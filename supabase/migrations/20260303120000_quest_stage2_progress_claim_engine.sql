-- #128 quest stage2 progress/claim backend engine

create extension if not exists pgcrypto;

create table if not exists public.quest_templates (
  id text primary key,
  quest_scope text not null default 'daily' check (quest_scope in ('daily', 'weekly')),
  quest_type text not null,
  title text not null,
  description text not null default '',
  base_target_value double precision not null check (base_target_value > 0),
  reward_points integer not null default 0 check (reward_points >= 0),
  reward_tokens integer not null default 0 check (reward_tokens >= 0),
  reroll_group text not null default 'general',
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quest_instances (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  template_id text not null references public.quest_templates(id) on delete restrict,
  quest_scope text not null check (quest_scope in ('daily', 'weekly')),
  quest_type text not null,
  title_snapshot text not null,
  description_snapshot text not null default '',
  target_value_snapshot double precision not null check (target_value_snapshot > 0),
  reward_points_snapshot integer not null default 0 check (reward_points_snapshot >= 0),
  reward_tokens_snapshot integer not null default 0 check (reward_tokens_snapshot >= 0),
  progress_value double precision not null default 0 check (progress_value >= 0),
  status text not null default 'generated'
    check (status in ('generated', 'active', 'completed', 'claimed', 'expired', 'rerolled', 'alternative', 'replaced')),
  cycle_key text not null,
  replacement_source_instance_id uuid references public.quest_instances(id) on delete set null,
  rerolled_from_instance_id uuid references public.quest_instances(id) on delete set null,
  expires_at timestamptz not null,
  completed_at timestamptz,
  claimed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quest_progress (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  quest_instance_id uuid not null references public.quest_instances(id) on delete cascade,
  event_id text not null,
  event_type text not null default 'walk_event',
  delta_value double precision not null default 0 check (delta_value >= 0),
  payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (quest_instance_id, event_id)
);

create table if not exists public.quest_claims (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  quest_instance_id uuid not null references public.quest_instances(id) on delete cascade,
  request_id text not null,
  claim_status text not null default 'pending' check (claim_status in ('pending', 'claimed', 'rejected')),
  reward_points integer not null default 0 check (reward_points >= 0),
  reward_tokens integer not null default 0 check (reward_tokens >= 0),
  reason text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  claimed_at timestamptz,
  unique (quest_instance_id),
  unique (owner_user_id, request_id)
);

create table if not exists public.quest_claim_audit_logs (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  quest_instance_id uuid not null references public.quest_instances(id) on delete cascade,
  action text not null,
  detail text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_quest_instances_owner_template_cycle
  on public.quest_instances(owner_user_id, template_id, cycle_key);
create index if not exists idx_quest_instances_owner_status
  on public.quest_instances(owner_user_id, status, expires_at asc);
create index if not exists idx_quest_instances_scope_cycle
  on public.quest_instances(quest_scope, cycle_key, status);

create index if not exists idx_quest_progress_owner_created
  on public.quest_progress(owner_user_id, created_at desc);
create index if not exists idx_quest_progress_instance_created
  on public.quest_progress(quest_instance_id, created_at desc);

create index if not exists idx_quest_claims_owner_created
  on public.quest_claims(owner_user_id, created_at desc);
create index if not exists idx_quest_claim_audit_owner_action_created
  on public.quest_claim_audit_logs(owner_user_id, action, created_at desc);

alter table public.quest_templates enable row level security;
alter table public.quest_instances enable row level security;
alter table public.quest_progress enable row level security;
alter table public.quest_claims enable row level security;
alter table public.quest_claim_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_templates'
      and policyname = 'quest_templates_public_select'
  ) then
    create policy quest_templates_public_select
      on public.quest_templates
      for select
      to anon, authenticated
      using (is_active = true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_templates'
      and policyname = 'quest_templates_service_write'
  ) then
    create policy quest_templates_service_write
      on public.quest_templates
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_instances'
      and policyname = 'quest_instances_owner_select'
  ) then
    create policy quest_instances_owner_select
      on public.quest_instances
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_instances'
      and policyname = 'quest_instances_service_write'
  ) then
    create policy quest_instances_service_write
      on public.quest_instances
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_progress'
      and policyname = 'quest_progress_owner_select'
  ) then
    create policy quest_progress_owner_select
      on public.quest_progress
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_progress'
      and policyname = 'quest_progress_service_write'
  ) then
    create policy quest_progress_service_write
      on public.quest_progress
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_claims'
      and policyname = 'quest_claims_owner_select'
  ) then
    create policy quest_claims_owner_select
      on public.quest_claims
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_claims'
      and policyname = 'quest_claims_service_write'
  ) then
    create policy quest_claims_service_write
      on public.quest_claims
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_claim_audit_logs'
      and policyname = 'quest_claim_audit_logs_owner_select'
  ) then
    create policy quest_claim_audit_logs_owner_select
      on public.quest_claim_audit_logs
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'quest_claim_audit_logs'
      and policyname = 'quest_claim_audit_logs_service_write'
  ) then
    create policy quest_claim_audit_logs_service_write
      on public.quest_claim_audit_logs
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_quest_templates_updated_at on public.quest_templates;
create trigger trg_quest_templates_updated_at
before update on public.quest_templates
for each row execute function public.touch_updated_at();

