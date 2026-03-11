-- #732/#733 hotfix: resolve output-variable ambiguity in rpc_get_indoor_mission_summary

create or replace function public.rpc_get_indoor_mission_summary(payload jsonb)
returns table (
  owner_user_id uuid,
  pet_context_id text,
  day_key text,
  base_risk_level text,
  effective_risk_level text,
  extension_state text,
  extension_message text,
  pet_name text,
  age_band text,
  activity_level text,
  walk_frequency text,
  applied_multiplier double precision,
  adjustment_description text,
  adjustment_reasons jsonb,
  easy_day_state text,
  easy_day_message text,
  history jsonb,
  missions jsonb,
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
  resolved_pet_name text := coalesce(nullif(trim(coalesce(payload ->> 'pet_name', payload ->> 'in_pet_name')), ''), '강아지');
  resolved_age_years integer := nullif(trim(coalesce(payload ->> 'age_years', payload ->> 'in_age_years')), '')::integer;
  resolved_recent_daily_minutes double precision := greatest(coalesce(nullif(trim(coalesce(payload ->> 'recent_daily_minutes', payload ->> 'in_recent_daily_minutes')), '')::double precision, 0), 0);
  resolved_average_weekly_walk_count double precision := greatest(coalesce(nullif(trim(coalesce(payload ->> 'average_weekly_walk_count', payload ->> 'in_average_weekly_walk_count')), '')::double precision, 0), 0);
  requested_base_risk text := public.normalize_indoor_weather_risk(
    coalesce(
      nullif(trim(coalesce(payload ->> 'base_risk_level', payload ->> 'in_base_risk_level')), ''),
      'clear'
    )
  );
  weather_row record;
  effective_risk_value text := 'clear';
  replacement_count_value integer := 0;
  previous_multiplier double precision := null;
  age_band_value text := 'unknown';
  activity_level_value text := 'moderate';
  walk_frequency_value text := 'steady';
  multiplier_value double precision := 1.0;
  clamped_multiplier_value double precision := 1.0;
  adjustment_description_value text := '기본 난이도 유지';
  adjustment_reasons_value jsonb := '[]'::jsonb;
  easy_day_applied_value boolean := false;
  extension_state_value text := 'none';
  extension_source_day_value date := null;
  extension_source_instance_value uuid := null;
  recent_template_ids text[] := array[]::text[];
  ordered_template_ids text[] := array[]::text[];
  filtered_template_ids text[] := array[]::text[];
  selected_template_ids text[] := array[]::text[];
  template_id_value text;
  template_row public.indoor_mission_templates%rowtype;
  existing_instance_count integer := 0;
  source_instance_row public.owner_indoor_mission_instances%rowtype;
  state_row public.owner_indoor_mission_daily_state%rowtype;
  mission_json jsonb := '[]'::jsonb;
  history_json jsonb := '[]'::jsonb;
  reward_scale_value double precision := 1.0;
  adjusted_minimum integer := 1;
  adjusted_reward integer := 0;
  recent_template_id text;
  synthetic_extension jsonb;
begin
  if requester_uid is null then
    raise exception 'permission denied';
  end if;

  select *
  into weather_row
  from public.rpc_get_weather_replacement_summary(
    jsonb_build_object(
      'in_base_risk_level', requested_base_risk,
      'in_now_ts', resolved_now_ts
    )
  )
  limit 1;

  effective_risk_value := coalesce(weather_row.effective_risk_level, requested_base_risk, 'clear');
  replacement_count_value := public.indoor_mission_replacement_count(effective_risk_value);

  age_band_value := public.indoor_mission_age_band(resolved_age_years);
  activity_level_value := public.indoor_mission_activity_level(resolved_recent_daily_minutes);
  walk_frequency_value := public.indoor_mission_walk_frequency_band(resolved_average_weekly_walk_count);

  select ds.applied_multiplier
  into previous_multiplier
  from public.owner_indoor_mission_daily_state ds
  where ds.owner_user_id = requester_uid
    and ds.pet_context_id = resolved_pet_context_id
    and ds.day_key < resolved_day
  order by ds.day_key desc
  limit 1;

  if age_band_value = 'puppy' then
    multiplier_value := multiplier_value - 0.08;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('유년기 반려견이라 목표를 소폭 완화했어요.');
  elsif age_band_value = 'senior' then
    multiplier_value := multiplier_value - 0.12;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('노령기 반려견 컨디션을 고려해 목표를 완화했어요.');
  end if;

  if activity_level_value = 'low' then
    multiplier_value := multiplier_value - 0.12;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('최근 활동량이 낮아 완료 경험 안정화를 위해 목표를 낮췄어요.');
  elsif activity_level_value = 'high' then
    multiplier_value := multiplier_value + 0.10;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('최근 활동량이 높아 목표를 조금 높였어요.');
  end if;

  if walk_frequency_value = 'sparse' then
    multiplier_value := multiplier_value - 0.08;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('최근 산책 빈도가 낮아 목표를 완화했어요.');
  elsif walk_frequency_value = 'frequent' then
    multiplier_value := multiplier_value + 0.08;
    adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('최근 산책 빈도가 높아 목표를 상향했어요.');
  end if;

  multiplier_value := least(greatest(multiplier_value, 0.75), 1.25);
  if previous_multiplier is not null then
    clamped_multiplier_value := least(greatest(multiplier_value, previous_multiplier - 0.15), previous_multiplier + 0.15);
    if abs(clamped_multiplier_value - multiplier_value) > 0.001 then
      adjustment_reasons_value := adjustment_reasons_value || jsonb_build_array('급격한 변동을 막기 위해 일일 변동폭 제한을 적용했어요.');
    end if;
    multiplier_value := clamped_multiplier_value;
  end if;
  multiplier_value := least(greatest(multiplier_value, 0.75), 1.25);

  if abs(multiplier_value - 1.0) < 0.001 then
    adjustment_description_value := '기본 난이도 유지';
  elsif multiplier_value > 1.0 then
    adjustment_description_value := format('기본 대비 +%s%%', round((multiplier_value - 1.0) * 100));
  else
    adjustment_description_value := format('기본 대비 %s%%', round((multiplier_value - 1.0) * 100));
  end if;

  insert into public.owner_indoor_mission_daily_state (
    owner_user_id,
    day_key,
    pet_context_id,
    pet_name_snapshot,
    age_years,
    age_band,
    activity_level,
    walk_frequency,
    applied_multiplier,
    adjustment_description,
    adjustment_reasons,
    easy_day_applied,
    extension_state,
    extension_source_day_key,
    extension_source_instance_id,
    base_risk_level,
    effective_risk_level,
    refreshed_at,
    metadata
  )
  values (
    requester_uid,
    resolved_day,
    resolved_pet_context_id,
    resolved_pet_name,
    resolved_age_years,
    age_band_value,
    activity_level_value,
    walk_frequency_value,
    multiplier_value,
    adjustment_description_value,
    adjustment_reasons_value,
    false,
    'none',
    null,
    null,
    requested_base_risk,
    effective_risk_value,
    resolved_now_ts,
    jsonb_build_object('source', 'rpc_get_indoor_mission_summary')
  )
  on conflict (owner_user_id, day_key, pet_context_id) do update
  set
    pet_name_snapshot = excluded.pet_name_snapshot,
    age_years = excluded.age_years,
    age_band = excluded.age_band,
    activity_level = excluded.activity_level,
    walk_frequency = excluded.walk_frequency,
    applied_multiplier = excluded.applied_multiplier,
    adjustment_description = excluded.adjustment_description,
    adjustment_reasons = excluded.adjustment_reasons,
    base_risk_level = excluded.base_risk_level,
    effective_risk_level = excluded.effective_risk_level,
    refreshed_at = excluded.refreshed_at,
    metadata = coalesce(public.owner_indoor_mission_daily_state.metadata, '{}'::jsonb) || jsonb_build_object('last_refresh_at', resolved_now_ts)
  returning * into state_row;

  easy_day_applied_value := coalesce(state_row.easy_day_applied, false);

  select *
  into state_row
  from public.owner_indoor_mission_daily_state ds
  where ds.owner_user_id = requester_uid
    and ds.day_key = resolved_day
    and ds.pet_context_id = resolved_pet_context_id
  limit 1;

  if state_row.extension_source_instance_id is not null then
    select *
    into source_instance_row
    from public.owner_indoor_mission_instances i
    where i.id = state_row.extension_source_instance_id
    limit 1;

    if source_instance_row.id is not null then
      if source_instance_row.claimed_at is not null or source_instance_row.status = 'claimed' then
        extension_state_value := 'consumed';
      else
        extension_state_value := 'active';
      end if;
      extension_source_day_value := state_row.extension_source_day_key;
      extension_source_instance_value := state_row.extension_source_instance_id;
    else
      extension_state_value := 'none';
      extension_source_day_value := null;
      extension_source_instance_value := null;
    end if;
  else
    select *
    into state_row
    from public.owner_indoor_mission_daily_state ds
    where ds.owner_user_id = requester_uid
      and ds.day_key = (resolved_day - interval '1 day')::date
      and ds.pet_context_id = resolved_pet_context_id
    limit 1;

    if found and state_row.extension_source_instance_id is not null then
      select *
      into source_instance_row
      from public.owner_indoor_mission_instances i
      where i.id = state_row.extension_source_instance_id
      limit 1;

      if source_instance_row.id is not null and (source_instance_row.claimed_at is not null or source_instance_row.status = 'claimed') then
        extension_state_value := 'cooldown';
      else
        extension_state_value := 'expired';
      end if;
    else
      select *
      into source_instance_row
      from public.owner_indoor_mission_instances i
      where i.owner_user_id = requester_uid
        and i.pet_context_id = resolved_pet_context_id
        and i.day_key = (resolved_day - interval '1 day')::date
        and i.is_extension = false
        and coalesce(i.claimed_at, null) is null
      order by i.created_at asc
      limit 1;

      if source_instance_row.id is not null then
        extension_state_value := case
          when source_instance_row.claimed_at is not null then 'consumed'
          else 'active'
        end;
        extension_source_day_value := source_instance_row.day_key;
        extension_source_instance_value := source_instance_row.id;
      else
        extension_state_value := 'none';
      end if;
    end if;

    update public.owner_indoor_mission_daily_state
    set
      extension_state = extension_state_value,
      extension_source_day_key = extension_source_day_value,
      extension_source_instance_id = extension_source_instance_value,
      refreshed_at = resolved_now_ts,
      updated_at = now()
    where owner_user_id = requester_uid
      and day_key = resolved_day
      and pet_context_id = resolved_pet_context_id;
  end if;

  select count(*)::integer
  into existing_instance_count
  from public.owner_indoor_mission_instances i
  where i.owner_user_id = requester_uid
    and i.day_key = resolved_day
    and i.pet_context_id = resolved_pet_context_id
    and i.is_extension = false;

  if existing_instance_count = 0 and replacement_count_value > 0 then
    select coalesce(array_agg(distinct i.template_id), array[]::text[])
    into recent_template_ids
    from public.owner_indoor_mission_instances i
    where i.owner_user_id = requester_uid
      and i.pet_context_id = resolved_pet_context_id
      and i.is_extension = false
      and i.day_key in ((resolved_day - interval '1 day')::date, (resolved_day - interval '2 day')::date);

    select coalesce(array_agg(t.id order by public.indoor_mission_template_priority(t.category, effective_risk_value), t.id), array[]::text[])
    into ordered_template_ids
    from public.indoor_mission_templates t
    where t.is_active is true;

    filtered_template_ids := array[]::text[];
    foreach template_id_value in array ordered_template_ids loop
      if array_position(recent_template_ids, template_id_value) is null then
        filtered_template_ids := array_append(filtered_template_ids, template_id_value);
      end if;
    end loop;

    if coalesce(array_length(filtered_template_ids, 1), 0) < replacement_count_value then
      filtered_template_ids := ordered_template_ids;
    end if;

    selected_template_ids := filtered_template_ids[1:replacement_count_value];
    reward_scale_value := public.indoor_mission_reward_scale(effective_risk_value) * case when easy_day_applied_value then 0.80 else 1.0 end;

    foreach template_id_value in array coalesce(selected_template_ids, array[]::text[]) loop
      select *
      into template_row
      from public.indoor_mission_templates t
      where t.id = template_id_value
      limit 1;

      if template_row.id is null then
        continue;
      end if;

      adjusted_minimum := greatest(1, round(template_row.minimum_action_count * multiplier_value)::integer);
      adjusted_reward := greatest(1, round(template_row.base_reward_points * reward_scale_value)::integer);

      insert into public.owner_indoor_mission_instances (
        owner_user_id,
        day_key,
        pet_context_id,
        instance_key,
        template_id,
        category,
        title_snapshot,
        description_snapshot,
        minimum_action_count_snapshot,
        reward_points_snapshot,
        streak_eligible_snapshot,
        action_count,
        status,
        is_extension,
        extension_source_day_key,
        extension_reward_scale,
        metadata
      )
      values (
        requester_uid,
        resolved_day,
        resolved_pet_context_id,
        concat(to_char(resolved_day, 'YYYY-MM-DD'), '|', resolved_pet_context_id, '|', template_row.id, '|base'),
        template_row.id,
        template_row.category,
        template_row.title,
        template_row.description,
        adjusted_minimum,
        adjusted_reward,
        template_row.streak_eligible,
        0,
        'active',
        false,
        null,
        1.0,
        jsonb_build_object(
          'base_risk_level', requested_base_risk,
          'effective_risk_level', effective_risk_value,
          'applied_multiplier', multiplier_value,
          'easy_day_applied', easy_day_applied_value,
          'issued_at', resolved_now_ts
        )
      )
      on conflict (instance_key) do nothing;
    end loop;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'dayKey', to_char(h.day_key, 'YYYY-MM-DD'),
        'petId', case when h.pet_context_id = '__none__' then null else h.pet_context_id end,
        'petName', h.pet_name_snapshot,
        'multiplier', h.applied_multiplier,
        'ageBand', h.age_band,
        'activityLevel', h.activity_level,
        'walkFrequency', h.walk_frequency,
        'easyDayApplied', h.easy_day_applied
      )
      order by h.day_key desc
    ),
    '[]'::jsonb
  )
  into history_json
  from (
    select ds.*
    from public.owner_indoor_mission_daily_state ds
    where ds.owner_user_id = requester_uid
      and ds.pet_context_id = resolved_pet_context_id
    order by ds.day_key desc
    limit 5
  ) h;

  mission_json := '[]'::jsonb;
  if extension_source_instance_value is not null and extension_state_value in ('active', 'consumed') then
    select *
    into source_instance_row
    from public.owner_indoor_mission_instances i
    where i.id = extension_source_instance_value
    limit 1;

    if source_instance_row.id is not null then
      synthetic_extension := jsonb_build_object(
        'missionInstanceId', source_instance_row.id,
        'templateId', source_instance_row.template_id,
        'category', source_instance_row.category,
        'title', source_instance_row.title_snapshot,
        'description', source_instance_row.description_snapshot,
        'minimumActionCount', source_instance_row.minimum_action_count_snapshot,
        'rewardPoint', greatest(1, round((
          (select t.base_reward_points from public.indoor_mission_templates t where t.id = source_instance_row.template_id)
          * public.indoor_mission_reward_scale(effective_risk_value)
          * case when easy_day_applied_value then 0.80 else 1.0 end
          * 0.70
        ))::integer),
        'streakEligible', false,
        'trackingDayKey', to_char(source_instance_row.day_key, 'YYYY-MM-DD'),
        'isExtension', true,
        'extensionSourceDayKey', to_char(source_instance_row.day_key, 'YYYY-MM-DD'),
        'extensionRewardScale', 0.70,
        'actionCount', source_instance_row.action_count,
        'claimable', source_instance_row.claimed_at is null and source_instance_row.action_count >= source_instance_row.minimum_action_count_snapshot,
        'rewardEligible', source_instance_row.claimed_at is null and source_instance_row.action_count >= source_instance_row.minimum_action_count_snapshot,
        'claimedAt', source_instance_row.claimed_at,
        'status', case when source_instance_row.claimed_at is not null then 'claimed' else 'active' end
      );
      mission_json := mission_json || jsonb_build_array(synthetic_extension);
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'missionInstanceId', i.id,
        'templateId', i.template_id,
        'category', i.category,
        'title', i.title_snapshot,
        'description', i.description_snapshot,
        'minimumActionCount', i.minimum_action_count_snapshot,
        'rewardPoint', i.reward_points_snapshot,
        'streakEligible', i.streak_eligible_snapshot,
        'trackingDayKey', to_char(i.day_key, 'YYYY-MM-DD'),
        'isExtension', i.is_extension,
        'extensionSourceDayKey', case when i.extension_source_day_key is null then null else to_char(i.extension_source_day_key, 'YYYY-MM-DD') end,
        'extensionRewardScale', i.extension_reward_scale,
        'actionCount', i.action_count,
        'claimable', i.claimed_at is null and i.action_count >= i.minimum_action_count_snapshot,
        'rewardEligible', i.claimed_at is null and i.action_count >= i.minimum_action_count_snapshot,
        'claimedAt', i.claimed_at,
        'status', i.status
      )
      order by i.created_at asc
    ),
    '[]'::jsonb
  )
  into mission_json
  from (
    select *
    from public.owner_indoor_mission_instances i
    where i.owner_user_id = requester_uid
      and i.day_key = resolved_day
      and i.pet_context_id = resolved_pet_context_id
      and i.is_extension = false
      and (i.status in ('active', 'claimed') or (i.action_count >= i.minimum_action_count_snapshot and i.claimed_at is null))
    order by i.created_at asc
  ) i;

  if extension_source_instance_value is not null and extension_state_value in ('active', 'consumed') then
    select *
    into source_instance_row
    from public.owner_indoor_mission_instances i
    where i.id = extension_source_instance_value
    limit 1;
    if source_instance_row.id is not null then
      mission_json := jsonb_build_array(
        jsonb_build_object(
          'missionInstanceId', source_instance_row.id,
          'templateId', source_instance_row.template_id,
          'category', source_instance_row.category,
          'title', source_instance_row.title_snapshot,
          'description', source_instance_row.description_snapshot,
          'minimumActionCount', source_instance_row.minimum_action_count_snapshot,
          'rewardPoint', greatest(1, round((
            (select t.base_reward_points from public.indoor_mission_templates t where t.id = source_instance_row.template_id)
            * public.indoor_mission_reward_scale(effective_risk_value)
            * case when easy_day_applied_value then 0.80 else 1.0 end
            * 0.70
          ))::integer),
          'streakEligible', false,
          'trackingDayKey', to_char(source_instance_row.day_key, 'YYYY-MM-DD'),
          'isExtension', true,
          'extensionSourceDayKey', to_char(source_instance_row.day_key, 'YYYY-MM-DD'),
          'extensionRewardScale', 0.70,
          'actionCount', source_instance_row.action_count,
          'claimable', source_instance_row.claimed_at is null and source_instance_row.action_count >= source_instance_row.minimum_action_count_snapshot,
          'rewardEligible', source_instance_row.claimed_at is null and source_instance_row.action_count >= source_instance_row.minimum_action_count_snapshot,
          'claimedAt', source_instance_row.claimed_at,
          'status', case when source_instance_row.claimed_at is not null then 'claimed' else 'active' end
        )
      ) || mission_json;
    end if;
  end if;

  return query
  select
    requester_uid,
    resolved_pet_context_id,
    to_char(resolved_day, 'YYYY-MM-DD'),
    requested_base_risk,
    effective_risk_value,
    extension_state_value,
    public.indoor_mission_extension_message(extension_state_value),
    resolved_pet_name,
    age_band_value,
    activity_level_value,
    walk_frequency_value,
    multiplier_value,
    adjustment_description_value,
    adjustment_reasons_value,
    case when easy_day_applied_value then 'active' else case when resolved_pet_context_id = '__none__' then 'unavailable' else 'available' end end,
    public.indoor_mission_easy_day_message(easy_day_applied_value),
    history_json,
    mission_json,
    resolved_now_ts;
end;
$$;

grant execute on function public.rpc_get_indoor_mission_summary(jsonb) to authenticated, service_role;
