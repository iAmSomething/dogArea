-- #809 hotfix: resolve output-variable ambiguity in indoor mission claim RPC

create or replace function public.rpc_claim_indoor_mission_reward(payload jsonb)
returns table (
  mission_instance_id uuid,
  template_id text,
  claim_status text,
  already_claimed boolean,
  reward_points integer,
  claimed_at timestamptz,
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
  normalized_request_id text := coalesce(
    nullif(trim(coalesce(payload ->> 'request_id', payload ->> 'in_request_id')), ''),
    gen_random_uuid()::text
  );
  resolved_day date := public.normalize_indoor_mission_day_key(
    coalesce(payload ->> 'day_key', payload ->> 'in_day_key'),
    resolved_now_ts
  );
  resolved_pet_context_id text := public.normalize_indoor_mission_pet_context_id(
    coalesce(payload ->> 'pet_context_id', payload ->> 'in_pet_context_id')
  );
  instance_row public.owner_indoor_mission_instances%rowtype;
  claim_row public.owner_indoor_mission_claims%rowtype;
  state_row public.owner_indoor_mission_daily_state%rowtype;
  effective_reward integer;
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

  if instance_row.claimed_at is not null or instance_row.status = 'claimed' then
    select *
    into claim_row
    from public.owner_indoor_mission_claims c
    where c.mission_instance_id = instance_row.id
    limit 1;

    return query
    select
      instance_row.id,
      instance_row.template_id,
      coalesce(claim_row.claim_status, 'claimed'),
      true,
      coalesce(claim_row.reward_points, instance_row.reward_points_snapshot),
      coalesce(claim_row.claimed_at, instance_row.claimed_at),
      resolved_now_ts;
    return;
  end if;

  if instance_row.action_count < instance_row.minimum_action_count_snapshot then
    return query
    select
      instance_row.id,
      instance_row.template_id,
      'rejected',
      false,
      instance_row.reward_points_snapshot,
      null::timestamptz,
      resolved_now_ts;
    return;
  end if;

  effective_reward := instance_row.reward_points_snapshot;

  select *
  into state_row
  from public.owner_indoor_mission_daily_state ds
  where ds.owner_user_id = requester_uid
    and ds.day_key = resolved_day
    and ds.pet_context_id = resolved_pet_context_id
  limit 1;

  if state_row.extension_source_instance_id = instance_row.id then
    effective_reward := greatest(1, round((
      (select t.base_reward_points from public.indoor_mission_templates t where t.id = instance_row.template_id)
      * public.indoor_mission_reward_scale(coalesce(state_row.effective_risk_level, 'clear'))
      * case when coalesce(state_row.easy_day_applied, false) then 0.80 else 1.0 end
      * 0.70
    ))::integer);
  end if;

  insert into public.owner_indoor_mission_claims (
    owner_user_id,
    mission_instance_id,
    request_id,
    claim_status,
    reward_points,
    claimed_at,
    payload
  )
  values (
    requester_uid,
    instance_row.id,
    normalized_request_id,
    'claimed',
    effective_reward,
    resolved_now_ts,
    jsonb_build_object('requested_at', resolved_now_ts)
  )
  on conflict (mission_instance_id) do nothing
  returning * into claim_row;

  if claim_row.id is null then
    select *
    into claim_row
    from public.owner_indoor_mission_claims c
    where c.mission_instance_id = instance_row.id
    limit 1;

    return query
    select
      instance_row.id,
      instance_row.template_id,
      coalesce(claim_row.claim_status, 'claimed'),
      true,
      coalesce(claim_row.reward_points, effective_reward),
      coalesce(claim_row.claimed_at, resolved_now_ts),
      resolved_now_ts;
    return;
  end if;

  update public.owner_indoor_mission_instances
  set
    status = 'claimed',
    claimed_at = resolved_now_ts,
    updated_at = now()
  where id = instance_row.id
  returning * into instance_row;

  if state_row.extension_source_instance_id = instance_row.id then
    update public.owner_indoor_mission_daily_state
    set
      extension_state = 'consumed',
      refreshed_at = resolved_now_ts,
      updated_at = now()
    where owner_user_id = requester_uid
      and day_key = resolved_day
      and pet_context_id = resolved_pet_context_id;
  end if;

  return query
  select
    instance_row.id,
    instance_row.template_id,
    claim_row.claim_status,
    false,
    claim_row.reward_points,
    claim_row.claimed_at,
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_claim_indoor_mission_reward(jsonb) to authenticated, service_role;
