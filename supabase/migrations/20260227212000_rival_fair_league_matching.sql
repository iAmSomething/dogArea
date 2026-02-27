-- #149 rival fair league matching (14-day activity band)

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

create table if not exists public.rival_league_policies (
  policy_key text primary key,
  lookback_days integer not null default 14 check (lookback_days between 7 and 30),
  weekly_refresh_interval_days integer not null default 7 check (weekly_refresh_interval_days between 1 and 14),
  onboarding_protection_days integer not null default 14 check (onboarding_protection_days between 1 and 30),
  min_sessions_for_ranked integer not null default 2 check (min_sessions_for_ranked between 1 and 20),
  min_sample_per_league integer not null default 20 check (min_sample_per_league between 2 and 200),
  light_max_percentile double precision not null default 0.33 check (light_max_percentile > 0 and light_max_percentile < 1),
  mid_max_percentile double precision not null default 0.66 check (mid_max_percentile > 0 and mid_max_percentile < 1),
  area_weight double precision not null default 0.4 check (area_weight >= 0 and area_weight <= 1),
  duration_weight double precision not null default 0.6 check (duration_weight >= 0 and duration_weight <= 1),
  updated_at timestamptz not null default now(),
  constraint rival_league_percentile_order check (light_max_percentile < mid_max_percentile),
  constraint rival_league_weight_sum check (abs((area_weight + duration_weight) - 1.0) < 0.000001)
);

insert into public.rival_league_policies (
  policy_key,
  lookback_days,
  weekly_refresh_interval_days,
  onboarding_protection_days,
  min_sessions_for_ranked,
  min_sample_per_league,
  light_max_percentile,
  mid_max_percentile,
  area_weight,
  duration_weight
)
values (
  'rival_league_v1',
  14,
  7,
  14,
  2,
  20,
  0.33,
  0.66,
  0.4,
  0.6
)
on conflict (policy_key) do nothing;

create table if not exists public.rival_league_assignments (
  user_id uuid primary key references auth.users(id) on delete cascade,
  snapshot_week_start date not null,
  league text not null check (league in ('onboarding', 'light', 'mid', 'hardcore')),
  effective_league text not null check (effective_league in ('onboarding', 'light', 'mid', 'hardcore')),
  activity_score double precision not null default 0,
  activity_days integer not null default 0,
  session_count integer not null default 0,
  percentile_rank double precision not null default 0,
  fallback_applied boolean not null default false,
  fallback_reason text,
  reason text not null default 'weekly_rebalance',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_rival_league_assignments_snapshot
  on public.rival_league_assignments(snapshot_week_start desc, effective_league, league);

create table if not exists public.rival_league_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  from_league text check (from_league in ('onboarding', 'light', 'mid', 'hardcore')),
  to_league text not null check (to_league in ('onboarding', 'light', 'mid', 'hardcore')),
  from_effective_league text check (from_effective_league in ('onboarding', 'light', 'mid', 'hardcore')),
  to_effective_league text not null check (to_effective_league in ('onboarding', 'light', 'mid', 'hardcore')),
  snapshot_week_start date not null,
  change_reason text not null,
  activity_score double precision not null default 0,
  percentile_rank double precision not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_rival_league_history_user_created
  on public.rival_league_history(user_id, created_at desc);
create index if not exists idx_rival_league_history_snapshot
  on public.rival_league_history(snapshot_week_start desc, to_effective_league);

alter table public.rival_league_policies enable row level security;
alter table public.rival_league_assignments enable row level security;
alter table public.rival_league_history enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_league_policies'
      and policyname = 'rival_league_policies_select_all'
  ) then
    create policy rival_league_policies_select_all
      on public.rival_league_policies
      for select
      to anon, authenticated
      using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_league_assignments'
      and policyname = 'rival_league_assignments_owner_select'
  ) then
    create policy rival_league_assignments_owner_select
      on public.rival_league_assignments
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_league_assignments'
      and policyname = 'rival_league_assignments_service_write'
  ) then
    create policy rival_league_assignments_service_write
      on public.rival_league_assignments
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_league_history'
      and policyname = 'rival_league_history_owner_select'
  ) then
    create policy rival_league_history_owner_select
      on public.rival_league_history
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rival_league_history'
      and policyname = 'rival_league_history_service_write'
  ) then
    create policy rival_league_history_service_write
      on public.rival_league_history
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

