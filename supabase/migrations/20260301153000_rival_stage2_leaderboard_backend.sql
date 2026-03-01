-- #131 rival stage2 backend: alias profile + leaderboard API + export/delete route

create extension if not exists pgcrypto;

create table if not exists public.rival_alias_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  season_key text not null,
  alias_code text not null,
  avatar_seed text not null,
  rotated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_rival_alias_profiles_season_alias
  on public.rival_alias_profiles(season_key, alias_code);

create table if not exists public.rival_abuse_audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  period_type text not null check (period_type in ('day', 'week', 'season')),
  period_start timestamptz not null,
  period_end timestamptz not null,
  reason text not null,
  source_count integer not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, period_type, period_start, reason)
);

create index if not exists idx_rival_abuse_audit_user_created
  on public.rival_abuse_audit_logs(user_id, created_at desc);
create index if not exists idx_rival_abuse_audit_period_created
  on public.rival_abuse_audit_logs(period_type, period_start desc, created_at desc);

alter table public.rival_alias_profiles enable row level security;
alter table public.rival_abuse_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_alias_profiles'
      and policyname = 'rival_alias_profiles_owner_select'
  ) then
    create policy rival_alias_profiles_owner_select
      on public.rival_alias_profiles
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_alias_profiles'
      and policyname = 'rival_alias_profiles_service_write'
  ) then
    create policy rival_alias_profiles_service_write
      on public.rival_alias_profiles
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_abuse_audit_logs'
      and policyname = 'rival_abuse_audit_logs_owner_select'
  ) then
    create policy rival_abuse_audit_logs_owner_select
      on public.rival_abuse_audit_logs
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_abuse_audit_logs'
      and policyname = 'rival_abuse_audit_logs_service_write'
  ) then
    create policy rival_abuse_audit_logs_service_write
      on public.rival_abuse_audit_logs
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

drop trigger if exists trg_rival_alias_profiles_updated_at on public.rival_alias_profiles;
create trigger trg_rival_alias_profiles_updated_at
before update on public.rival_alias_profiles
for each row execute function public.touch_updated_at();

create or replace function public.rival_score_bucket(score_value double precision)
returns text
language sql
immutable
as $$
  select case
    when score_value < 10 then '0-9'
    when score_value < 25 then '10-24'
    when score_value < 50 then '25-49'
    when score_value < 100 then '50-99'
    when score_value < 200 then '100-199'
    when score_value < 400 then '200-399'
    else '400+'
  end;
$$;

create or replace function public.rpc_get_rival_leaderboard(
  period_type text default 'week',
  top_n integer default 50,
  now_ts timestamptz default now()
)
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
  requester_uid uuid;
  normalized_period text := lower(coalesce(period_type, 'week'));
  limited_top_n integer := greatest(1, least(coalesce(top_n, 50), 200));
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_season_id uuid;
  v_season_key text;
  run_row public.season_runs%rowtype;
  policy_row public.rival_league_policies%rowtype;
