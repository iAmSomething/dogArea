-- #145 season comeback catch-up buff (72h inactivity -> 48h +20% on new tile contribution)

create table if not exists public.season_catchup_buff_policies (
  policy_key text primary key,
  inactivity_threshold_hours int not null default 72 check (inactivity_threshold_hours >= 24),
  buff_active_hours int not null default 48 check (buff_active_hours between 1 and 168),
  score_boost_rate double precision not null default 0.20 check (score_boost_rate >= 0 and score_boost_rate <= 1.0),
  weekly_issue_limit int not null default 1 check (weekly_issue_limit between 0 and 7),
  season_end_block_hours int not null default 24 check (season_end_block_hours between 0 and 72),
  abuse_grant_count_28d int not null default 3 check (abuse_grant_count_28d between 1 and 20),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.season_catchup_buff_policies (
  policy_key,
  inactivity_threshold_hours,
  buff_active_hours,
  score_boost_rate,
  weekly_issue_limit,
  season_end_block_hours,
  abuse_grant_count_28d,
  enabled
)
values (
  'season_comeback_catchup_v1',
  72,
  48,
  0.20,
  1,
  24,
  3,
  true
)
on conflict (policy_key) do update
set inactivity_threshold_hours = excluded.inactivity_threshold_hours,
    buff_active_hours = excluded.buff_active_hours,
    score_boost_rate = excluded.score_boost_rate,
    weekly_issue_limit = excluded.weekly_issue_limit,
    season_end_block_hours = excluded.season_end_block_hours,
    abuse_grant_count_28d = excluded.abuse_grant_count_28d,
    enabled = excluded.enabled,
    updated_at = now();

create table if not exists public.season_catchup_buff_grants (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  walk_session_id uuid,
  policy_key text not null default 'season_comeback_catchup_v1',
  granted_at timestamptz not null,
  expires_at timestamptz not null,
  week_start date not null,
  boost_rate double precision not null default 0.20 check (boost_rate >= 0 and boost_rate <= 1.0),
  status text not null default 'active' check (status in ('active','expired','blocked')),
  blocked_reason text,
  issued_reason text,
  abuse_flag boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_season_catchup_buff_grants_owner_granted
  on public.season_catchup_buff_grants(owner_user_id, granted_at desc);
create index if not exists idx_season_catchup_buff_grants_owner_expires
  on public.season_catchup_buff_grants(owner_user_id, expires_at desc);
create index if not exists idx_season_catchup_buff_grants_week_start
  on public.season_catchup_buff_grants(week_start, owner_user_id);

alter table public.season_catchup_buff_policies enable row level security;
alter table public.season_catchup_buff_grants enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'season_catchup_buff_policies'
      and policyname = 'season_catchup_buff_policies_select_all'
  ) then
    create policy season_catchup_buff_policies_select_all
      on public.season_catchup_buff_policies
      for select
      to anon, authenticated
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'season_catchup_buff_grants'
      and policyname = 'season_catchup_buff_grants_owner_select'
  ) then
    create policy season_catchup_buff_grants_owner_select
      on public.season_catchup_buff_grants
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'season_catchup_buff_grants'
      and policyname = 'season_catchup_buff_grants_service_write'
  ) then
    create policy season_catchup_buff_grants_service_write
      on public.season_catchup_buff_grants
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_season_catchup_buff_policies_updated_at on public.season_catchup_buff_policies;
create trigger trg_season_catchup_buff_policies_updated_at
before update on public.season_catchup_buff_policies
for each row execute function public.set_updated_at();

drop trigger if exists trg_season_catchup_buff_grants_updated_at on public.season_catchup_buff_grants;
create trigger trg_season_catchup_buff_grants_updated_at
before update on public.season_catchup_buff_grants
for each row execute function public.set_updated_at();

-- replace #146 RPC with catch-up buff aware scoring

drop function if exists public.rpc_score_walk_session_anti_farming(uuid, timestamptz);