drop trigger if exists trg_rival_league_policies_updated_at on public.rival_league_policies;
create trigger trg_rival_league_policies_updated_at
before update on public.rival_league_policies
for each row execute function public.touch_updated_at();

drop trigger if exists trg_rival_league_assignments_updated_at on public.rival_league_assignments;
create trigger trg_rival_league_assignments_updated_at
before update on public.rival_league_assignments
for each row execute function public.touch_updated_at();

create or replace function public.rpc_refresh_rival_leagues(
  target_snapshot_week_start date default date_trunc('week', now())::date,
  now_ts timestamptz default now()
)
returns table (
  snapshot_week_start date,
  total_users int,
  onboarding_users int,
  light_users int,
  mid_users int,
  hardcore_users int,
  fallback_users int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  policy_row public.rival_league_policies%rowtype;
begin
  select *
  into policy_row
  from public.rival_league_policies
  where policy_key = 'rival_league_v1'
  limit 1;

  if not found then
    policy_row.lookback_days := 14;
    policy_row.weekly_refresh_interval_days := 7;
    policy_row.onboarding_protection_days := 14;
    policy_row.min_sessions_for_ranked := 2;
    policy_row.min_sample_per_league := 20;
    policy_row.light_max_percentile := 0.33;
    policy_row.mid_max_percentile := 0.66;
    policy_row.area_weight := 0.4;
    policy_row.duration_weight := 0.6;
  end if;

  create temporary table if not exists tmp_prev_rival_league_assignments on commit drop as
  select
    user_id,
    league,
    effective_league
  from public.rival_league_assignments;
  truncate table tmp_prev_rival_league_assignments;
  insert into tmp_prev_rival_league_assignments (user_id, league, effective_league)
  select user_id, league, effective_league
  from public.rival_league_assignments;

  with base_users as (
    select id as user_id, created_at
    from auth.users
  ),
  activity as (
    select
      bu.user_id,
      bu.created_at,
      coalesce(count(ws.id), 0)::int as session_count,
      coalesce(count(distinct (ws.started_at at time zone 'UTC')::date), 0)::int as activity_days,
      coalesce(sum(ws.duration_sec), 0)::double precision as total_duration_sec,
      coalesce(sum(ws.area_m2), 0)::double precision as total_area_m2,
      coalesce(sum(ws.duration_sec), 0)::double precision / 60.0 * policy_row.duration_weight +
      coalesce(sum(ws.area_m2), 0)::double precision / 10000.0 * policy_row.area_weight as activity_score
    from base_users bu
    left join public.walk_sessions ws
      on ws.owner_user_id = bu.user_id
     and ws.started_at >= now_ts - make_interval(days => policy_row.lookback_days)
    group by bu.user_id, bu.created_at
  ),
  ranked as (
    select
      a.*,
      case
        when a.session_count = 0 then 0::double precision
        else percent_rank() over (order by a.activity_score asc, a.user_id)
      end as percentile_rank,
      (
        a.created_at >= now_ts - make_interval(days => policy_row.onboarding_protection_days)
        or a.session_count < policy_row.min_sessions_for_ranked
      ) as is_onboarding
    from activity a
  ),
  classified as (
    select
      r.user_id,
      target_snapshot_week_start as snapshot_week_start,
      case
        when r.is_onboarding then 'onboarding'
        when r.percentile_rank <= policy_row.light_max_percentile then 'light'
        when r.percentile_rank <= policy_row.mid_max_percentile then 'mid'
        else 'hardcore'
      end as league,
      r.activity_score,
      r.activity_days,
      r.session_count,
      r.percentile_rank,
      case
        when r.is_onboarding then 'onboarding_protection'
        else 'weekly_rebalance'
      end as reason
    from ranked r
  )
  insert into public.rival_league_assignments (
    user_id,
    snapshot_week_start,
    league,
    effective_league,
    activity_score,
    activity_days,
    session_count,
    percentile_rank,
    fallback_applied,
    fallback_reason,
    reason,
    updated_at
  )
  select
    c.user_id,
    c.snapshot_week_start,
    c.league,
    c.league,
    c.activity_score,
    c.activity_days,
    c.session_count,
    c.percentile_rank,
    false,
    null,
    c.reason,
    now_ts
  from classified c
  on conflict (user_id) do update set
    snapshot_week_start = excluded.snapshot_week_start,
    league = excluded.league,
    effective_league = excluded.effective_league,
    activity_score = excluded.activity_score,
    activity_days = excluded.activity_days,
    session_count = excluded.session_count,
    percentile_rank = excluded.percentile_rank,
    fallback_applied = excluded.fallback_applied,
    fallback_reason = excluded.fallback_reason,
    reason = excluded.reason,
    updated_at = now_ts;

  with league_counts as (
    select league, count(*)::int as member_count
    from public.rival_league_assignments
    where snapshot_week_start = target_snapshot_week_start
    group by league
  ),
  resolved as (
    select
      a.user_id,
      a.league,
      coalesce(lc.member_count, 0) as league_member_count,
      case
        when a.league = 'onboarding' then 'onboarding'
        when coalesce(lc.member_count, 0) >= policy_row.min_sample_per_league then a.league
        when a.league = 'light' then 'mid'
        when a.league = 'hardcore' then 'mid'
        when a.league = 'mid' then (
          case
            when coalesce(lh.member_count, 0) >= coalesce(ll.member_count, 0) then 'hardcore'
            else 'light'
          end
        )
        else a.league
      end as effective_league,
      case
        when a.league = 'onboarding' then null
        when coalesce(lc.member_count, 0) >= policy_row.min_sample_per_league then null
        when a.league in ('light', 'mid', 'hardcore') then 'insufficient_samples'
        else null
      end as fallback_reason
    from public.rival_league_assignments a
    left join league_counts lc on lc.league = a.league
    left join league_counts ll on ll.league = 'light'
    left join league_counts lh on lh.league = 'hardcore'
    where a.snapshot_week_start = target_snapshot_week_start
  )
  update public.rival_league_assignments a
  set
    effective_league = r.effective_league,
    fallback_applied = (r.fallback_reason is not null),
    fallback_reason = r.fallback_reason,
    updated_at = now_ts
  from resolved r
  where a.user_id = r.user_id
    and a.snapshot_week_start = target_snapshot_week_start;

  insert into public.rival_league_history (
    user_id,
    from_league,
    to_league,
    from_effective_league,
    to_effective_league,
    snapshot_week_start,
    change_reason,
    activity_score,
    percentile_rank,
    created_at
  )
  select
    a.user_id,
    p.league,
    a.league,
    p.effective_league,
    a.effective_league,
    target_snapshot_week_start,
    case
      when p.user_id is null then 'initial_assignment'
      when p.league is distinct from a.league then 'weekly_rebalance'
      when p.effective_league is distinct from a.effective_league then 'fallback_rebalance'
      else 'no_change'
    end as change_reason,
    a.activity_score,
    a.percentile_rank,
    now_ts
  from public.rival_league_assignments a
  left join tmp_prev_rival_league_assignments p
    on p.user_id = a.user_id
  where a.snapshot_week_start = target_snapshot_week_start
    and (
      p.user_id is null
      or p.league is distinct from a.league
      or p.effective_league is distinct from a.effective_league
    );

  return query
  select
    target_snapshot_week_start as snapshot_week_start,
    count(*)::int as total_users,
    count(*) filter (where league = 'onboarding')::int as onboarding_users,
    count(*) filter (where league = 'light')::int as light_users,
    count(*) filter (where league = 'mid')::int as mid_users,
    count(*) filter (where league = 'hardcore')::int as hardcore_users,
    count(*) filter (where fallback_applied)::int as fallback_users
  from public.rival_league_assignments
  where snapshot_week_start = target_snapshot_week_start;
end;
$$;

create or replace function public.rpc_get_my_rival_league(
  requested_user_id uuid default auth.uid(),
  now_ts timestamptz default now()
)
returns table (
  user_id uuid,
  snapshot_week_start date,
  league text,
  effective_league text,
  fallback_applied boolean,
  fallback_reason text,
  activity_score double precision,
  percentile_rank double precision,
  sample_count int,
  guidance_message text,
  is_stale boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  assignment_row public.rival_league_assignments%rowtype;
  effective_member_count int := 0;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();

  if requester_role <> 'service_role' then
    if requested_user_id is null or requester_uid is null or requested_user_id <> requester_uid then
      raise exception 'permission denied';
    end if;
  end if;

  select *
  into assignment_row
  from public.rival_league_assignments
  where user_id = requested_user_id
  order by snapshot_week_start desc
  limit 1;

  if not found then
    return query
    select
      requested_user_id,
      date_trunc('week', now_ts)::date,
      'onboarding'::text,
      'onboarding'::text,
      false,
      null::text,
      0::double precision,
      0::double precision,
      0::int,
      '온보딩 보호 리그입니다. 최근 14일 활동이 쌓이면 주간 리그가 배정됩니다.'::text,
      true;
    return;
  end if;

  select count(*)::int
  into effective_member_count
  from public.rival_league_assignments
  where snapshot_week_start = assignment_row.snapshot_week_start
    and effective_league = assignment_row.effective_league;

  return query
  select
    assignment_row.user_id,
    assignment_row.snapshot_week_start,
    assignment_row.league,
    assignment_row.effective_league,
    assignment_row.fallback_applied,
    assignment_row.fallback_reason,
    assignment_row.activity_score,
    assignment_row.percentile_rank,
    effective_member_count,
    case
      when assignment_row.league = 'onboarding' then '온보딩 보호 리그입니다. 최근 14일 활동이 쌓이면 주간 리그가 배정됩니다.'
      when assignment_row.fallback_applied then '현재 리그 표본이 부족해 인접 리그와 매칭 중입니다.'
      else '최근 14일 활동량 기준으로 주간 리그가 배정되었습니다.'
    end,
    assignment_row.snapshot_week_start < date_trunc('week', now_ts)::date;
end;
$$;

create or replace view public.view_rival_league_distribution_current as
with latest as (
  select max(snapshot_week_start) as snapshot_week_start
  from public.rival_league_assignments
)
select
  a.snapshot_week_start,
  a.league,
  a.effective_league,
  count(*)::bigint as user_count,
  avg(a.activity_score)::double precision as avg_activity_score,
  min(a.activity_score)::double precision as min_activity_score,
  max(a.activity_score)::double precision as max_activity_score,
  sum(case when a.fallback_applied then 1 else 0 end)::bigint as fallback_count
from public.rival_league_assignments a
join latest l on l.snapshot_week_start = a.snapshot_week_start
group by a.snapshot_week_start, a.league, a.effective_league
order by a.effective_league, a.league;

grant execute on function public.rpc_refresh_rival_leagues(date, timestamptz) to service_role;
grant execute on function public.rpc_get_my_rival_league(uuid, timestamptz) to authenticated, service_role;
grant select on public.view_rival_league_distribution_current to anon, authenticated;
