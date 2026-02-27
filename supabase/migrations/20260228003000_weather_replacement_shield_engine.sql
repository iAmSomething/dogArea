-- #134 weather replacement + shield server engine

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

create table if not exists public.weather_replacement_runtime_policies (
  policy_key text primary key,
  daily_replacement_limit int not null default 1 check (daily_replacement_limit between 0 and 5),
  weekly_shield_limit int not null default 1 check (weekly_shield_limit between 0 and 7),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.weather_replacement_runtime_policies (
  policy_key,
  daily_replacement_limit,
  weekly_shield_limit,
  enabled
)
values (
  'weather_replacement_v1',
  1,
  1,
  true
)
on conflict (policy_key) do update
set daily_replacement_limit = excluded.daily_replacement_limit,
    weekly_shield_limit = excluded.weekly_shield_limit,
    enabled = excluded.enabled,
    updated_at = now();

create table if not exists public.weather_replacement_mappings (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null references public.weather_replacement_runtime_policies(policy_key) on delete cascade,
  risk_level text not null check (risk_level in ('caution', 'bad', 'severe')),
  source_quest_type text not null,
  replacement_quest_type text not null,
  reason_template text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (policy_key, risk_level, source_quest_type)
);

insert into public.weather_replacement_mappings (
  policy_key,
  risk_level,
  source_quest_type,
  replacement_quest_type,
  reason_template,
  is_active
)
values
  ('weather_replacement_v1', 'caution', 'outdoor.default', 'indoor.light', '기상 주의 단계로 실내 저강도 퀘스트로 자동 전환', true),
  ('weather_replacement_v1', 'bad', 'outdoor.default', 'indoor.routine', '악천후 단계로 실내 대체 퀘스트로 자동 전환', true),
  ('weather_replacement_v1', 'severe', 'outdoor.default', 'indoor.safety', '고위험 단계로 안전 중심 실내 퀘스트로 자동 전환', true)
on conflict (policy_key, risk_level, source_quest_type) do update
set replacement_quest_type = excluded.replacement_quest_type,
    reason_template = excluded.reason_template,
    is_active = excluded.is_active,
    updated_at = now();

create table if not exists public.weather_replacement_histories (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  walk_session_id uuid references public.walk_sessions(id) on delete set null,
  day_key date not null,
  risk_level text not null check (risk_level in ('caution', 'bad', 'severe')),
  source_quest_id text not null,
  replacement_quest_id text not null,
  replacement_reason text,
  shield_applied boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_weather_replacement_histories_owner_day
  on public.weather_replacement_histories(owner_user_id, day_key desc);
create index if not exists idx_weather_replacement_histories_session
  on public.weather_replacement_histories(walk_session_id);

create table if not exists public.weather_shield_ledgers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  walk_session_id uuid references public.walk_sessions(id) on delete set null,
  week_start date not null,
  day_key date not null,
  reason text,
  consumed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, week_start, walk_session_id)
);

create index if not exists idx_weather_shield_ledgers_owner_week
  on public.weather_shield_ledgers(owner_user_id, week_start desc);

alter table public.weather_replacement_runtime_policies enable row level security;
alter table public.weather_replacement_mappings enable row level security;
alter table public.weather_replacement_histories enable row level security;
alter table public.weather_shield_ledgers enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_replacement_runtime_policies'
      and policyname = 'weather_replacement_runtime_policies_select_all'
  ) then
    create policy weather_replacement_runtime_policies_select_all
      on public.weather_replacement_runtime_policies
      for select
      to anon, authenticated
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_replacement_mappings'
      and policyname = 'weather_replacement_mappings_select_all'
  ) then
    create policy weather_replacement_mappings_select_all
      on public.weather_replacement_mappings
      for select
      to anon, authenticated
      using (is_active = true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_replacement_histories'
      and policyname = 'weather_replacement_histories_owner_select'
  ) then
    create policy weather_replacement_histories_owner_select
      on public.weather_replacement_histories
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_replacement_histories'
      and policyname = 'weather_replacement_histories_service_write'
  ) then
    create policy weather_replacement_histories_service_write
      on public.weather_replacement_histories
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_shield_ledgers'
      and policyname = 'weather_shield_ledgers_owner_select'
  ) then
    create policy weather_shield_ledgers_owner_select
      on public.weather_shield_ledgers
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'weather_shield_ledgers'
      and policyname = 'weather_shield_ledgers_service_write'
  ) then
    create policy weather_shield_ledgers_service_write
      on public.weather_shield_ledgers
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_weather_replacement_runtime_policies_updated_at on public.weather_replacement_runtime_policies;
create trigger trg_weather_replacement_runtime_policies_updated_at
before update on public.weather_replacement_runtime_policies
for each row execute function public.touch_updated_at();

