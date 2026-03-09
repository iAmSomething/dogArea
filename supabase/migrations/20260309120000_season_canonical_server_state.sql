-- #473 season canonical server state + reward claim idempotency

alter table public.season_rewards
  add column if not exists claimed_at timestamptz,
  add column if not exists claim_request_id text,
  add column if not exists claim_source text,
  add column if not exists claim_metadata jsonb not null default '{}'::jsonb;

create unique index if not exists idx_season_rewards_owner_claim_request
  on public.season_rewards(owner_user_id, claim_request_id)
  where claim_request_id is not null;

create or replace function public.rpc_get_owner_season_summary(payload jsonb)
returns table (
  current_season_id uuid,
  current_season_key text,
  current_week_key text,
  current_status text,
  current_score double precision,
  current_target_score double precision,
  current_progress double precision,
  current_rank_tier text,
  current_today_score_delta integer,
  current_contribution_count integer,
  current_weather_shield_apply_count integer,
  current_score_updated_at timestamptz,
  current_last_contribution_at timestamptz,
  latest_completed_season_id uuid,
  latest_completed_week_key text,
  latest_completed_rank_tier text,
  latest_completed_total_score integer,
  latest_completed_contribution_count integer,
  latest_completed_weather_shield_apply_count integer,
  latest_completed_reward_code text,
  latest_completed_reward_status text,
  latest_completed_reward_claimed_at timestamptz,
  latest_completed_completed_at timestamptz,
  refreshed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid := auth.uid();
  resolved_now_ts timestamptz := coalesce(
    nullif(payload ->> 'now_ts', '')::timestamptz,
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    now()
  );
  requested_season_id uuid := coalesce(
    nullif(payload ->> 'season_id', '')::uuid,
    nullif(payload ->> 'in_season_id', '')::uuid
  );
  requested_week_key text := coalesce(
    nullif(trim(payload ->> 'week_key'), ''),
    nullif(trim(payload ->> 'in_week_key'), '')
  );
  current_run public.season_runs%rowtype;
  latest_completed_run public.season_runs%rowtype;
  current_score_row public.season_user_scores%rowtype;
  latest_completed_score_row public.season_user_scores%rowtype;
  latest_reward_row public.season_rewards%rowtype;
  current_today_score_delta_value integer := 0;
  current_contribution_count_value integer := 0;
  current_shield_apply_count_value integer := 0;
  latest_completed_contribution_count_value integer := 0;
  latest_completed_shield_apply_count_value integer := 0;
  resolved_current_week_key text := to_char((resolved_now_ts at time zone 'utc')::date, 'IYYY-"W"IW');
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;

  if requested_season_id is not null then
    select *
    into current_run
    from public.season_runs sr
    where sr.id = requested_season_id
    limit 1;
  elsif requested_week_key is not null then
    select *
    into current_run
    from public.season_runs sr
    where to_char(sr.week_start, 'IYYY-"W"IW') = requested_week_key
    order by sr.week_start desc
    limit 1;
  else
    select *
    into current_run
    from public.season_runs sr
    order by
      case sr.status
        when 'active' then 1
        when 'settling' then 2
        when 'settled' then 3
        else 4
      end,
      sr.week_start desc
    limit 1;
  end if;

  if current_run.id is not null then
    resolved_current_week_key := to_char(current_run.week_start, 'IYYY-"W"IW');

    select *
    into current_score_row
    from public.season_user_scores sus
    where sus.season_id = current_run.id
      and sus.owner_user_id = requester_uid
    limit 1;

    select coalesce(sum(te.score_delta), 0)::integer
    into current_today_score_delta_value
    from public.tile_events te
    where te.season_id = current_run.id
      and te.owner_user_id = requester_uid
      and te.event_day = (resolved_now_ts at time zone 'utc')::date;

    select count(distinct te.source_walk_session_id)::integer
    into current_contribution_count_value
    from public.tile_events te
    where te.season_id = current_run.id
      and te.owner_user_id = requester_uid
      and te.source_walk_session_id is not null;

    select count(*)::integer
    into current_shield_apply_count_value
    from public.weather_shield_ledgers s
    where s.owner_user_id = requester_uid
      and s.week_start = current_run.week_start;
  end if;

  select *
  into latest_completed_run
  from public.season_runs sr
  where sr.status = 'settled'
    and exists (
      select 1
      from public.season_user_scores sus
      where sus.season_id = sr.id
        and sus.owner_user_id = requester_uid
    )
  order by sr.week_start desc
  limit 1;

  if latest_completed_run.id is not null then
    select *
    into latest_completed_score_row
    from public.season_user_scores sus
    where sus.season_id = latest_completed_run.id
      and sus.owner_user_id = requester_uid
    limit 1;

    select *
    into latest_reward_row
    from public.season_rewards r
    where r.season_id = latest_completed_run.id
      and r.owner_user_id = requester_uid
    order by r.issued_at desc, r.created_at desc
    limit 1;

    select count(distinct te.source_walk_session_id)::integer
    into latest_completed_contribution_count_value
    from public.tile_events te
    where te.season_id = latest_completed_run.id
      and te.owner_user_id = requester_uid
      and te.source_walk_session_id is not null;

    select count(*)::integer
    into latest_completed_shield_apply_count_value
    from public.weather_shield_ledgers s
    where s.owner_user_id = requester_uid
      and s.week_start = latest_completed_run.week_start;
  end if;

  return query
  select
    current_run.id,
    current_run.season_key,
    resolved_current_week_key,
    coalesce(current_run.status, 'inactive'),
    coalesce(current_score_row.total_score, 0::double precision),
    greatest(coalesce(current_run.tier_threshold_platinum, 520), 1)::double precision,
    case
      when current_run.id is null then 0::double precision
      else least(
        1::double precision,
        greatest(
          0::double precision,
          coalesce(current_score_row.total_score, 0::double precision)
            / greatest(coalesce(current_run.tier_threshold_platinum, 520), 1)::double precision
        )
      )
    end,
    case coalesce(current_score_row.tier, 'none')
      when 'none' then 'rookie'
      else current_score_row.tier
    end,
    greatest(current_today_score_delta_value, 0),
    greatest(current_contribution_count_value, 0),
    greatest(current_shield_apply_count_value, 0),
    current_score_row.score_updated_at,
    current_score_row.last_contribution_at,
    latest_completed_run.id,
    case
      when latest_completed_run.id is null then null
      else to_char(latest_completed_run.week_start, 'IYYY-"W"IW')
    end,
    case coalesce(latest_completed_score_row.tier, 'none')
      when 'none' then 'rookie'
      else latest_completed_score_row.tier
    end,
    case
      when latest_completed_run.id is null then null
      else round(coalesce(latest_completed_score_row.total_score, 0::double precision))::integer
    end,
    case
      when latest_completed_run.id is null then null
      else greatest(latest_completed_contribution_count_value, 0)
    end,
    case
      when latest_completed_run.id is null then null
      else greatest(latest_completed_shield_apply_count_value, 0)
    end,
    latest_reward_row.reward_code,
    case
      when latest_completed_run.id is null then null
      when latest_reward_row.id is null then 'unavailable'
      when latest_reward_row.claimed_at is not null then 'claimed'
      else 'pending'
    end,
    latest_reward_row.claimed_at,
    coalesce(latest_completed_run.finalized_at, latest_completed_run.week_end::timestamptz),
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_get_owner_season_summary(jsonb)
  to authenticated, service_role;

create or replace function public.rpc_claim_season_reward(payload jsonb)
returns table (
  season_id uuid,
  week_key text,
  reward_code text,
  claim_status text,
  already_claimed boolean,
  claimed_at timestamptz,
  request_id text,
  refreshed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid := auth.uid();
  resolved_now_ts timestamptz := coalesce(
    nullif(payload ->> 'now_ts', '')::timestamptz,
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    now()
  );
  requested_season_id uuid := coalesce(
    nullif(payload ->> 'season_id', '')::uuid,
    nullif(payload ->> 'in_season_id', '')::uuid
  );
  requested_week_key text := coalesce(
    nullif(trim(payload ->> 'week_key'), ''),
    nullif(trim(payload ->> 'in_week_key'), '')
  );
  resolved_request_id text := lower(
    coalesce(
      nullif(trim(payload ->> 'request_id'), ''),
      nullif(trim(payload ->> 'in_request_id'), ''),
      gen_random_uuid()::text
    )
  );
  resolved_source text := coalesce(
    nullif(trim(payload ->> 'source'), ''),
    nullif(trim(payload ->> 'in_source'), ''),
    'ios'
  );
  reward_row public.season_rewards%rowtype;
  run_row public.season_runs%rowtype;
  resolved_week_key text := coalesce(requested_week_key, to_char((resolved_now_ts at time zone 'utc')::date, 'IYYY-"W"IW'));
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;

  select *
  into reward_row
  from public.season_rewards r
  where r.owner_user_id = requester_uid
    and r.claim_request_id = resolved_request_id
  limit 1;

  if reward_row.id is not null then
    select *
    into run_row
    from public.season_runs sr
    where sr.id = reward_row.season_id
    limit 1;

    return query
    select
      reward_row.season_id,
      coalesce(to_char(run_row.week_start, 'IYYY-"W"IW'), resolved_week_key),
      reward_row.reward_code,
      'claimed',
      true,
      reward_row.claimed_at,
      coalesce(reward_row.claim_request_id, resolved_request_id),
      resolved_now_ts;
    return;
  end if;

  if requested_season_id is not null then
    select *
    into run_row
    from public.season_runs sr
    where sr.id = requested_season_id
    limit 1;
  elsif requested_week_key is not null then
    select *
    into run_row
    from public.season_runs sr
    where to_char(sr.week_start, 'IYYY-"W"IW') = requested_week_key
    order by sr.week_start desc
    limit 1;
  end if;

  if run_row.id is null then
    return query
    select
      requested_season_id,
      resolved_week_key,
      null::text,
      'unavailable',
      false,
      null::timestamptz,
      resolved_request_id,
      resolved_now_ts;
    return;
  end if;

  resolved_week_key := to_char(run_row.week_start, 'IYYY-"W"IW');

  select *
  into reward_row
  from public.season_rewards r
  where r.season_id = run_row.id
    and r.owner_user_id = requester_uid
  order by r.issued_at desc, r.created_at desc
  limit 1;

  if reward_row.id is null then
    return query
    select
      run_row.id,
      resolved_week_key,
      null::text,
      'unavailable',
      false,
      null::timestamptz,
      resolved_request_id,
      resolved_now_ts;
    return;
  end if;

  if reward_row.claimed_at is not null then
    return query
    select
      reward_row.season_id,
      resolved_week_key,
      reward_row.reward_code,
      'claimed',
      true,
      reward_row.claimed_at,
      coalesce(reward_row.claim_request_id, resolved_request_id),
      resolved_now_ts;
    return;
  end if;

  update public.season_rewards r
  set claimed_at = resolved_now_ts,
      claim_request_id = resolved_request_id,
      claim_source = resolved_source,
      claim_metadata = coalesce(r.claim_metadata, '{}'::jsonb) || jsonb_build_object(
        'request_id', resolved_request_id,
        'source', resolved_source,
        'claimed_at', resolved_now_ts
      ),
      updated_at = resolved_now_ts
  where r.id = reward_row.id
  returning * into reward_row;

  return query
  select
    reward_row.season_id,
    resolved_week_key,
    reward_row.reward_code,
    'claimed',
    false,
    reward_row.claimed_at,
    resolved_request_id,
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_claim_season_reward(jsonb)
  to authenticated, service_role;