create or replace function public.rpc_score_walk_session_anti_farming(
  target_walk_session_id uuid,
  now_ts timestamptz default now()
)
returns table (
  walk_session_id uuid,
  total_points int,
  unique_tiles int,
  novelty_ratio double precision,
  repeat_suppressed_count int,
  suspicious_repeat_count int,
  base_score double precision,
  new_route_bonus double precision,
  catchup_bonus double precision,
  total_score double precision,
  score_blocked boolean,
  catchup_buff_active boolean,
  catchup_buff_granted_at timestamptz,
  catchup_buff_expires_at timestamptz,
  explain jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  policy_row public.season_scoring_policies%rowtype;
  catchup_policy_row public.season_catchup_buff_policies%rowtype;
  session_owner uuid;
  requester_uid uuid;
  requester_role text;
  v_total_points int := 0;
  v_unique_tiles int := 0;
  v_novelty_ratio double precision := 0;
  v_repeat_suppressed int := 0;
  v_suspicious_repeat int := 0;
  v_base_score double precision := 0;
  v_bonus_score double precision := 0;
  v_raw_total_score double precision := 0;
  v_total_distance_m double precision := 0;
  v_score_blocked boolean := false;
  v_total_score double precision := 0;
  v_severity text := 'info';
  v_new_tile_score double precision := 0;
  v_catchup_bonus double precision := 0;
  v_catchup_active boolean := false;
  v_catchup_granted_at timestamptz := null;
  v_catchup_expires_at timestamptz := null;
  v_catchup_status text := 'inactive';
  v_catchup_block_reason text := null;
  v_last_activity_at timestamptz := null;
  v_inactive_hours double precision := 0;
  v_week_start timestamptz := date_trunc('week', now_ts);
  v_week_end timestamptz := date_trunc('week', now_ts) + interval '7 day';
  v_weekly_grant_count int := 0;
  v_recent_grant_count_28d int := 0;
  v_abuse_suspected boolean := false;
begin
  if target_walk_session_id is null then
    return;
  end if;

  select owner_user_id into session_owner
  from public.walk_sessions
  where id = target_walk_session_id
  limit 1;

  if session_owner is null then
    return;
  end if;

  requester_uid := auth.uid();
  requester_role := auth.role();

  if requester_role <> 'service_role' then
    if requester_uid is null or requester_uid <> session_owner then
      raise exception 'permission denied for walk session %', target_walk_session_id;
    end if;
  end if;

  select *
  into policy_row
  from public.season_scoring_policies
  where policy_key = 'season_tile_anti_farming_v1'
  limit 1;

  if not found then
    policy_row.policy_key := 'season_tile_anti_farming_v1';
    policy_row.repeat_cooldown_minutes := 30;
    policy_row.tile_decimal_precision := 3;
    policy_row.base_tile_score := 1.0;
    policy_row.new_route_bonus_weight := 0.7;
    policy_row.suspicious_repeat_threshold := 10;
    policy_row.suspicious_max_novelty_ratio := 0.35;
    policy_row.suspicious_low_movement_meters := 120;
    policy_row.suspicious_block_enabled := true;
  end if;

  select *
  into catchup_policy_row
  from public.season_catchup_buff_policies
  where policy_key = 'season_comeback_catchup_v1'
  limit 1;

  if not found then
    catchup_policy_row.policy_key := 'season_comeback_catchup_v1';
    catchup_policy_row.inactivity_threshold_hours := 72;
    catchup_policy_row.buff_active_hours := 48;
    catchup_policy_row.score_boost_rate := 0.20;
    catchup_policy_row.weekly_issue_limit := 1;
    catchup_policy_row.season_end_block_hours := 24;
    catchup_policy_row.abuse_grant_count_28d := 3;
    catchup_policy_row.enabled := true;
  end if;

  delete from public.season_tile_score_events
  where walk_session_id = target_walk_session_id;

  with points as (
    select
      wp.seq_no,
      wp.lat,
      wp.lng,
      wp.recorded_at,
      public.season_tile_key_from_coord(wp.lat, wp.lng, policy_row.tile_decimal_precision) as geotile,
      lag(wp.recorded_at) over (
        partition by public.season_tile_key_from_coord(wp.lat, wp.lng, policy_row.tile_decimal_precision)
        order by wp.recorded_at, wp.seq_no
      ) as prev_same_tile_at,
      lag(wp.lat) over (order by wp.recorded_at, wp.seq_no) as prev_lat,
      lag(wp.lng) over (order by wp.recorded_at, wp.seq_no) as prev_lng,
      row_number() over (
        partition by public.season_tile_key_from_coord(wp.lat, wp.lng, policy_row.tile_decimal_precision)
        order by wp.recorded_at, wp.seq_no
      ) = 1 as is_first_tile_hit
    from public.walk_points wp
    where wp.walk_session_id = target_walk_session_id
  ),
  normalized as (
    select
      p.*,
      (
        p.prev_same_tile_at is not null
        and p.recorded_at <= p.prev_same_tile_at + make_interval(mins => policy_row.repeat_cooldown_minutes)
      ) as is_repeat_within_cooldown,
      case
        when p.prev_lat is null or p.prev_lng is null then 0::double precision
        else sqrt(
          power((p.lat - p.prev_lat), 2) +
          power((p.lng - p.prev_lng) * cos(radians(p.lat)), 2)
        ) * 111320.0
      end as distance_from_prev_m
    from points p
  ),
  session_stats as (
    select
      count(*)::int as total_points,
      count(distinct geotile)::int as unique_tiles,
      case
        when count(*) = 0 then 0::double precision
        else count(distinct geotile)::double precision / count(*)::double precision
      end as novelty_ratio
    from normalized
  ),
  scored as (
    select
      n.seq_no,
      n.geotile,
      n.recorded_at,
      n.is_first_tile_hit,
      n.is_repeat_within_cooldown,
      n.distance_from_prev_m,
      ss.novelty_ratio,
      case
        when n.is_repeat_within_cooldown then 0::double precision
        else policy_row.base_tile_score
      end as base_score,
      case
        when n.is_first_tile_hit and n.is_repeat_within_cooldown = false
          then policy_row.base_tile_score * policy_row.new_route_bonus_weight * ss.novelty_ratio
        else 0::double precision
      end as novelty_bonus,
      case
        when n.is_repeat_within_cooldown then 'repeat_within_30m'
        else null
      end as suppression_reason
    from normalized n
    cross join session_stats ss
  )
  insert into public.season_tile_score_events (
    owner_user_id,
    walk_session_id,
    seq_no,
    geotile,
    recorded_at,
    is_first_tile_hit,
    is_repeat_within_cooldown,
    distance_from_prev_m,
    novelty_ratio,
    base_score,
    novelty_bonus,
    final_score,
    suppression_reason,
    created_at
  )
  select
    session_owner,
    target_walk_session_id,
    s.seq_no,
    s.geotile,
    s.recorded_at,
    s.is_first_tile_hit,
    s.is_repeat_within_cooldown,
    s.distance_from_prev_m,
    s.novelty_ratio,
    s.base_score,
    s.novelty_bonus,
    (s.base_score + s.novelty_bonus) as final_score,
    s.suppression_reason,
    now_ts
  from scored s
  order by s.seq_no;

  select
    count(*)::int,
    count(distinct geotile)::int,
    coalesce(max(novelty_ratio), 0::double precision),
    count(*) filter (where is_repeat_within_cooldown)::int,
    count(*) filter (where suppression_reason = 'repeat_within_30m')::int,
    coalesce(sum(base_score), 0::double precision),
    coalesce(sum(novelty_bonus), 0::double precision),
    coalesce(sum(final_score), 0::double precision),
    coalesce(sum(distance_from_prev_m), 0::double precision)
  into
    v_total_points,
    v_unique_tiles,
    v_novelty_ratio,
    v_repeat_suppressed,
    v_suspicious_repeat,
    v_base_score,
    v_bonus_score,
    v_raw_total_score,
    v_total_distance_m
  from public.season_tile_score_events
  where walk_session_id = target_walk_session_id;

  v_score_blocked :=
    policy_row.suspicious_block_enabled
    and v_repeat_suppressed >= policy_row.suspicious_repeat_threshold
    and v_novelty_ratio <= policy_row.suspicious_max_novelty_ratio
    and v_total_distance_m <= policy_row.suspicious_low_movement_meters;

  select count(*)::int
  into v_weekly_grant_count
  from public.season_catchup_buff_grants
  where owner_user_id = session_owner
    and granted_at >= v_week_start
    and granted_at < v_week_end
    and status in ('active', 'expired');

  select count(*)::int
  into v_recent_grant_count_28d
  from public.season_catchup_buff_grants
  where owner_user_id = session_owner
    and granted_at >= now_ts - interval '28 day'
    and status in ('active', 'expired');

  v_abuse_suspected := v_recent_grant_count_28d >= catchup_policy_row.abuse_grant_count_28d;

  select granted_at, expires_at
  into v_catchup_granted_at, v_catchup_expires_at
  from public.season_catchup_buff_grants
  where owner_user_id = session_owner
    and status = 'active'
    and granted_at <= now_ts
    and expires_at > now_ts
  order by granted_at desc
  limit 1;

  if v_catchup_granted_at is not null then
    v_catchup_active := true;
    v_catchup_status := 'active';
  elsif catchup_policy_row.enabled then
    if now_ts >= v_week_end - make_interval(hours => catchup_policy_row.season_end_block_hours) then
      v_catchup_status := 'blocked';
      v_catchup_block_reason := 'season_end_window';
    elsif v_weekly_grant_count >= catchup_policy_row.weekly_issue_limit then
      v_catchup_status := 'blocked';
      v_catchup_block_reason := 'weekly_limit_reached';
    else
      select max(ws.ended_at)
      into v_last_activity_at
      from public.walk_sessions ws
      where ws.owner_user_id = session_owner
        and ws.id <> target_walk_session_id
        and ws.ended_at < now_ts;

      if v_last_activity_at is null then
        v_catchup_status := 'blocked';
        v_catchup_block_reason := 'no_prior_activity';
      else
        v_inactive_hours := extract(epoch from (now_ts - v_last_activity_at)) / 3600.0;
        if v_inactive_hours < catchup_policy_row.inactivity_threshold_hours then
          v_catchup_status := 'blocked';
          v_catchup_block_reason := 'insufficient_inactivity';
        else
          insert into public.season_catchup_buff_grants (
            owner_user_id,
            walk_session_id,
            policy_key,
            granted_at,
            expires_at,
            week_start,
            boost_rate,
            status,
            blocked_reason,
            issued_reason,
            abuse_flag,
            payload,
            created_at,
            updated_at
          )
          values (
            session_owner,
            target_walk_session_id,
            catchup_policy_row.policy_key,
            now_ts,
            now_ts + make_interval(hours => catchup_policy_row.buff_active_hours),
            v_week_start::date,
            catchup_policy_row.score_boost_rate,
            'active',
            null,
            'auto_comeback_72h',
            v_abuse_suspected,
            jsonb_build_object(
              'inactive_hours', round(v_inactive_hours::numeric, 2),
              'weekly_grant_count_before', v_weekly_grant_count,
              'season_end', v_week_end,
              'policy_key', catchup_policy_row.policy_key
            ),
            now_ts,
            now_ts
          )
          returning granted_at, expires_at
          into v_catchup_granted_at, v_catchup_expires_at;

          v_catchup_active := true;
          v_weekly_grant_count := v_weekly_grant_count + 1;
          v_catchup_status := 'granted';
        end if;
      end if;
    end if;
  end if;

  if v_catchup_active and v_score_blocked = false then
    select coalesce(sum(final_score), 0::double precision)
    into v_new_tile_score
    from public.season_tile_score_events
    where walk_session_id = target_walk_session_id
      and is_first_tile_hit = true
      and is_repeat_within_cooldown = false;

    v_catchup_bonus := v_new_tile_score * catchup_policy_row.score_boost_rate;
  end if;

  v_total_score := case
    when v_score_blocked then 0
    else v_raw_total_score + v_catchup_bonus
  end;

  if v_score_blocked then
    v_severity := 'block';
  elsif v_repeat_suppressed > 0 then
    v_severity := 'warn';
  else
    v_severity := 'info';
  end if;

  if v_repeat_suppressed > 0 then
    insert into public.season_score_audit_logs (
      owner_user_id,
      walk_session_id,
      policy_key,
      severity,
      blocked,
      repeat_suppressed_count,
      novelty_ratio,
      session_distance_m,
      payload,
      created_at
    )
    values (
      session_owner,
      target_walk_session_id,
      policy_row.policy_key,
      v_severity,
      v_score_blocked,
      v_repeat_suppressed,
      v_novelty_ratio,
      v_total_distance_m,
      jsonb_build_object(
        'cooldown_minutes', policy_row.repeat_cooldown_minutes,
        'repeat_threshold', policy_row.suspicious_repeat_threshold,
        'novelty_limit', policy_row.suspicious_max_novelty_ratio,
        'distance_limit_m', policy_row.suspicious_low_movement_meters,
        'score_before_block', v_raw_total_score,
        'scored_at', now_ts
      ),
      now_ts
    );
  end if;

  if v_catchup_status = 'granted' then
    insert into public.season_score_audit_logs (
      owner_user_id,
      walk_session_id,
      policy_key,
      severity,
      blocked,
      repeat_suppressed_count,
      novelty_ratio,
      session_distance_m,
      payload,
      created_at
    )
    values (
      session_owner,
      target_walk_session_id,
      catchup_policy_row.policy_key,
      case when v_abuse_suspected then 'warn' else 'info' end,
      false,
      v_repeat_suppressed,
      v_novelty_ratio,
      v_total_distance_m,
      jsonb_build_object(
        'event', 'catchup_buff_granted',
        'granted_at', v_catchup_granted_at,
        'expires_at', v_catchup_expires_at,
        'boost_rate', catchup_policy_row.score_boost_rate,
        'weekly_grant_count', v_weekly_grant_count,
        'abuse_suspected', v_abuse_suspected
      ),
      now_ts
    );
  elsif v_catchup_status = 'blocked' and v_catchup_block_reason in ('season_end_window', 'weekly_limit_reached') then
    insert into public.season_score_audit_logs (
      owner_user_id,
      walk_session_id,
      policy_key,
      severity,
      blocked,
      repeat_suppressed_count,
      novelty_ratio,
      session_distance_m,
      payload,
      created_at
    )
    values (
      session_owner,
      target_walk_session_id,
      catchup_policy_row.policy_key,
      'info',
      false,
      v_repeat_suppressed,
      v_novelty_ratio,
      v_total_distance_m,
      jsonb_build_object(
        'event', 'catchup_buff_blocked',
        'reason', v_catchup_block_reason,
        'weekly_grant_count', v_weekly_grant_count,
        'season_end', v_week_end
      ),
      now_ts
    );
  end if;

  return query
  select
    target_walk_session_id as walk_session_id,
    v_total_points,
    v_unique_tiles,
    v_novelty_ratio,
    v_repeat_suppressed,
    v_suspicious_repeat,
    v_base_score,
    v_bonus_score,
    v_catchup_bonus,
    v_total_score,
    v_score_blocked,
    v_catchup_active,
    v_catchup_granted_at,
    v_catchup_expires_at,
    jsonb_build_object(
      'policy_key', policy_row.policy_key,
      'repeat_cooldown_minutes', policy_row.repeat_cooldown_minutes,
      'repeat_suppressed_count', v_repeat_suppressed,
      'novelty_ratio', v_novelty_ratio,
      'score_blocked', v_score_blocked,
      'ui_reason', case
        when v_score_blocked then '반복 패턴이 감지되어 이번 세션 시즌 점수가 차단되었습니다.'
        when v_repeat_suppressed > 0 then '동일 타일 반복 입력(30분 이내)은 점수에서 제외되었습니다.'
        else '신규 경로 중심 점수 규칙이 적용되었습니다.'
      end,
      'distance_m', v_total_distance_m,
      'scored_at', now_ts,
      'catchup_buff', jsonb_build_object(
        'status', v_catchup_status,
        'active', v_catchup_active,
        'granted_at', v_catchup_granted_at,
        'expires_at', v_catchup_expires_at,
        'boost_rate', catchup_policy_row.score_boost_rate,
        'bonus_score', v_catchup_bonus,
        'weekly_grant_count', v_weekly_grant_count,
        'weekly_limit', catchup_policy_row.weekly_issue_limit,
        'block_reason', v_catchup_block_reason,
        'abuse_suspected', v_abuse_suspected
      )
    ) as explain;
end;
$$;

create or replace view public.view_season_catchup_buff_kpis_14d as
select
  date_trunc('day', granted_at) as day_bucket,
  count(*)::bigint as issued_count,
  sum(case when abuse_flag then 1 else 0 end)::bigint as abuse_flag_count,
  avg(boost_rate)::double precision as avg_boost_rate
from public.season_catchup_buff_grants
group by date_trunc('day', granted_at)
having date_trunc('day', granted_at) >= date_trunc('day', now() - interval '14 day')
order by day_bucket desc;

grant select on public.season_catchup_buff_policies to anon, authenticated;
grant select on public.season_catchup_buff_grants to authenticated;
grant select on public.view_season_catchup_buff_kpis_14d to authenticated;
grant execute on function public.rpc_score_walk_session_anti_farming(uuid, timestamptz) to authenticated, service_role;
