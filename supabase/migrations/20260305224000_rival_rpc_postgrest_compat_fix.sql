-- #364 fix rival RPC compatibility without relying on broken 3-arg function path

create or replace function public.rpc_get_rival_leaderboard(payload jsonb)
returns table (
  period_type text,
  period_start timestamptz,
  period_end timestamptz,
  season_key text,
  rank_position integer,
  user_key text,
  alias_code text,
  avatar_seed text,
  league text,
  effective_league text,
  fallback_applied boolean,
  score_bucket text,
  is_me boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid := auth.uid();
  normalized_period text := lower(
    coalesce(
      nullif(trim(payload ->> 'period_type'), ''),
      nullif(trim(payload ->> 'in_period_type'), ''),
      'week'
    )
  );
  limited_top_n integer := greatest(
    1,
    least(
      coalesce(
        nullif(payload ->> 'top_n', '')::integer,
        nullif(payload ->> 'in_top_n', '')::integer,
        50
      ),
      200
    )
  );
  resolved_now_ts timestamptz := coalesce(
    nullif(payload ->> 'now_ts', '')::timestamptz,
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    now()
  );
  snapshot_start date;
  snapshot_end date;
  resolved_season_key text;
begin
  if requester_uid is null then
    return;
  end if;

  if normalized_period not in ('day', 'week', 'season') then
    normalized_period := 'week';
  end if;

  select max(a.snapshot_week_start)
  into snapshot_start
  from public.rival_league_assignments a;

  if snapshot_start is null then
    snapshot_start := date_trunc('week', resolved_now_ts)::date;
  end if;

  snapshot_end := snapshot_start + interval '7 days';
  resolved_season_key :=
    case normalized_period
      when 'day' then 'daily_' || to_char(date_trunc('day', resolved_now_ts), 'YYYYMMDD')
      when 'season' then 'season_' || to_char(snapshot_start, 'YYYYMMDD')
      else 'weekly_' || to_char(snapshot_start, 'YYYYMMDD')
    end;

  return query
  with ranked as (
    select
      a.user_id,
      a.league,
      a.effective_league,
      coalesce(a.fallback_applied, false) as fallback_applied,
      coalesce(a.activity_score, 0)::double precision as score_value,
      row_number() over (
        order by
          coalesce(a.activity_score, 0) desc,
          a.user_id
      )::integer as rank_position
    from public.rival_league_assignments a
    where a.snapshot_week_start = snapshot_start
  ),
  top_rows as (
    select *
    from ranked
    order by rank_position
    limit limited_top_n
  )
  select
    normalized_period as period_type,
    snapshot_start::timestamptz as period_start,
    snapshot_end::timestamptz as period_end,
    resolved_season_key as season_key,
    t.rank_position,
    md5(t.user_id::text) as user_key,
    coalesce(
      ap.alias_code,
      'R-' || upper(substr(md5(t.user_id::text || ':' || resolved_season_key), 1, 6))
    ) as alias_code,
    coalesce(
      ap.avatar_seed,
      substr(md5('avatar:' || t.user_id::text || ':' || resolved_season_key), 1, 12)
    ) as avatar_seed,
    t.league,
    t.effective_league,
    t.fallback_applied,
    public.rival_score_bucket(t.score_value) as score_bucket,
    (t.user_id = requester_uid) as is_me
  from top_rows t
  left join public.rival_alias_profiles ap on ap.user_id = t.user_id
  order by t.rank_position asc;
end;
$$;

revoke all on function public.rpc_get_rival_leaderboard(jsonb) from public;
grant execute on function public.rpc_get_rival_leaderboard(jsonb) to anon, authenticated, service_role;

create or replace function public.rpc_get_widget_quest_rival_summary(
  in_now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  quest_title text,
  quest_progress_value double precision,
  quest_target_value double precision,
  quest_claimable boolean,
  quest_reward_point integer,
  rival_rank integer,
  rival_league text,
  refreshed_at timestamptz,
  has_data boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  quest_row record;
  rival_row record;
begin
  requester_uid := auth.uid();
  if requester_uid is null then
    return;
  end if;

  select
    qi.id,
    qi.title_snapshot,
    qi.progress_value,
    qi.target_value_snapshot,
    (qi.status = 'completed' and qi.claimed_at is null) as claimable,
    qi.reward_points_snapshot
  into quest_row
  from public.quest_instances qi
  where qi.owner_user_id = requester_uid
    and qi.status in ('active', 'completed', 'claimed')
    and qi.expires_at >= in_now_ts - interval '1 day'
  order by
    case
      when qi.status = 'completed' and qi.claimed_at is null then 0
      when qi.status = 'active' then 1
      when qi.status = 'claimed' then 2
      else 3
    end,
    qi.updated_at desc
  limit 1;

  select
    r.rank_position,
    r.effective_league
  into rival_row
  from public.rpc_get_rival_leaderboard(
    jsonb_build_object(
      'period_type', 'week',
      'top_n', 50,
      'now_ts', in_now_ts
    )
  ) r
  where r.is_me = true
  limit 1;

  return query
  select
    quest_row.id::uuid,
    coalesce(quest_row.title_snapshot::text, '오늘의 퀘스트를 준비 중입니다.'),
    coalesce(quest_row.progress_value::double precision, 0::double precision),
    greatest(coalesce(quest_row.target_value_snapshot::double precision, 1::double precision), 1::double precision),
    coalesce(quest_row.claimable::boolean, false),
    greatest(coalesce(quest_row.reward_points_snapshot::integer, 0), 0),
    rival_row.rank_position::integer,
    coalesce(rival_row.effective_league::text, 'onboarding'),
    in_now_ts,
    (quest_row.id is not null or rival_row.rank_position is not null);
end;
$$;

revoke all on function public.rpc_get_widget_quest_rival_summary(timestamptz) from public;
grant execute on function public.rpc_get_widget_quest_rival_summary(timestamptz) to authenticated, service_role;

create or replace function public.rpc_get_widget_quest_rival_summary(payload jsonb)
returns table (
  quest_instance_id uuid,
  quest_title text,
  quest_progress_value double precision,
  quest_target_value double precision,
  quest_claimable boolean,
  quest_reward_point integer,
  rival_rank integer,
  rival_league text,
  refreshed_at timestamptz,
  has_data boolean
)
language sql
security definer
set search_path = public
as $$
  select *
  from public.rpc_get_widget_quest_rival_summary(
    coalesce(
      nullif(payload ->> 'in_now_ts', '')::timestamptz,
      nullif(payload ->> 'now_ts', '')::timestamptz,
      now()
    )
  );
$$;

revoke all on function public.rpc_get_widget_quest_rival_summary(jsonb) from public;
grant execute on function public.rpc_get_widget_quest_rival_summary(jsonb) to authenticated, service_role;
