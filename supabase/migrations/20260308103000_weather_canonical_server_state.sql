-- #475 canonicalize weather replacement / shield / feedback state on server

alter table public.weather_replacement_runtime_policies
  add column if not exists weekly_feedback_limit integer not null default 2;

create or replace function public.normalize_indoor_weather_risk(raw text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(trim(raw), 'clear'))
    when 'clear' then 'clear'
    when 'caution' then 'caution'
    when 'bad' then 'bad'
    when 'severe' then 'severe'
    else 'clear'
  end;
$$;

create or replace function public.indoor_weather_risk_index(risk text)
returns integer
language sql
immutable
as $$
  select case public.normalize_indoor_weather_risk(risk)
    when 'clear' then 0
    when 'caution' then 1
    when 'bad' then 2
    when 'severe' then 3
    else 0
  end;
$$;

create or replace function public.indoor_weather_adjusted_risk(base_risk text, adjustment_step integer)
returns text
language sql
immutable
as $$
  with normalized as (
    select
      public.normalize_indoor_weather_risk(base_risk) as base_risk,
      greatest(
        0,
        least(
          3,
          public.indoor_weather_risk_index(base_risk) + coalesce(adjustment_step, 0)
        )
      ) as target_index
  )
  select case
    when base_risk <> 'clear' and target_index = 0 then 'caution'
    when target_index = 0 then 'clear'
    when target_index = 1 then 'caution'
    when target_index = 2 then 'bad'
    else 'severe'
  end
  from normalized;
$$;

create or replace function public.indoor_weather_feedback_next_risk(current_risk text)
returns text
language sql
immutable
as $$
  select case public.normalize_indoor_weather_risk(current_risk)
    when 'severe' then 'bad'
    when 'bad' then 'caution'
    when 'caution' then 'caution'
    else 'clear'
  end;
$$;

create table if not exists public.weather_feedback_histories (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  day_key date not null,
  week_start date not null,
  base_risk_level text not null,
  effective_risk_level text not null,
  adjusted_risk_level text not null,
  adjustment_step integer not null default 0,
  accepted boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, request_id)
);

create index if not exists idx_weather_feedback_histories_owner_week
  on public.weather_feedback_histories(owner_user_id, week_start desc);
create index if not exists idx_weather_feedback_histories_owner_day
  on public.weather_feedback_histories(owner_user_id, day_key desc, created_at desc);

alter table public.weather_feedback_histories enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'weather_feedback_histories'
      and policyname = 'weather_feedback_histories_owner_select'
  ) then
    create policy weather_feedback_histories_owner_select
      on public.weather_feedback_histories
      for select
      to authenticated
      using (auth.uid() = owner_user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'weather_feedback_histories'
      and policyname = 'weather_feedback_histories_service_write'
  ) then
    create policy weather_feedback_histories_service_write
      on public.weather_feedback_histories
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_weather_feedback_histories_updated_at on public.weather_feedback_histories;
create trigger trg_weather_feedback_histories_updated_at
before update on public.weather_feedback_histories
for each row
execute function public.set_updated_at();