drop trigger if exists trg_weather_replacement_mappings_updated_at on public.weather_replacement_mappings;
create trigger trg_weather_replacement_mappings_updated_at
before update on public.weather_replacement_mappings
for each row execute function public.touch_updated_at();

drop trigger if exists trg_weather_replacement_histories_updated_at on public.weather_replacement_histories;
create trigger trg_weather_replacement_histories_updated_at
before update on public.weather_replacement_histories
for each row execute function public.touch_updated_at();

drop trigger if exists trg_weather_shield_ledgers_updated_at on public.weather_shield_ledgers;
create trigger trg_weather_shield_ledgers_updated_at
before update on public.weather_shield_ledgers
for each row execute function public.touch_updated_at();

create or replace function public.rpc_apply_weather_replacement(
  target_user_id uuid,
  target_walk_session_id uuid,
  target_risk_level text,
  source_quest_id text default 'outdoor.default',
  replaced_quest_id text default 'indoor.light',
  now_ts timestamptz default now()
)
returns table (
  applied boolean,
  shield_applied boolean,
  blocked_reason text,
  risk_level text,
  replacement_reason text,
  replacement_count_today int,
  daily_replacement_limit int,
  shield_used_this_week int,
  weekly_shield_limit int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  effective_user_id uuid;
  walk_owner uuid;
  policy_row public.weather_replacement_runtime_policies%rowtype;
  normalized_risk text;
  day_bucket date := (now_ts at time zone 'utc')::date;
  week_bucket date := date_trunc('week', now_ts)::date;
  replaced_today int := 0;
  shield_used_week int := 0;
  mapping_row public.weather_replacement_mappings%rowtype;
  should_apply_shield boolean := false;
  reason_text text := null;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();

  if requester_role <> 'service_role' and requester_uid is null then
    raise exception 'permission denied';
  end if;

  effective_user_id := coalesce(target_user_id, requester_uid);

  if requester_role <> 'service_role' and requester_uid <> effective_user_id then
    raise exception 'permission denied for user %', effective_user_id;
  end if;

  if target_walk_session_id is not null then
    select owner_user_id into walk_owner
    from public.walk_sessions
    where id = target_walk_session_id
    limit 1;

    if walk_owner is null then
      return query select false, false, 'walk_session_not_found', coalesce(target_risk_level, ''), null, 0, 0, 0, 0;
      return;
    end if;

    if walk_owner <> effective_user_id then
      raise exception 'permission denied for walk session %', target_walk_session_id;
    end if;
  end if;

  select * into policy_row
  from public.weather_replacement_runtime_policies
  where policy_key = 'weather_replacement_v1'
  limit 1;

  if not found then
    policy_row.policy_key := 'weather_replacement_v1';
    policy_row.daily_replacement_limit := 1;
    policy_row.weekly_shield_limit := 1;
    policy_row.enabled := true;
  end if;

  if policy_row.enabled is false then
    return query select false, false, 'policy_disabled', coalesce(target_risk_level, ''), null, 0, policy_row.daily_replacement_limit, 0, policy_row.weekly_shield_limit;
    return;
  end if;

  normalized_risk := lower(coalesce(target_risk_level, 'clear'));
  if normalized_risk not in ('caution', 'bad', 'severe') then
    return query select false, false, 'risk_clear_or_unknown', normalized_risk, null, 0, policy_row.daily_replacement_limit, 0, policy_row.weekly_shield_limit;
    return;
  end if;

  select count(*)::int
  into replaced_today
  from public.weather_replacement_histories h
  where h.owner_user_id = effective_user_id
    and h.day_key = day_bucket;

  if replaced_today >= policy_row.daily_replacement_limit then
    select count(*)::int
    into shield_used_week
    from public.weather_shield_ledgers s
    where s.owner_user_id = effective_user_id
      and s.week_start = week_bucket;

    return query select false, false, 'daily_limit_reached', normalized_risk, null, replaced_today, policy_row.daily_replacement_limit, shield_used_week, policy_row.weekly_shield_limit;
    return;
  end if;

  select * into mapping_row
  from public.weather_replacement_mappings m
  where m.policy_key = policy_row.policy_key
    and m.risk_level = normalized_risk
    and m.source_quest_type = coalesce(source_quest_id, 'outdoor.default')
    and m.is_active = true
  limit 1;

  if not found then
    select * into mapping_row
    from public.weather_replacement_mappings m
    where m.policy_key = policy_row.policy_key
      and m.risk_level = normalized_risk
      and m.source_quest_type = 'outdoor.default'
      and m.is_active = true
    limit 1;
  end if;

  reason_text := coalesce(mapping_row.reason_template, '날씨 위험도 기반 자동 치환');

  select count(*)::int
  into shield_used_week
  from public.weather_shield_ledgers s
  where s.owner_user_id = effective_user_id
    and s.week_start = week_bucket;

  should_apply_shield := shield_used_week < policy_row.weekly_shield_limit;

  insert into public.weather_replacement_histories (
    owner_user_id,
    walk_session_id,
    day_key,
    risk_level,
    source_quest_id,
    replacement_quest_id,
    replacement_reason,
    shield_applied,
    created_at,
    updated_at
  ) values (
    effective_user_id,
    target_walk_session_id,
    day_bucket,
    normalized_risk,
    coalesce(source_quest_id, 'outdoor.default'),
    coalesce(mapping_row.replacement_quest_type, replaced_quest_id, 'indoor.light'),
    reason_text,
    should_apply_shield,
    now_ts,
    now_ts
  );

  if should_apply_shield then
    insert into public.weather_shield_ledgers (
      owner_user_id,
      walk_session_id,
      week_start,
      day_key,
      reason,
      consumed_at,
      created_at,
      updated_at
    ) values (
      effective_user_id,
      target_walk_session_id,
      week_bucket,
      day_bucket,
      'weather_auto_protection',
      now_ts,
      now_ts,
      now_ts
    )
    on conflict (owner_user_id, week_start, walk_session_id) do nothing;

    select count(*)::int
    into shield_used_week
    from public.weather_shield_ledgers s
    where s.owner_user_id = effective_user_id
      and s.week_start = week_bucket;
  end if;

  return query select
    true,
    should_apply_shield,
    null::text,
    normalized_risk,
    reason_text,
    replaced_today + 1,
    policy_row.daily_replacement_limit,
    shield_used_week,
    policy_row.weekly_shield_limit;
end;
$$;

grant execute on function public.rpc_apply_weather_replacement(uuid, uuid, text, text, text, timestamptz)
to anon, authenticated, service_role;

create or replace view public.view_weather_replacement_audit_14d as
select
  day_key,
  risk_level,
  count(*)::bigint as replacement_count,
  count(*) filter (where shield_applied)::bigint as shield_applied_count
from public.weather_replacement_histories
where day_key >= (current_date - interval '14 day')::date
group by day_key, risk_level
order by day_key desc, risk_level asc;

grant select on public.view_weather_replacement_audit_14d to anon, authenticated;