drop trigger if exists trg_quest_instances_updated_at on public.quest_instances;
create trigger trg_quest_instances_updated_at
before update on public.quest_instances
for each row execute function public.touch_updated_at();

drop trigger if exists trg_quest_claims_updated_at on public.quest_claims;
create trigger trg_quest_claims_updated_at
before update on public.quest_claims
for each row execute function public.touch_updated_at();

insert into public.quest_templates (
  id,
  quest_scope,
  quest_type,
  title,
  description,
  base_target_value,
  reward_points,
  reward_tokens,
  reroll_group,
  is_active,
  metadata
)
values
  (
    'daily.walk_duration.normal',
    'daily',
    'walk_duration',
    '산책 30분 달성',
    '오늘 누적 산책 시간을 30분 이상 달성하세요.',
    30,
    120,
    8,
    'daily_core',
    true,
    jsonb_build_object('tier', 'Normal')
  ),
  (
    'daily.new_tile.easy',
    'daily',
    'new_tile',
    '새 타일 3개 개척',
    '새로운 산책 타일을 3개 이상 점령하세요.',
    3,
    90,
    6,
    'daily_core',
    true,
    jsonb_build_object('tier', 'Easy')
  ),
  (
    'daily.linked_path.normal',
    'daily',
    'linked_path',
    '연결 경로 8칸',
    '연속된 경로를 8칸 이상 연결하세요.',
    8,
    110,
    7,
    'daily_core',
    true,
    jsonb_build_object('tier', 'Normal')
  ),
  (
    'weekly.streak_days.hard',
    'weekly',
    'streak_days',
    '주간 5일 연속 산책',
    '이번 주 5일 이상 산책을 유지하세요.',
    5,
    500,
    24,
    'weekly_core',
    true,
    jsonb_build_object('tier', 'Hard')
  )
on conflict (id) do update
set
  quest_scope = excluded.quest_scope,
  quest_type = excluded.quest_type,
  title = excluded.title,
  description = excluded.description,
  base_target_value = excluded.base_target_value,
  reward_points = excluded.reward_points,
  reward_tokens = excluded.reward_tokens,
  reroll_group = excluded.reroll_group,
  is_active = excluded.is_active,
  metadata = excluded.metadata,
  updated_at = now();

create or replace function public.quest_cycle_key(
  scope text,
  now_ts timestamptz default now()
)
returns text
language sql
stable
as $$
  select case lower(coalesce(scope, 'daily'))
    when 'weekly' then to_char(date_trunc('week', timezone('utc', now_ts))::date, 'IYYY-"W"IW')
    else to_char((timezone('utc', now_ts))::date, 'YYYY-MM-DD')
  end;
$$;

create or replace function public.quest_scope_expires_at(
  scope text,
  now_ts timestamptz default now()
)
returns timestamptz
language sql
stable
as $$
  select case lower(coalesce(scope, 'daily'))
    when 'weekly' then date_trunc('week', timezone('utc', now_ts)) + interval '7 days' - interval '1 second'
    else date_trunc('day', timezone('utc', now_ts)) + interval '1 day' - interval '1 second'
  end;