drop function if exists public.rpc_apply_weather_replacement(uuid, uuid, text, text, text, timestamptz);
create function public.rpc_apply_weather_replacement(
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
  base_risk_level text,
  risk_level text,
  replacement_reason text,
  replacement_count_today int,
  daily_replacement_limit int,
  shield_used_this_week int,
  weekly_shield_limit int,
  shield_apply_count_today int,
  shield_last_applied_at timestamptz,
  feedback_used_this_week int,
  weekly_feedback_limit int,
  feedback_remaining_count int,
  refreshed_at timestamptz
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
  shield_apply_count_today_value int := 0;
  shield_last_applied_at_value timestamptz := null;
  feedback_used_week int := 0;
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
    select owner_user_id
    into walk_owner
    from public.walk_sessions
    where id = target_walk_session_id
    limit 1;

    if walk_owner is null then
      return query select false, false, 'walk_session_not_found', public.normalize_indoor_weather_risk(target_risk_level), public.normalize_indoor_weather_risk(target_risk_level), null, 0, 0, 0, 0, 0, null::timestamptz, 0, 2, 2, now_ts;
      return;
    end if;

    if walk_owner <> effective_user_id then
      raise exception 'permission denied for walk session %', target_walk_session_id;
    end if;
  end if;

  select *
  into policy_row
  from public.weather_replacement_runtime_policies
  where policy_key = 'weather_replacement_v1'
  limit 1;

  if not found then
    policy_row.policy_key := 'weather_replacement_v1';
    policy_row.daily_replacement_limit := 1;
    policy_row.weekly_shield_limit := 1;
    policy_row.weekly_feedback_limit := 2;
    policy_row.enabled := true;
  end if;

  normalized_risk := public.normalize_indoor_weather_risk(target_risk_level);

  select count(*)::int
  into feedback_used_week
  from public.weather_feedback_histories f
  where f.owner_user_id = effective_user_id
    and f.week_start = week_bucket
    and f.accepted is true;

  select count(*)::int
  into replaced_today
  from public.weather_replacement_histories h
  where h.owner_user_id = effective_user_id
    and h.day_key = day_bucket;

  select count(*)::int, max(s.consumed_at)
  into shield_apply_count_today_value, shield_last_applied_at_value
  from public.weather_shield_ledgers s
  where s.owner_user_id = effective_user_id
    and s.day_key = day_bucket;

  select count(*)::int
  into shield_used_week
  from public.weather_shield_ledgers s
  where s.owner_user_id = effective_user_id
    and s.week_start = week_bucket;

  if policy_row.enabled is false then
    return query select
      false,
      false,
      'policy_disabled',
      normalized_risk,
      normalized_risk,
      null::text,
      replaced_today,
      policy_row.daily_replacement_limit,
      shield_used_week,
      policy_row.weekly_shield_limit,
      shield_apply_count_today_value,
      shield_last_applied_at_value,
      feedback_used_week,
      policy_row.weekly_feedback_limit,
      greatest(policy_row.weekly_feedback_limit - feedback_used_week, 0),
      now_ts;
    return;
  end if;

  if normalized_risk not in ('caution', 'bad', 'severe') then
    return query select
      false,
      false,
      'risk_clear_or_unknown',
      normalized_risk,
      normalized_risk,
      null::text,
      replaced_today,
      policy_row.daily_replacement_limit,
      shield_used_week,
      policy_row.weekly_shield_limit,
      shield_apply_count_today_value,
      shield_last_applied_at_value,
      feedback_used_week,
      policy_row.weekly_feedback_limit,
      greatest(policy_row.weekly_feedback_limit - feedback_used_week, 0),
      now_ts;
    return;
  end if;

  if replaced_today >= policy_row.daily_replacement_limit then
    return query select
      false,
      false,
      'daily_limit_reached',
      normalized_risk,
      normalized_risk,
      null::text,
      replaced_today,
      policy_row.daily_replacement_limit,
      shield_used_week,
      policy_row.weekly_shield_limit,
      shield_apply_count_today_value,
      shield_last_applied_at_value,
      feedback_used_week,
      policy_row.weekly_feedback_limit,
      greatest(policy_row.weekly_feedback_limit - feedback_used_week, 0),
      now_ts;
    return;
  end if;

  select *
  into mapping_row
  from public.weather_replacement_mappings m
  where m.policy_key = policy_row.policy_key
    and m.risk_level = normalized_risk
    and m.source_quest_type = coalesce(source_quest_id, 'outdoor.default')
    and m.is_active = true
  limit 1;

  if not found then
    select *
    into mapping_row
    from public.weather_replacement_mappings m
    where m.policy_key = policy_row.policy_key
      and m.risk_level = normalized_risk
      and m.source_quest_type = 'outdoor.default'
      and m.is_active = true
    limit 1;
  end if;

  reason_text := coalesce(mapping_row.reason_template, '날씨 위험도 기반 자동 치환');
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

    select count(*)::int, max(s.consumed_at)
    into shield_apply_count_today_value, shield_last_applied_at_value
    from public.weather_shield_ledgers s
    where s.owner_user_id = effective_user_id
      and s.day_key = day_bucket;

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
    normalized_risk,
    reason_text,
    replaced_today + 1,
    policy_row.daily_replacement_limit,
    shield_used_week,
    policy_row.weekly_shield_limit,
    shield_apply_count_today_value,
    shield_last_applied_at_value,
    feedback_used_week,
    policy_row.weekly_feedback_limit,
    greatest(policy_row.weekly_feedback_limit - feedback_used_week, 0),
    now_ts;
end;
$$;

grant execute on function public.rpc_apply_weather_replacement(uuid, uuid, text, text, text, timestamptz)
to anon, authenticated, service_role;

create or replace function public.rpc_get_weather_replacement_summary(payload jsonb)
returns table (
  applied boolean,
  blocked_reason text,
  base_risk_level text,
  effective_risk_level text,
  replacement_reason text,
  replacement_count_today int,
  daily_replacement_limit int,
  shield_used_this_week int,
  weekly_shield_limit int,
  shield_apply_count_today int,
  shield_last_applied_at timestamptz,
  feedback_used_this_week int,
  weekly_feedback_limit int,
  feedback_remaining_count int,
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
  normalized_base_risk text := public.normalize_indoor_weather_risk(
    coalesce(
      nullif(trim(payload ->> 'base_risk_level'), ''),
      nullif(trim(payload ->> 'in_base_risk_level'), ''),
      'clear'
    )
  );
  resolved_source_quest_id text := coalesce(
    nullif(trim(payload ->> 'source_quest_id'), ''),
    nullif(trim(payload ->> 'in_source_quest_id'), ''),
    'outdoor.default'
  );
  policy_row public.weather_replacement_runtime_policies%rowtype;
  day_bucket date := (resolved_now_ts at time zone 'utc')::date;
  week_bucket date := date_trunc('week', resolved_now_ts)::date;
  feedback_adjustment_step int := 0;
  effective_risk text;
  replaced_today int := 0;
  shield_used_week int := 0;
  shield_apply_count_today_value int := 0;
  shield_last_applied_at_value timestamptz := null;
  feedback_used_week int := 0;
  mapping_reason text := null;
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;

  select *
  into policy_row
  from public.weather_replacement_runtime_policies
  where policy_key = 'weather_replacement_v1'
  limit 1;

  if not found then
    policy_row.policy_key := 'weather_replacement_v1';
    policy_row.daily_replacement_limit := 1;
    policy_row.weekly_shield_limit := 1;
    policy_row.weekly_feedback_limit := 2;
    policy_row.enabled := true;
  end if;

  select coalesce(f.adjustment_step, 0)
  into feedback_adjustment_step
  from public.weather_feedback_histories f
  where f.owner_user_id = requester_uid
    and f.day_key = day_bucket
    and f.accepted is true
  order by f.created_at desc
  limit 1;

  effective_risk := public.indoor_weather_adjusted_risk(normalized_base_risk, feedback_adjustment_step);

  select count(*)::int
  into replaced_today
  from public.weather_replacement_histories h
  where h.owner_user_id = requester_uid
    and h.day_key = day_bucket;

  select count(*)::int, max(s.consumed_at)
  into shield_apply_count_today_value, shield_last_applied_at_value
  from public.weather_shield_ledgers s
  where s.owner_user_id = requester_uid
    and s.day_key = day_bucket;

  select count(*)::int
  into shield_used_week
  from public.weather_shield_ledgers s
  where s.owner_user_id = requester_uid
    and s.week_start = week_bucket;

  select count(*)::int
  into feedback_used_week
  from public.weather_feedback_histories f
  where f.owner_user_id = requester_uid
    and f.week_start = week_bucket
    and f.accepted is true;

  if effective_risk in ('caution', 'bad', 'severe') then
    select m.reason_template
    into mapping_reason
    from public.weather_replacement_mappings m
    where m.policy_key = policy_row.policy_key
      and m.risk_level = effective_risk
      and m.source_quest_type = resolved_source_quest_id
      and m.is_active = true
    limit 1;

    if mapping_reason is null then
      select m.reason_template
      into mapping_reason
      from public.weather_replacement_mappings m
      where m.policy_key = policy_row.policy_key
        and m.risk_level = effective_risk
        and m.source_quest_type = 'outdoor.default'
        and m.is_active = true
      limit 1;
    end if;
  end if;

  return query select
    (policy_row.enabled and effective_risk <> 'clear'),
    case
      when policy_row.enabled is false then 'policy_disabled'
      when effective_risk = 'clear' then 'risk_clear_or_unknown'
      else null
    end,
    normalized_base_risk,
    effective_risk,
    mapping_reason,
    replaced_today,
    policy_row.daily_replacement_limit,
    shield_used_week,
    policy_row.weekly_shield_limit,
    shield_apply_count_today_value,
    shield_last_applied_at_value,
    feedback_used_week,
    policy_row.weekly_feedback_limit,
    greatest(policy_row.weekly_feedback_limit - feedback_used_week, 0),
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_get_weather_replacement_summary(jsonb)
to authenticated, service_role;

create or replace function public.rpc_submit_weather_feedback(payload jsonb)
returns table (
  accepted boolean,
  message text,
  original_risk_level text,
  adjusted_risk_level text,
  applied boolean,
  blocked_reason text,
  base_risk_level text,
  effective_risk_level text,
  replacement_reason text,
  replacement_count_today int,
  daily_replacement_limit int,
  shield_used_this_week int,
  weekly_shield_limit int,
  shield_apply_count_today int,
  shield_last_applied_at timestamptz,
  feedback_used_this_week int,
  weekly_feedback_limit int,
  feedback_remaining_count int,
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
  normalized_base_risk text := public.normalize_indoor_weather_risk(
    coalesce(
      nullif(trim(payload ->> 'base_risk_level'), ''),
      nullif(trim(payload ->> 'in_base_risk_level'), ''),
      'clear'
    )
  );
  normalized_request_id text := lower(
    coalesce(
      nullif(trim(payload ->> 'request_id'), ''),
      nullif(trim(payload ->> 'in_request_id'), ''),
      gen_random_uuid()::text
    )
  );
  policy_row public.weather_replacement_runtime_policies%rowtype;
  day_bucket date := (resolved_now_ts at time zone 'utc')::date;
  week_bucket date := date_trunc('week', resolved_now_ts)::date;
  existing_row public.weather_feedback_histories%rowtype;
  current_adjustment_step int := 0;
  current_effective_risk text;
  next_effective_risk text;
  next_adjustment_step int := 0;
  feedback_used_week int := 0;
  accepted_feedback boolean := false;
  message_text text;
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;

  select *
  into policy_row
  from public.weather_replacement_runtime_policies
  where policy_key = 'weather_replacement_v1'
  limit 1;

  if not found then
    policy_row.policy_key := 'weather_replacement_v1';
    policy_row.daily_replacement_limit := 1;
    policy_row.weekly_shield_limit := 1;
    policy_row.weekly_feedback_limit := 2;
    policy_row.enabled := true;
  end if;

  select *
  into existing_row
  from public.weather_feedback_histories f
  where f.owner_user_id = requester_uid
    and f.request_id = normalized_request_id
  limit 1;

  if found then
    accepted_feedback := existing_row.accepted;
    current_effective_risk := existing_row.effective_risk_level;
    next_effective_risk := existing_row.adjusted_risk_level;
  else
    select count(*)::int
    into feedback_used_week
    from public.weather_feedback_histories f
    where f.owner_user_id = requester_uid
      and f.week_start = week_bucket
      and f.accepted is true;

    select coalesce(f.adjustment_step, 0)
    into current_adjustment_step
    from public.weather_feedback_histories f
    where f.owner_user_id = requester_uid
      and f.day_key = day_bucket
      and f.accepted is true
    order by f.created_at desc
    limit 1;

    current_effective_risk := public.indoor_weather_adjusted_risk(normalized_base_risk, current_adjustment_step);

    if feedback_used_week >= policy_row.weekly_feedback_limit then
      accepted_feedback := false;
      next_effective_risk := current_effective_risk;
      message_text := format('체감 피드백은 주간 %s회까지 반영할 수 있어요.', policy_row.weekly_feedback_limit);
      insert into public.weather_feedback_histories (
        owner_user_id,
        request_id,
        day_key,
        week_start,
        base_risk_level,
        effective_risk_level,
        adjusted_risk_level,
        adjustment_step,
        accepted,
        created_at,
        updated_at
      ) values (
        requester_uid,
        normalized_request_id,
        day_bucket,
        week_bucket,
        normalized_base_risk,
        current_effective_risk,
        current_effective_risk,
        current_adjustment_step,
        false,
        resolved_now_ts,
        resolved_now_ts
      );
    else
      accepted_feedback := true;
      next_effective_risk := public.indoor_weather_feedback_next_risk(current_effective_risk);
      next_adjustment_step := public.indoor_weather_risk_index(next_effective_risk)
        - public.indoor_weather_risk_index(normalized_base_risk);
      message_text := case
        when current_effective_risk <> next_effective_risk then format(
          '체감 피드백이 반영되어 오늘 판정을 %s로 재평가했어요.',
          next_effective_risk
        )
        else format(
          '피드백은 반영했지만 안전 기준상 오늘 판정은 %s로 유지돼요.',
          next_effective_risk
        )
      end;
      insert into public.weather_feedback_histories (
        owner_user_id,
        request_id,
        day_key,
        week_start,
        base_risk_level,
        effective_risk_level,
        adjusted_risk_level,
        adjustment_step,
        accepted,
        created_at,
        updated_at
      ) values (
        requester_uid,
        normalized_request_id,
        day_bucket,
        week_bucket,
        normalized_base_risk,
        current_effective_risk,
        next_effective_risk,
        next_adjustment_step,
        true,
        resolved_now_ts,
        resolved_now_ts
      );
    end if;
  end if;

  if message_text is null then
    message_text := case
      when accepted_feedback and current_effective_risk <> next_effective_risk then format(
        '체감 피드백이 반영되어 오늘 판정을 %s로 재평가했어요.',
        next_effective_risk
      )
      when accepted_feedback then format(
        '피드백은 반영했지만 안전 기준상 오늘 판정은 %s로 유지돼요.',
        next_effective_risk
      )
      else format('체감 피드백은 주간 %s회까지 반영할 수 있어요.', policy_row.weekly_feedback_limit)
    end;
  end if;

  return query
  select
    accepted_feedback,
    message_text,
    current_effective_risk,
    next_effective_risk,
    summary.applied,
    summary.blocked_reason,
    summary.base_risk_level,
    summary.effective_risk_level,
    summary.replacement_reason,
    summary.replacement_count_today,
    summary.daily_replacement_limit,
    summary.shield_used_this_week,
    summary.weekly_shield_limit,
    summary.shield_apply_count_today,
    summary.shield_last_applied_at,
    summary.feedback_used_this_week,
    summary.weekly_feedback_limit,
    summary.feedback_remaining_count,
    summary.refreshed_at
  from public.rpc_get_weather_replacement_summary(
    jsonb_build_object(
      'in_base_risk_level', normalized_base_risk,
      'in_now_ts', resolved_now_ts
    )
  ) as summary;
end;
$$;

grant execute on function public.rpc_submit_weather_feedback(jsonb)
to authenticated, service_role;
