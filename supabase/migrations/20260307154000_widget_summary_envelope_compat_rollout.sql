-- #459 widget summary canonical envelope compat rollout

create or replace function public.rpc_get_widget_territory_summary(payload jsonb)
returns jsonb
language sql
security definer
set search_path = public
as $$
with request_args as (
  select coalesce(
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    nullif(payload ->> 'now_ts', '')::timestamptz,
    now()
  ) as resolved_now
),
legacy as (
  select public.rpc_get_widget_territory_summary(request_args.resolved_now) as body
  from request_args
)
select jsonb_build_object(
  'summary_type', 'territory',
  'version', 'widget_summary_v1',
  'status', case
    when coalesce((body ->> 'has_data')::boolean, false) then 'ok'
    else 'empty'
  end,
  'message', case
    when coalesce((body ->> 'has_data')::boolean, false) then '오늘/주간/방어 예정 영역 요약입니다.'
    else '아직 집계된 영역이 없어 기본 상태를 표시합니다.'
  end,
  'has_data', coalesce((body ->> 'has_data')::boolean, false),
  'refreshed_at', body -> 'refreshed_at',
  'context', jsonb_build_object(
    'request_mode', 'payload'
  ),
  'summary', jsonb_build_object(
    'today_tile_count', body -> 'today_tile_count',
    'weekly_tile_count', body -> 'weekly_tile_count',
    'defense_scheduled_tile_count', body -> 'defense_scheduled_tile_count',
    'score_updated_at', body -> 'score_updated_at'
  )
)
from legacy;
$$;

grant execute on function public.rpc_get_widget_territory_summary(jsonb) to authenticated, service_role;

create or replace function public.rpc_get_widget_hotspot_summary(payload jsonb)
returns jsonb
language sql
security definer
set search_path = public
as $$
with request_args as (
  select
    least(
      5.0,
      greatest(
        0.3,
        coalesce(
          nullif(payload ->> 'in_radius_km', '')::double precision,
          nullif(payload ->> 'radius_km', '')::double precision,
          1.2
        )
      )
    ) as resolved_radius_km,
    coalesce(
      nullif(payload ->> 'in_now_ts', '')::timestamptz,
      nullif(payload ->> 'now_ts', '')::timestamptz,
      now()
    ) as resolved_now
),
legacy as (
  select public.rpc_get_widget_hotspot_summary(
    request_args.resolved_radius_km,
    request_args.resolved_now
  ) as body
  from request_args
)
select jsonb_build_object(
  'summary_type', 'hotspot',
  'version', 'widget_summary_v1',
  'status', case
    when coalesce(body ->> 'privacy_mode', '') = 'guest' then 'guest_locked'
    when coalesce((body ->> 'has_data')::boolean, false) = false then 'empty'
    when coalesce((body ->> 'is_cached')::boolean, false) then 'cached'
    when coalesce(body ->> 'suppression_reason', '') <> ''
      or coalesce(body ->> 'privacy_mode', 'none') <> 'full' then 'degraded'
    else 'ok'
  end,
  'message', coalesce(body ->> 'guide_copy', ''),
  'has_data', coalesce((body ->> 'has_data')::boolean, false),
  'refreshed_at', body -> 'refreshed_at',
  'context', jsonb_strip_nulls(
    jsonb_build_object(
      'request_mode', 'payload',
      'is_cached', coalesce((body ->> 'is_cached')::boolean, false),
      'server_policy', body ->> 'server_policy',
      'privacy_mode', body ->> 'privacy_mode',
      'suppression_reason', body ->> 'suppression_reason'
    )
  ),
  'summary', jsonb_strip_nulls(
    jsonb_build_object(
      'signal_level', body ->> 'signal_level',
      'high_cells', coalesce((body ->> 'high_cells')::integer, 0),
      'medium_cells', coalesce((body ->> 'medium_cells')::integer, 0),
      'low_cells', coalesce((body ->> 'low_cells')::integer, 0),
      'delay_minutes', coalesce((body ->> 'delay_minutes')::integer, 0),
      'guide_copy', body ->> 'guide_copy',
      'privacy_mode', body ->> 'privacy_mode',
      'suppression_reason', body ->> 'suppression_reason'
    )
  )
)
from legacy;
$$;

grant execute on function public.rpc_get_widget_hotspot_summary(jsonb) to anon, authenticated, service_role;

drop function if exists public.rpc_get_widget_quest_rival_summary(jsonb);

create or replace function public.rpc_get_widget_quest_rival_summary(payload jsonb)
returns jsonb
language sql
security definer
set search_path = public
as $$
with request_args as (
  select coalesce(
    nullif(payload ->> 'in_now_ts', '')::timestamptz,
    nullif(payload ->> 'now_ts', '')::timestamptz,
    now()
  ) as resolved_now
),
legacy as (
  select coalesce(
    (
      select row_to_json(summary_row)::jsonb
      from public.rpc_get_widget_quest_rival_summary(request_args.resolved_now) as summary_row
      limit 1
    ),
    jsonb_build_object(
      'quest_instance_id', null,
      'quest_title', '오늘의 퀘스트를 준비 중입니다.',
      'quest_progress_value', 0,
      'quest_target_value', 1,
      'quest_claimable', false,
      'quest_reward_point', 0,
      'rival_rank', null,
      'rival_league', 'onboarding',
      'refreshed_at', request_args.resolved_now,
      'has_data', false
    )
  ) as body
  from request_args
)
select jsonb_build_object(
  'summary_type', 'quest_rival',
  'version', 'widget_summary_v1',
  'status', case
    when coalesce((body ->> 'has_data')::boolean, false) then 'ok'
    else 'empty'
  end,
  'message', case
    when coalesce((body ->> 'has_data')::boolean, false) then '오늘 퀘스트와 라이벌 요약입니다.'
    else '퀘스트와 라이벌 요약을 준비 중입니다.'
  end,
  'has_data', coalesce((body ->> 'has_data')::boolean, false),
  'refreshed_at', body -> 'refreshed_at',
  'context', jsonb_build_object(
    'request_mode', 'payload'
  ),
  'summary', jsonb_strip_nulls(
    jsonb_build_object(
      'quest_instance_id', body ->> 'quest_instance_id',
      'quest_title', body ->> 'quest_title',
      'quest_progress_value', coalesce((body ->> 'quest_progress_value')::double precision, 0),
      'quest_target_value', greatest(coalesce((body ->> 'quest_target_value')::double precision, 1), 1),
      'quest_claimable', coalesce((body ->> 'quest_claimable')::boolean, false),
      'quest_reward_point', greatest(coalesce((body ->> 'quest_reward_point')::integer, 0), 0),
      'rival_rank', (body ->> 'rival_rank')::integer,
      'rival_league', coalesce(body ->> 'rival_league', 'onboarding')
    )
  )
)
from legacy;
$$;

grant execute on function public.rpc_get_widget_quest_rival_summary(jsonb) to authenticated, service_role;
