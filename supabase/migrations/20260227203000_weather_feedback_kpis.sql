-- #151 perceived weather feedback loop metrics

create or replace view public.view_weather_feedback_kpis_7d as
with metrics as (
  select
    event_name,
    created_at,
    payload
  from public.app_metric_events
  where created_at >= now() - interval '7 days'
    and event_name in (
      'weather_feedback_submitted',
      'weather_feedback_rate_limited',
      'weather_risk_reevaluated'
    )
),
agg as (
  select
    date_trunc('day', created_at) as day_bucket,
    count(*) filter (where event_name = 'weather_feedback_submitted')::bigint as submitted_count,
    count(*) filter (where event_name = 'weather_feedback_rate_limited')::bigint as rate_limited_count,
    count(*) filter (
      where event_name = 'weather_risk_reevaluated'
        and coalesce(payload->>'changed', 'false') = 'true'
    )::bigint as changed_count,
    count(*) filter (
      where event_name = 'weather_risk_reevaluated'
        and coalesce(payload->>'changed', 'false') = 'false'
    )::bigint as unchanged_count
  from metrics
  group by date_trunc('day', created_at)
)
select
  day_bucket,
  submitted_count,
  rate_limited_count,
  changed_count,
  unchanged_count,
  case
    when submitted_count = 0 then null
    else changed_count::double precision / submitted_count::double precision
  end as changed_ratio,
  case
    when (submitted_count + rate_limited_count) = 0 then null
    else rate_limited_count::double precision / (submitted_count + rate_limited_count)::double precision
  end as rate_limited_ratio
from agg
order by day_bucket desc;

grant select on public.view_weather_feedback_kpis_7d to anon, authenticated;
