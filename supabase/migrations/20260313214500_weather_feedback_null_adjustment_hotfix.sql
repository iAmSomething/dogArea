-- #808 weather feedback rate-limited insert should not write null adjustment_step

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

    current_adjustment_step := coalesce(current_adjustment_step, 0);
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
      when accepted_feedback then format('체감 피드백이 이미 반영된 상태예요. 현재 판정은 %s예요.', coalesce(next_effective_risk, current_effective_risk, normalized_base_risk))
      else format('체감 피드백은 이미 주간 %s회 한도에 도달했어요.', policy_row.weekly_feedback_limit)
    end;
  end if;

  return query
  select
    accepted_feedback,
    message_text,
    current_effective_risk,
    next_effective_risk,
    policy_row.enabled and coalesce(next_effective_risk, current_effective_risk) <> 'clear',
    case
      when policy_row.enabled is false then 'policy_disabled'
      when accepted_feedback is false and feedback_used_week >= policy_row.weekly_feedback_limit then 'weekly_feedback_limit_reached'
      else null
    end,
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