begin
  requester_uid := auth.uid();

  if normalized_period not in ('day', 'week', 'season') then
    raise exception 'invalid period_type: %', normalized_period;
  end if;

  select *
  into policy_row
  from public.rival_league_policies
  where policy_key = 'rival_league_v1'
  limit 1;

  if normalized_period = 'day' then
    v_period_start := date_trunc('day', now_ts);
    v_period_end := v_period_start + interval '1 day';
    v_season_key := 'daily_' || to_char(v_period_start, 'YYYYMMDD');
  elsif normalized_period = 'week' then
    v_period_start := date_trunc('week', now_ts);
    v_period_end := v_period_start + interval '7 days';
    v_season_key := 'weekly_' || to_char(v_period_start, 'YYYYMMDD');
  else
    select *
    into run_row
    from public.season_runs sr
    order by
      case sr.status
        when 'active' then 1
        when 'settling' then 2
        else 3
      end,
      sr.week_start desc
    limit 1;

    if run_row.id is null then
      v_period_start := date_trunc('week', now_ts);
      v_period_end := v_period_start + interval '7 days';
      v_season_key := 'weekly_' || to_char(v_period_start, 'YYYYMMDD');
      normalized_period := 'week';
    else
      v_period_start := run_row.week_start::timestamptz;
      v_period_end := run_row.week_end::timestamptz;
      v_season_id := run_row.id;
      v_season_key := run_row.season_key;
    end if;
  end if;

  return query
  with raw_scores as (
    select
      ws.owner_user_id as user_id,
      sum(
        (ws.duration_sec::double precision / 60.0) * coalesce(policy_row.duration_weight, 0.6) +
        (ws.area_m2::double precision / 10000.0) * coalesce(policy_row.area_weight, 0.4)
      )::double precision as raw_score
    from public.walk_sessions ws
    where normalized_period in ('day', 'week')
      and ws.started_at >= v_period_start
      and ws.started_at < v_period_end
    group by ws.owner_user_id

    union all

    select
      sus.owner_user_id as user_id,
      sus.total_score::double precision as raw_score
    from public.season_user_scores sus
    where normalized_period = 'season'
      and v_season_id is not null
      and sus.season_id = v_season_id
  ),
  merged_scores as (
    select
      r.user_id,
      sum(r.raw_score)::double precision as raw_score
    from raw_scores r
    group by r.user_id
  ),
  latest_assignments as (
    select distinct on (a.user_id)
      a.user_id,
      a.league,
      a.effective_league,
      a.fallback_applied
    from public.rival_league_assignments a
    order by a.user_id, a.snapshot_week_start desc, a.updated_at desc
  ),
  suspicious_users as (
    select
      l.owner_user_id as user_id,
      count(*)::int as blocked_count
    from public.season_score_audit_logs l
    where l.blocked = true
      and l.created_at >= now_ts - interval '14 days'
    group by l.owner_user_id
  ),
  excluded_candidates as (
    select
      m.user_id,
      s.blocked_count
    from merged_scores m
    join suspicious_users s on s.user_id = m.user_id
  ),
  audit_upsert as (
    insert into public.rival_abuse_audit_logs (
      user_id,
      period_type,
      period_start,
      period_end,
      reason,
      source_count,
      payload,
      created_at
    )
    select
      e.user_id,
      normalized_period,
      v_period_start,
      v_period_end,
      'blocked_by_season_audit',
      e.blocked_count,
      jsonb_build_object(
        'source', 'season_score_audit_logs',
        'blocked_count', e.blocked_count
      ),
      now_ts
    from excluded_candidates e
    on conflict (user_id, period_type, period_start, reason)
    do update set
      source_count = excluded.source_count,
      payload = excluded.payload,
      created_at = excluded.created_at
    returning 1
  ),
  eligible as (
    select
      m.user_id,
      m.raw_score,
      coalesce(a.league, 'onboarding') as league,
      coalesce(a.effective_league, 'onboarding') as effective_league,
      coalesce(a.fallback_applied, false) as fallback_applied
    from merged_scores m
    left join latest_assignments a on a.user_id = m.user_id
    where not exists (
      select 1
      from suspicious_users s
      where s.user_id = m.user_id
    )
  ),
  ranked as (
    select
      e.*,
      row_number() over (order by e.raw_score desc, e.user_id) as rank_position
    from eligible e
  ),
  top_rows as (
    select *
    from ranked
    order by rank_position
    limit limited_top_n
  ),
  alias_upsert as (
    insert into public.rival_alias_profiles (
      user_id,
      season_key,
      alias_code,
      avatar_seed,
      rotated_at,
      created_at,
      updated_at
    )
    select
      t.user_id,
      v_season_key,
      'R-' || upper(substr(md5(t.user_id::text || ':' || v_season_key), 1, 6)),
      substr(md5('avatar:' || t.user_id::text || ':' || v_season_key), 1, 12),
      now_ts,
      now_ts,
      now_ts
    from top_rows t
    on conflict (user_id) do update set
      season_key = excluded.season_key,
      alias_code = excluded.alias_code,
      avatar_seed = excluded.avatar_seed,
      rotated_at = excluded.rotated_at,
      updated_at = now_ts
    where public.rival_alias_profiles.season_key is distinct from excluded.season_key
    returning user_id
  )
  select
    normalized_period as period_type,
    v_period_start as period_start,
    v_period_end as period_end,
    v_season_key as season_key,
    t.rank_position,
    md5(t.user_id::text) as user_key,
    coalesce(ap.alias_code, 'R-' || upper(substr(md5(t.user_id::text || ':' || v_season_key), 1, 6))) as alias_code,
    coalesce(ap.avatar_seed, substr(md5('avatar:' || t.user_id::text || ':' || v_season_key), 1, 12)) as avatar_seed,
    t.league,
    t.effective_league,
    t.fallback_applied,
    public.rival_score_bucket(t.raw_score) as score_bucket,
    (requester_uid is not null and t.user_id = requester_uid) as is_me
  from top_rows t
  left join public.rival_alias_profiles ap on ap.user_id = t.user_id
  order by t.rank_position asc;
end;
$$;

