-- #732/#733 hotfix: resolve output-variable ambiguity in indoor mission action/easy-day RPCs

create or replace function public.rpc_record_indoor_mission_action(payload jsonb)
returns table (
  mission_instance_id uuid,
  template_id text,
  event_id text,
  idempotent boolean,
  action_count integer,
  minimum_action_count integer,
  claimable boolean,
  status text,
  refreshed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  requester_uid uuid := auth.uid();
  resolved_now_ts timestamptz := coalesce(
    nullif(payload ->> 'now_ts', '')::timestamptz,
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    now()
  );
  target_instance_id uuid := coalesce(
    nullif(payload ->> 'mission_instance_id', '')::uuid,
    nullif(payload ->> 'in_mission_instance_id', '')::uuid
  );
  normalized_event_id text := coalesce(
    nullif(trim(coalesce(payload ->> 'event_id', payload ->> 'in_event_id', payload ->> 'request_id', payload ->> 'in_request_id')), ''),
    gen_random_uuid()::text
  );
  instance_row public.owner_indoor_mission_instances%rowtype;
  inserted_id bigint;
  next_action_count integer;
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;
  if target_instance_id is null then
    raise exception 'mission_instance_id is required';
  end if;

  select *
  into instance_row
  from public.owner_indoor_mission_instances i
  where i.id = target_instance_id
  for update;

  if instance_row.id is null then
    raise exception 'indoor mission instance not found';
  end if;
  if instance_row.owner_user_id <> requester_uid then
    raise exception 'forbidden indoor mission access';
  end if;

  insert into public.owner_indoor_mission_action_events (
    owner_user_id,
    mission_instance_id,
    event_id,
    delta_value,
    payload,
    recorded_at
  )
  values (
    requester_uid,
    instance_row.id,
    normalized_event_id,
    1,
    coalesce(payload, '{}'::jsonb),
    resolved_now_ts
  )
  on conflict (mission_instance_id, event_id) do nothing
  returning id into inserted_id;

  if inserted_id is not null and instance_row.claimed_at is null then
    next_action_count := instance_row.action_count + 1;
    update public.owner_indoor_mission_instances
    set
      action_count = next_action_count,
      updated_at = now()
    where id = instance_row.id
    returning * into instance_row;
  end if;

  return query
  select
    instance_row.id,
    instance_row.template_id,
    normalized_event_id,
    inserted_id is null,
    instance_row.action_count,
    instance_row.minimum_action_count_snapshot,
    instance_row.claimed_at is null and instance_row.action_count >= instance_row.minimum_action_count_snapshot,
    instance_row.status,
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_record_indoor_mission_action(jsonb) to authenticated, service_role;

create or replace function public.rpc_activate_indoor_easy_day(payload jsonb)
returns table (
  outcome text,
  pet_context_id text,
  already_applied boolean,
  refreshed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  requester_uid uuid := auth.uid();
  resolved_now_ts timestamptz := coalesce(
    nullif(payload ->> 'now_ts', '')::timestamptz,
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    now()
  );
  resolved_day date := public.normalize_indoor_mission_day_key(
    coalesce(payload ->> 'day_key', payload ->> 'in_day_key'),
    resolved_now_ts
  );
  resolved_pet_context_id text := public.normalize_indoor_mission_pet_context_id(
    coalesce(payload ->> 'pet_context_id', payload ->> 'in_pet_context_id')
  );
  state_row public.owner_indoor_mission_daily_state%rowtype;
  current_reward_scale double precision;
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;
  if resolved_pet_context_id = '__none__' then
    return query select 'missing_pet', resolved_pet_context_id, false, resolved_now_ts;
    return;
  end if;

  perform public.rpc_get_indoor_mission_summary(
    jsonb_build_object(
      'in_day_key', to_char(resolved_day, 'YYYY-MM-DD'),
      'in_pet_context_id', resolved_pet_context_id,
      'in_pet_name', coalesce(payload ->> 'pet_name', payload ->> 'in_pet_name', '강아지'),
      'in_age_years', payload ->> 'age_years',
      'in_recent_daily_minutes', coalesce(payload ->> 'recent_daily_minutes', payload ->> 'in_recent_daily_minutes', '0'),
      'in_average_weekly_walk_count', coalesce(payload ->> 'average_weekly_walk_count', payload ->> 'in_average_weekly_walk_count', '0'),
      'in_base_risk_level', coalesce(payload ->> 'base_risk_level', payload ->> 'in_base_risk_level', 'clear'),
      'in_now_ts', resolved_now_ts
    )
  );

  select *
  into state_row
  from public.owner_indoor_mission_daily_state ds
  where ds.owner_user_id = requester_uid
    and ds.day_key = resolved_day
    and ds.pet_context_id = resolved_pet_context_id
  for update;

  if state_row.easy_day_applied then
    return query select 'already_used', resolved_pet_context_id, true, resolved_now_ts;
    return;
  end if;

  update public.owner_indoor_mission_daily_state
  set
    easy_day_applied = true,
    easy_day_activated_at = resolved_now_ts,
    refreshed_at = resolved_now_ts,
    updated_at = now()
  where owner_user_id = requester_uid
    and day_key = resolved_day
    and pet_context_id = resolved_pet_context_id
  returning * into state_row;

  current_reward_scale := public.indoor_mission_reward_scale(coalesce(state_row.effective_risk_level, 'clear')) * 0.80;

  update public.owner_indoor_mission_instances
  set
    reward_points_snapshot = greatest(1, round((
      (select t.base_reward_points from public.indoor_mission_templates t where t.id = public.owner_indoor_mission_instances.template_id)
      * current_reward_scale
    ))::integer),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('easy_day_applied', true),
    updated_at = now()
  where owner_user_id = requester_uid
    and day_key = resolved_day
    and pet_context_id = resolved_pet_context_id
    and is_extension = false
    and claimed_at is null;

  return query select 'activated', resolved_pet_context_id, false, resolved_now_ts;
end;
$$;

grant execute on function public.rpc_activate_indoor_easy_day(jsonb) to authenticated, service_role;