$$;

create or replace function public.rpc_issue_quest_instances(
  target_user_id uuid default auth.uid(),
  target_scope text default 'daily',
  target_cycle_key text default null,
  expires_at timestamptz default null,
  now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  owner_user_id uuid,
  template_id text,
  quest_type text,
  target_value_snapshot double precision,
  progress_value double precision,
  status text,
  cycle_key text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  effective_user_id uuid;
  normalized_scope text;
  effective_cycle_key text;
  effective_expires_at timestamptz;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  effective_user_id := coalesce(target_user_id, requester_uid);
  normalized_scope := lower(coalesce(target_scope, 'daily'));

  if normalized_scope not in ('daily', 'weekly') then
    raise exception 'invalid target_scope: %', normalized_scope;
  end if;

  if requester_role <> 'service_role' then
    if requester_uid is null or effective_user_id is null or requester_uid <> effective_user_id then
      raise exception 'unauthorized quest issue request';
    end if;
  end if;

  effective_cycle_key := coalesce(nullif(trim(target_cycle_key), ''), public.quest_cycle_key(normalized_scope, now_ts));
  effective_expires_at := coalesce(expires_at, public.quest_scope_expires_at(normalized_scope, now_ts));

  insert into public.quest_instances (
    owner_user_id,
    template_id,
    quest_scope,
    quest_type,
    title_snapshot,
    description_snapshot,
    target_value_snapshot,
    reward_points_snapshot,
    reward_tokens_snapshot,
    progress_value,
    status,
    cycle_key,
    expires_at,
    metadata
  )
  select
    effective_user_id,
    t.id,
    t.quest_scope,
    t.quest_type,
    t.title,
    t.description,
    t.base_target_value,
    t.reward_points,
    t.reward_tokens,
    0,
    'active',
    effective_cycle_key,
    effective_expires_at,
    jsonb_build_object(
      'issued_by', 'rpc_issue_quest_instances',
      'issued_at', now_ts,
      'snapshot_fixed', true
    )
  from public.quest_templates t
  where t.is_active = true
    and t.quest_scope = normalized_scope
  on conflict (owner_user_id, template_id, cycle_key) do update
  set
    updated_at = now(),
    expires_at = greatest(public.quest_instances.expires_at, excluded.expires_at),
    status = case
      when public.quest_instances.status in ('generated', 'active') then public.quest_instances.status
      when public.quest_instances.status = 'completed' then 'completed'
      when public.quest_instances.status = 'claimed' then 'claimed'
      else public.quest_instances.status
    end;

  return query
  select
    qi.id,
    qi.owner_user_id,
    qi.template_id,
    qi.quest_type,
    qi.target_value_snapshot,
    qi.progress_value,
    qi.status,
    qi.cycle_key,
    qi.expires_at
  from public.quest_instances qi
  where qi.owner_user_id = effective_user_id
    and qi.quest_scope = normalized_scope
    and qi.cycle_key = effective_cycle_key
  order by qi.template_id asc;
end;
$$;

create or replace function public.rpc_apply_quest_progress_event(
  target_user_id uuid default auth.uid(),
  target_instance_id uuid default null,
  event_id text default null,
  event_type text default 'walk_event',
  delta_value double precision default 1,
  payload jsonb default '{}'::jsonb,
  now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  owner_user_id uuid,
  event_id text,
  idempotent boolean,
  previous_progress double precision,
  current_progress double precision,
  target_progress double precision,
  status text,
  completed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  effective_user_id uuid;
  normalized_event_id text;
  normalized_event_type text;
  normalized_delta double precision;
  instance_row public.quest_instances%rowtype;
  inserted_progress_id bigint;
  next_progress double precision;
  next_status text;
  next_completed_at timestamptz;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  effective_user_id := coalesce(target_user_id, requester_uid);
  normalized_event_id := nullif(trim(coalesce(event_id, '')), '');
  normalized_event_type := coalesce(nullif(trim(event_type), ''), 'walk_event');
  normalized_delta := greatest(coalesce(delta_value, 0), 0);

  if requester_role <> 'service_role' then
    if requester_uid is null or effective_user_id is null or requester_uid <> effective_user_id then
      raise exception 'unauthorized quest progress request';
    end if;
  end if;

  if target_instance_id is null then
    raise exception 'target_instance_id is required';
  end if;

  if normalized_event_id is null then
    raise exception 'event_id is required';
  end if;

  select *
  into instance_row
  from public.quest_instances
  where id = target_instance_id
  for update;

  if instance_row.id is null then
    raise exception 'quest instance not found: %', target_instance_id;
  end if;

  if requester_role <> 'service_role' and instance_row.owner_user_id <> effective_user_id then
    raise exception 'forbidden quest instance access';
  end if;

  if normalized_delta <= 0 then
    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      normalized_event_id,
      true,
      instance_row.progress_value,
      instance_row.progress_value,
      instance_row.target_value_snapshot,
      instance_row.status,
      instance_row.completed_at;
    return;
  end if;

  if instance_row.status not in ('generated', 'active', 'completed') then
    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      normalized_event_id,
      true,
      instance_row.progress_value,
      instance_row.progress_value,
      instance_row.target_value_snapshot,
      instance_row.status,
      instance_row.completed_at;
    return;
  end if;

  insert into public.quest_progress (
    owner_user_id,
    quest_instance_id,
    event_id,
    event_type,
    delta_value,
    payload,
    recorded_at
  )
  values (
    instance_row.owner_user_id,
    instance_row.id,
    normalized_event_id,
    normalized_event_type,
    normalized_delta,
    coalesce(payload, '{}'::jsonb),
    now_ts
  )
  on conflict (quest_instance_id, event_id) do nothing
  returning id into inserted_progress_id;

  if inserted_progress_id is null then
    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      normalized_event_id,
      true,
      instance_row.progress_value,
      instance_row.progress_value,
      instance_row.target_value_snapshot,
      instance_row.status,
      instance_row.completed_at;
    return;
  end if;

  next_progress := least(instance_row.target_value_snapshot, instance_row.progress_value + normalized_delta);
  next_status := case
    when next_progress >= instance_row.target_value_snapshot then 'completed'
    when instance_row.status = 'generated' then 'active'
    else instance_row.status
  end;

  update public.quest_instances
  set
    progress_value = next_progress,
    status = next_status,
    completed_at = case
      when next_status = 'completed' then coalesce(completed_at, now_ts)
      else completed_at
    end,
    updated_at = now()
  where id = instance_row.id
  returning completed_at into next_completed_at;

  return query
  select
    instance_row.id,
    instance_row.owner_user_id,
    normalized_event_id,
    false,
    instance_row.progress_value,
    next_progress,
    instance_row.target_value_snapshot,
    next_status,
    next_completed_at;
end;
$$;

create or replace function public.rpc_claim_quest_reward(
  target_user_id uuid default auth.uid(),
  target_instance_id uuid default null,
  request_id text default null,
  now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  owner_user_id uuid,
  claim_id bigint,
  claim_status text,
  already_claimed boolean,
  reward_points integer,
  reward_tokens integer,
  claimed_at timestamptz,
  audit_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  effective_user_id uuid;
  normalized_request_id text;
  instance_row public.quest_instances%rowtype;
  claim_row public.quest_claims%rowtype;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  effective_user_id := coalesce(target_user_id, requester_uid);
  normalized_request_id := coalesce(nullif(trim(coalesce(request_id, '')), ''), gen_random_uuid()::text);

  if requester_role <> 'service_role' then
    if requester_uid is null or effective_user_id is null or requester_uid <> effective_user_id then
      raise exception 'unauthorized quest claim request';
    end if;
  end if;

  if target_instance_id is null then
    raise exception 'target_instance_id is required';
  end if;

  select *
  into instance_row
  from public.quest_instances
  where id = target_instance_id
  for update;

  if instance_row.id is null then
    raise exception 'quest instance not found: %', target_instance_id;
  end if;

  if requester_role <> 'service_role' and instance_row.owner_user_id <> effective_user_id then
    raise exception 'forbidden quest instance access';
  end if;

  if instance_row.status = 'claimed' then
    select *
    into claim_row
    from public.quest_claims
    where quest_instance_id = instance_row.id
    limit 1;

    insert into public.quest_claim_audit_logs (
      owner_user_id,
      quest_instance_id,
      action,
      detail,
      payload
    )
    values (
      instance_row.owner_user_id,
      instance_row.id,
      'duplicate_claim_blocked',
      'already claimed instance',
      jsonb_build_object('request_id', normalized_request_id)
    );

    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      claim_row.id,
      coalesce(claim_row.claim_status, 'claimed'),
      true,
      coalesce(claim_row.reward_points, instance_row.reward_points_snapshot),
      coalesce(claim_row.reward_tokens, instance_row.reward_tokens_snapshot),
      coalesce(claim_row.claimed_at, instance_row.claimed_at),
      'duplicate_claim_blocked';
    return;
  end if;

  if instance_row.status <> 'completed' then
    insert into public.quest_claim_audit_logs (
      owner_user_id,
      quest_instance_id,
      action,
      detail,
      payload
    )
    values (
      instance_row.owner_user_id,
      instance_row.id,
      'claim_rejected',
      'instance is not completed',
      jsonb_build_object('request_id', normalized_request_id, 'status', instance_row.status)
    );

    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      null::bigint,
      'rejected',
      false,
      instance_row.reward_points_snapshot,
      instance_row.reward_tokens_snapshot,
      null::timestamptz,
      'claim_rejected';
    return;
  end if;

  insert into public.quest_claims (
    owner_user_id,
    quest_instance_id,
    request_id,
    claim_status,
    reward_points,
    reward_tokens,
    payload
  )
  values (
    instance_row.owner_user_id,
    instance_row.id,
    normalized_request_id,
    'pending',
    instance_row.reward_points_snapshot,
    instance_row.reward_tokens_snapshot,
    jsonb_build_object('requested_at', now_ts)
  )
  on conflict (quest_instance_id) do nothing
  returning * into claim_row;

  if claim_row.id is null then
    select *
    into claim_row
    from public.quest_claims
    where quest_instance_id = instance_row.id
    limit 1;

    insert into public.quest_claim_audit_logs (
      owner_user_id,
      quest_instance_id,
      action,
      detail,
      payload
    )
    values (
      instance_row.owner_user_id,
      instance_row.id,
      'duplicate_claim_blocked',
      'concurrent claim conflict',
      jsonb_build_object('request_id', normalized_request_id)
    );

    return query
    select
      instance_row.id,
      instance_row.owner_user_id,
      claim_row.id,
      coalesce(claim_row.claim_status, 'claimed'),
      true,
      coalesce(claim_row.reward_points, instance_row.reward_points_snapshot),
      coalesce(claim_row.reward_tokens, instance_row.reward_tokens_snapshot),
      coalesce(claim_row.claimed_at, instance_row.claimed_at),
      'duplicate_claim_blocked';
    return;
  end if;

  update public.quest_claims
  set
    claim_status = 'claimed',
    claimed_at = now_ts,
    updated_at = now(),
    payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object('confirmed_at', now_ts)
  where id = claim_row.id
  returning * into claim_row;

  update public.quest_instances
  set
    status = 'claimed',
    claimed_at = coalesce(claimed_at, now_ts),
    updated_at = now()
  where id = instance_row.id;

  insert into public.quest_claim_audit_logs (
    owner_user_id,
    quest_instance_id,
    action,
    detail,
    payload
  )
  values (
    instance_row.owner_user_id,
    instance_row.id,
    'claim_confirmed',
    'claim confirmed by server validation',
    jsonb_build_object('request_id', normalized_request_id, 'claim_id', claim_row.id)
  );

  return query
  select
    instance_row.id,
    instance_row.owner_user_id,
    claim_row.id,
    claim_row.claim_status,
    false,
    claim_row.reward_points,
    claim_row.reward_tokens,
    claim_row.claimed_at,
    'claim_confirmed';
end;
$$;

create or replace function public.rpc_transition_quest_status(
  target_user_id uuid default auth.uid(),
  target_instance_id uuid default null,
  transition_action text default null,
  replacement_template_id text default null,
  now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  previous_status text,
  current_status text,
  replacement_instance_id uuid,
  transition_action text,
  reroll_allowed boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  requester_role text;
  effective_user_id uuid;
  normalized_action text;
  normalized_replacement_template_id text;
  instance_row public.quest_instances%rowtype;
  previous_status_text text;
  replacement_template_row public.quest_templates%rowtype;
  created_replacement_id uuid;
  reroll_used_today boolean;
  cycle_date date;
begin
  requester_uid := auth.uid();
  requester_role := auth.role();
  effective_user_id := coalesce(target_user_id, requester_uid);
  normalized_action := lower(coalesce(transition_action, ''));
  normalized_replacement_template_id := nullif(trim(coalesce(replacement_template_id, '')), '');

  if requester_role <> 'service_role' then
    if requester_uid is null or effective_user_id is null or requester_uid <> effective_user_id then
      raise exception 'unauthorized quest transition request';
    end if;
  end if;

  if target_instance_id is null then
    raise exception 'target_instance_id is required';
  end if;

  if normalized_action not in ('expire', 'reroll', 'replace') then
    raise exception 'invalid transition_action: %', transition_action;
  end if;

  select *
  into instance_row
  from public.quest_instances
  where id = target_instance_id
  for update;

  if instance_row.id is null then
    raise exception 'quest instance not found: %', target_instance_id;
  end if;

  if requester_role <> 'service_role' and instance_row.owner_user_id <> effective_user_id then
    raise exception 'forbidden quest instance access';
  end if;

  previous_status_text := instance_row.status;

  if normalized_action = 'expire' then
    update public.quest_instances
    set
      status = case
        when status = 'claimed' then status
        else 'expired'
      end,
      updated_at = now()
    where id = instance_row.id
    returning * into instance_row;

    insert into public.quest_claim_audit_logs (
      owner_user_id,
      quest_instance_id,
      action,
      detail,
      payload
    )
    values (
      instance_row.owner_user_id,
      instance_row.id,
      'expire_transition',
      'quest moved to expired status',
      jsonb_build_object('requested_at', now_ts)
    );

    return query
    select
      instance_row.id,
      previous_status_text,
      instance_row.status,
      null::uuid,
      normalized_action,
      true;
    return;
  end if;

  if normalized_action = 'reroll' then
    cycle_date := (timezone('utc', now_ts))::date;

    select exists(
      select 1
      from public.quest_claim_audit_logs l
      where l.owner_user_id = instance_row.owner_user_id
        and l.action = 'reroll_transition'
        and (timezone('utc', l.created_at))::date = cycle_date
    )
    into reroll_used_today;

    if reroll_used_today then
      return query
      select
        instance_row.id,
        previous_status_text,
        instance_row.status,
        null::uuid,
        normalized_action,
        false;
      return;
    end if;

    update public.quest_instances
    set
      status = case
        when status = 'claimed' then status
        else 'rerolled'
      end,
      updated_at = now()
    where id = instance_row.id
    returning * into instance_row;

    if normalized_replacement_template_id is not null then
      select *
      into replacement_template_row
      from public.quest_templates t
      where t.id = normalized_replacement_template_id
        and t.is_active = true
      limit 1;
    else
      select *
      into replacement_template_row
      from public.quest_templates t
      where t.quest_scope = instance_row.quest_scope
        and t.is_active = true
        and t.id <> instance_row.template_id
      order by t.id asc
      limit 1;
    end if;

    if replacement_template_row.id is not null and instance_row.status <> 'claimed' then
      insert into public.quest_instances (
        owner_user_id,
        template_id,
        quest_scope,
        quest_type,
        title_snapshot,
        description_snapshot,
        target_value_snapshot,
        reward_points_snapshot,
        reward_tokens_snapshot,
        progress_value,
        status,
        cycle_key,
        expires_at,
        rerolled_from_instance_id,
        metadata
      )
      values (
        instance_row.owner_user_id,
        replacement_template_row.id,
        replacement_template_row.quest_scope,
        replacement_template_row.quest_type,
        replacement_template_row.title,
        replacement_template_row.description,
        replacement_template_row.base_target_value,
        replacement_template_row.reward_points,
        replacement_template_row.reward_tokens,
        0,
        'active',
        instance_row.cycle_key,
        instance_row.expires_at,
        instance_row.id,
        jsonb_build_object('transition', 'reroll', 'source_instance_id', instance_row.id, 'requested_at', now_ts)
      )
      on conflict (owner_user_id, template_id, cycle_key) do update
      set
        status = 'active',
        updated_at = now(),
        rerolled_from_instance_id = excluded.rerolled_from_instance_id
      returning id into created_replacement_id;
    end if;

    insert into public.quest_claim_audit_logs (
      owner_user_id,
      quest_instance_id,
      action,
      detail,
      payload
    )
    values (
      instance_row.owner_user_id,
      instance_row.id,
      'reroll_transition',
      'daily reroll consumed',
      jsonb_build_object('replacement_instance_id', created_replacement_id)
    );

    return query
    select
      instance_row.id,
      previous_status_text,
      instance_row.status,
      created_replacement_id,
      normalized_action,
      true;
    return;
  end if;

  -- replace transition: move current to alternative and create replacement quest snapshot
  update public.quest_instances
  set
    status = case
      when status = 'claimed' then status
      else 'alternative'
    end,
    updated_at = now()
  where id = instance_row.id
  returning * into instance_row;

  if normalized_replacement_template_id is not null then
    select *
    into replacement_template_row
    from public.quest_templates t
    where t.id = normalized_replacement_template_id
      and t.is_active = true
    limit 1;
  else
    select *
    into replacement_template_row
    from public.quest_templates t
    where t.quest_scope = instance_row.quest_scope
      and t.is_active = true
      and t.id <> instance_row.template_id
    order by t.id asc
    limit 1;
  end if;

  if replacement_template_row.id is not null and instance_row.status <> 'claimed' then
    insert into public.quest_instances (
      owner_user_id,
      template_id,
      quest_scope,
      quest_type,
      title_snapshot,
      description_snapshot,
      target_value_snapshot,
      reward_points_snapshot,
      reward_tokens_snapshot,
      progress_value,
      status,
      cycle_key,
      expires_at,
      replacement_source_instance_id,
      metadata
    )
    values (
      instance_row.owner_user_id,
      replacement_template_row.id,
      replacement_template_row.quest_scope,
      replacement_template_row.quest_type,
      replacement_template_row.title,
      replacement_template_row.description,
      replacement_template_row.base_target_value,
      replacement_template_row.reward_points,
      replacement_template_row.reward_tokens,
      0,
      'active',
      instance_row.cycle_key,
      instance_row.expires_at,
      instance_row.id,
      jsonb_build_object('transition', 'replace', 'source_instance_id', instance_row.id, 'requested_at', now_ts)
    )
    on conflict (owner_user_id, template_id, cycle_key) do update
    set
      status = 'active',
      updated_at = now(),
      replacement_source_instance_id = excluded.replacement_source_instance_id
    returning id into created_replacement_id;
  end if;

  insert into public.quest_claim_audit_logs (
    owner_user_id,
    quest_instance_id,
    action,
    detail,
    payload
  )
  values (
    instance_row.owner_user_id,
    instance_row.id,
    'replace_transition',
    'quest replaced with alternative quest',
    jsonb_build_object('replacement_instance_id', created_replacement_id)
  );

  return query
  select
    instance_row.id,
    previous_status_text,
    instance_row.status,
    created_replacement_id,
    normalized_action,
    true;
end;
$$;

revoke all on function public.rpc_issue_quest_instances(uuid, text, text, timestamptz, timestamptz) from public;
revoke all on function public.rpc_apply_quest_progress_event(uuid, uuid, text, text, double precision, jsonb, timestamptz) from public;
revoke all on function public.rpc_claim_quest_reward(uuid, uuid, text, timestamptz) from public;
revoke all on function public.rpc_transition_quest_status(uuid, uuid, text, text, timestamptz) from public;

grant execute on function public.rpc_issue_quest_instances(uuid, text, text, timestamptz, timestamptz) to authenticated, service_role;
grant execute on function public.rpc_apply_quest_progress_event(uuid, uuid, text, text, double precision, jsonb, timestamptz) to authenticated, service_role;
grant execute on function public.rpc_claim_quest_reward(uuid, uuid, text, timestamptz) to authenticated, service_role;
grant execute on function public.rpc_transition_quest_status(uuid, uuid, text, text, timestamptz) to authenticated, service_role;