create or replace function public.rpc_export_my_rival_data(
  requested_user_id uuid default auth.uid(),
  now_ts timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  target_uid uuid;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  target_uid := coalesce(requested_user_id, requester_uid);

  if requester_role <> 'service_role' then
    if target_uid is null or requester_uid is null or target_uid <> requester_uid then
      raise exception 'permission denied';
    end if;
  end if;

  return jsonb_build_object(
    'user_id', target_uid,
    'visibility_settings', (
      select to_jsonb(v)
      from public.user_visibility_settings v
      where v.user_id = target_uid
    ),
    'alias_profile', (
      select to_jsonb(a)
      from public.rival_alias_profiles a
      where a.user_id = target_uid
    ),
    'latest_assignment', (
      select to_jsonb(x)
      from (
        select
          ra.snapshot_week_start,
          ra.league,
          ra.effective_league,
          ra.activity_score,
          ra.percentile_rank,
          ra.fallback_applied,
          ra.fallback_reason,
          ra.reason,
          ra.updated_at
        from public.rival_league_assignments ra
        where ra.user_id = target_uid
        order by ra.snapshot_week_start desc
        limit 1
      ) x
    ),
    'league_history', coalesce((
      select jsonb_agg(to_jsonb(h) order by h.created_at desc)
      from (
        select
          rh.snapshot_week_start,
          rh.from_league,
          rh.to_league,
          rh.from_effective_league,
          rh.to_effective_league,
          rh.change_reason,
          rh.activity_score,
          rh.percentile_rank,
          rh.created_at
        from public.rival_league_history rh
        where rh.user_id = target_uid
        order by rh.created_at desc
        limit 120
      ) h
    ), '[]'::jsonb),
    'presence', (
      select to_jsonb(p)
      from public.nearby_presence p
      where p.user_id = target_uid
    ),
    'abuse_audit_logs', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.created_at desc)
      from (
        select
          ral.period_type,
          ral.period_start,
          ral.period_end,
          ral.reason,
          ral.source_count,
          ral.payload,
          ral.created_at
        from public.rival_abuse_audit_logs ral
        where ral.user_id = target_uid
        order by ral.created_at desc
        limit 120
      ) l
    ), '[]'::jsonb),
    'exported_at', now_ts
  );
end;
$$;

create or replace function public.rpc_delete_my_rival_data(
  requested_user_id uuid default auth.uid(),
  now_ts timestamptz default now()
)
returns table (
  user_id uuid,
  sharing_disabled boolean,
  deleted_presence boolean,
  deleted_alias boolean,
  deleted_assignments integer,
  deleted_history integer,
  deleted_abuse_logs integer,
  deleted_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  target_uid uuid;
  deleted_presence_count integer := 0;
  deleted_alias_count integer := 0;
  deleted_assignment_count integer := 0;
  deleted_history_count integer := 0;
  deleted_abuse_count integer := 0;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  target_uid := coalesce(requested_user_id, requester_uid);

  if requester_role <> 'service_role' then
    if target_uid is null or requester_uid is null or target_uid <> requester_uid then
      raise exception 'permission denied';
    end if;
  end if;

  insert into public.user_visibility_settings (
    user_id,
    location_sharing_enabled,
    updated_at
  )
  values (
    target_uid,
    false,
    now_ts
  )
  on conflict (user_id) do update
  set
    location_sharing_enabled = false,
    updated_at = now_ts;

  delete from public.nearby_presence
  where user_id = target_uid;
  get diagnostics deleted_presence_count = row_count;

  delete from public.rival_alias_profiles
  where user_id = target_uid;
  get diagnostics deleted_alias_count = row_count;

  delete from public.rival_league_assignments
  where user_id = target_uid;
  get diagnostics deleted_assignment_count = row_count;

  delete from public.rival_league_history
  where user_id = target_uid;
  get diagnostics deleted_history_count = row_count;

  delete from public.rival_abuse_audit_logs
  where user_id = target_uid;
  get diagnostics deleted_abuse_count = row_count;

  return query
  select
    target_uid,
    true,
    deleted_presence_count > 0,
    deleted_alias_count > 0,
    deleted_assignment_count,
    deleted_history_count,
    deleted_abuse_count,
    now_ts;
end;
$$;

grant execute on function public.rival_score_bucket(double precision) to anon, authenticated, service_role;
grant execute on function public.rpc_get_rival_leaderboard(text, integer, timestamptz) to anon, authenticated, service_role;
grant execute on function public.rpc_export_my_rival_data(uuid, timestamptz) to authenticated, service_role;
grant execute on function public.rpc_delete_my_rival_data(uuid, timestamptz) to authenticated, service_role;

grant select on public.rival_alias_profiles to authenticated;
grant select on public.rival_abuse_audit_logs to authenticated;
