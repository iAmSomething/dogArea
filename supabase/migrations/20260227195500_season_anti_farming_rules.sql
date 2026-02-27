-- #146 season anti-farming rules (same tile repeat suppression + novelty bonus)

create extension if not exists pgcrypto;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.season_scoring_policies (
  policy_key text primary key,
  repeat_cooldown_minutes integer not null default 30 check (repeat_cooldown_minutes between 1 and 180),
  tile_decimal_precision integer not null default 3 check (tile_decimal_precision between 2 and 5),
  base_tile_score double precision not null default 1.0 check (base_tile_score >= 0),
  new_route_bonus_weight double precision not null default 0.7 check (new_route_bonus_weight >= 0 and new_route_bonus_weight <= 3),
  suspicious_repeat_threshold integer not null default 10 check (suspicious_repeat_threshold between 3 and 100),
  suspicious_max_novelty_ratio double precision not null default 0.35 check (suspicious_max_novelty_ratio >= 0 and suspicious_max_novelty_ratio <= 1),
  suspicious_low_movement_meters double precision not null default 120 check (suspicious_low_movement_meters >= 0),
  suspicious_block_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.season_scoring_policies (
  policy_key,
  repeat_cooldown_minutes,
  tile_decimal_precision,
  base_tile_score,
  new_route_bonus_weight,
  suspicious_repeat_threshold,
  suspicious_max_novelty_ratio,
  suspicious_low_movement_meters,
  suspicious_block_enabled
)
values (
  'season_tile_anti_farming_v1',
  30,
  3,
  1.0,
  0.7,
  10,
  0.35,
  120,
  true
)
on conflict (policy_key) do nothing;

create table if not exists public.season_tile_score_events (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  walk_session_id uuid not null references public.walk_sessions(id) on delete cascade,
  seq_no integer not null,
  geotile text not null,
  recorded_at timestamptz not null,
  is_first_tile_hit boolean not null,
  is_repeat_within_cooldown boolean not null,
  distance_from_prev_m double precision not null default 0,
  novelty_ratio double precision not null default 0,
  base_score double precision not null default 0,
  novelty_bonus double precision not null default 0,
  final_score double precision not null default 0,
  suppression_reason text,
  created_at timestamptz not null default now(),
  constraint season_tile_score_events_session_seq_unique unique (walk_session_id, seq_no)
);

create index if not exists idx_season_tile_score_events_session
  on public.season_tile_score_events(walk_session_id, seq_no);
create index if not exists idx_season_tile_score_events_owner_created
  on public.season_tile_score_events(owner_user_id, created_at desc);

create table if not exists public.season_score_audit_logs (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  walk_session_id uuid not null references public.walk_sessions(id) on delete cascade,
  policy_key text not null,
  severity text not null check (severity in ('info', 'warn', 'block')),
  blocked boolean not null default false,
  repeat_suppressed_count integer not null default 0,
  novelty_ratio double precision not null default 0,
  session_distance_m double precision not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_season_score_audit_owner_created
  on public.season_score_audit_logs(owner_user_id, created_at desc);
create index if not exists idx_season_score_audit_severity_created
  on public.season_score_audit_logs(severity, created_at desc);

alter table public.season_scoring_policies enable row level security;
alter table public.season_tile_score_events enable row level security;
alter table public.season_score_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_scoring_policies'
      and policyname = 'season_scoring_policies_select_all'
  ) then
    create policy season_scoring_policies_select_all
      on public.season_scoring_policies
      for select
      to anon, authenticated
      using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_tile_score_events'
      and policyname = 'season_tile_score_events_owner_select'
  ) then
    create policy season_tile_score_events_owner_select
      on public.season_tile_score_events
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_tile_score_events'
      and policyname = 'season_tile_score_events_service_write'
  ) then
    create policy season_tile_score_events_service_write
      on public.season_tile_score_events
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_score_audit_logs'
      and policyname = 'season_score_audit_logs_owner_select'
  ) then
    create policy season_score_audit_logs_owner_select
      on public.season_score_audit_logs
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_score_audit_logs'
      and policyname = 'season_score_audit_logs_service_write'
  ) then
    create policy season_score_audit_logs_service_write
      on public.season_score_audit_logs
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

drop trigger if exists trg_season_scoring_policies_updated_at on public.season_scoring_policies;
create trigger trg_season_scoring_policies_updated_at
before update on public.season_scoring_policies
for each row execute function public.touch_updated_at();

create or replace function public.season_tile_key_from_coord(
  lat double precision,
  lng double precision,
  precision_digits integer default 3
)
returns text
language sql
immutable
as $$
  select concat(
    round(lat::numeric, least(5, greatest(2, precision_digits)))::text,
    ',',
    round(lng::numeric, least(5, greatest(2, precision_digits)))::text
  );
$$;

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
  total_score double precision,
  score_blocked boolean,
  explain jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  policy_row public.season_scoring_policies%rowtype;
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

  v_total_score := case when v_score_blocked then 0 else v_raw_total_score end;

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
    v_total_score,
    v_score_blocked,
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
      'scored_at', now_ts
    ) as explain;
end;
$$;

create or replace view public.view_season_score_audit_24h as
select
  date_trunc('hour', created_at) as hour_bucket,
  severity,
  count(*)::bigint as event_count,
  sum(case when blocked then 1 else 0 end)::bigint as blocked_count
from public.season_score_audit_logs
where created_at >= now() - interval '24 hours'
group by date_trunc('hour', created_at), severity
order by hour_bucket desc, severity asc;

grant select on public.season_scoring_policies to anon, authenticated;
grant select on public.season_tile_score_events to authenticated;
grant select on public.season_score_audit_logs to authenticated;
grant execute on function public.rpc_score_walk_session_anti_farming(uuid, timestamptz) to authenticated, service_role;
grant select on public.view_season_score_audit_24h to authenticated;
