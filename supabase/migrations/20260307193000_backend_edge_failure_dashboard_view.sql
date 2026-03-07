-- #430 backend edge failure dashboard view (phase 1)

create or replace view public.view_backend_edge_failure_dashboard_24h as
with caricature_failures as (
  select
    date_trunc('hour', coalesce(completed_at, updated_at, created_at)) as hour_bucket,
    'caricature'::text as function_name,
    coalesce(nullif(error_code, ''), 'UNKNOWN') as error_code,
    case
      when coalesce(error_code, '') in ('AUTH_SESSION_INVALID', 'AUTH_MODE_NOT_ALLOWED', 'UNAUTHORIZED') then 'auth'
      when coalesce(error_code, '') in ('INVALID_REQUEST', 'INVALID_JSON', 'INVALID_PAYLOAD') then 'validation'
      when coalesce(error_code, '') in ('METHOD_NOT_ALLOWED') then 'contract'
      when coalesce(error_code, '') in ('SERVER_MISCONFIGURED', 'SOURCE_IMAGE_NOT_FOUND') then 'unavailable'
      when coalesce(error_code, '') in ('ALL_PROVIDERS_FAILED', 'STORAGE_UPLOAD_FAILED', 'DB_UPDATE_FAILED') then 'upstream'
      else 'upstream'
    end as failure_category,
    case
      when lower(coalesce(source_type, '')) in ('authenticated', 'member', 'user') then 'authenticated'
      when lower(coalesce(source_type, '')) in ('anon', 'public') then 'anon'
      when lower(coalesce(source_type, '')) in ('service_role', 'service_role_proxy', 'service') then 'service_role_proxy'
      else nullif(source_type, '')
    end as auth_mode,
    fallback_used,
    count(*)::bigint as event_count,
    count(distinct user_id)::bigint as affected_users,
    avg(latency_ms)::double precision as avg_latency_ms,
    percentile_cont(0.95) within group (order by latency_ms)::double precision as p95_latency_ms,
    'caricature_jobs'::text as data_source
  from public.caricature_jobs
  where coalesce(completed_at, updated_at, created_at) >= now() - interval '24 hours'
    and (status = 'failed' or error_code is not null)
  group by
    date_trunc('hour', coalesce(completed_at, updated_at, created_at)),
    coalesce(nullif(error_code, ''), 'UNKNOWN'),
    case
      when coalesce(error_code, '') in ('AUTH_SESSION_INVALID', 'AUTH_MODE_NOT_ALLOWED', 'UNAUTHORIZED') then 'auth'
      when coalesce(error_code, '') in ('INVALID_REQUEST', 'INVALID_JSON', 'INVALID_PAYLOAD') then 'validation'
      when coalesce(error_code, '') in ('METHOD_NOT_ALLOWED') then 'contract'
      when coalesce(error_code, '') in ('SERVER_MISCONFIGURED', 'SOURCE_IMAGE_NOT_FOUND') then 'unavailable'
      when coalesce(error_code, '') in ('ALL_PROVIDERS_FAILED', 'STORAGE_UPLOAD_FAILED', 'DB_UPDATE_FAILED') then 'upstream'
      else 'upstream'
    end,
    case
      when lower(coalesce(source_type, '')) in ('authenticated', 'member', 'user') then 'authenticated'
      when lower(coalesce(source_type, '')) in ('anon', 'public') then 'anon'
      when lower(coalesce(source_type, '')) in ('service_role', 'service_role_proxy', 'service') then 'service_role_proxy'
      else nullif(source_type, '')
    end,
    fallback_used
),
privacy_failures as (
  select
    date_trunc('hour', created_at) as hour_bucket,
    'nearby-presence'::text as function_name,
    case
      when coalesce(masked_hotspots, 0) > 0 then 'PRIVACY_SENSITIVE_MASK'
      when coalesce(k_anon_hotspots, 0) > 0 then 'PRIVACY_K_ANON_SUPPRESSED'
      when coalesce(suppressed_hotspots, 0) > 0 then 'PRIVACY_DELAY_SUPPRESSED'
      else 'PRIVACY_GUARD_EVENT'
    end as error_code,
    'privacy'::text as failure_category,
    nullif(payload ->> 'auth_mode', '') as auth_mode,
    case
      when payload ? 'fallback_used' then coalesce((payload ->> 'fallback_used')::boolean, false)
      else false
    end as fallback_used,
    count(*)::bigint as event_count,
    count(distinct request_user_id)::bigint as affected_users,
    null::double precision as avg_latency_ms,
    null::double precision as p95_latency_ms,
    'privacy_guard_audit_logs'::text as data_source
  from public.privacy_guard_audit_logs
  where created_at >= now() - interval '24 hours'
    and (
      suppressed_hotspots > 0
      or masked_hotspots > 0
      or k_anon_hotspots > 0
      or alert_level in ('warn', 'critical')
    )
  group by
    date_trunc('hour', created_at),
    case
      when coalesce(masked_hotspots, 0) > 0 then 'PRIVACY_SENSITIVE_MASK'
      when coalesce(k_anon_hotspots, 0) > 0 then 'PRIVACY_K_ANON_SUPPRESSED'
      when coalesce(suppressed_hotspots, 0) > 0 then 'PRIVACY_DELAY_SUPPRESSED'
      else 'PRIVACY_GUARD_EVENT'
    end,
    nullif(payload ->> 'auth_mode', ''),
    case
      when payload ? 'fallback_used' then coalesce((payload ->> 'fallback_used')::boolean, false)
      else false
    end
),
abuse_failures as (
  select
    date_trunc('hour', created_at) as hour_bucket,
    'nearby-presence'::text as function_name,
    case event_type
      when 'speed' then 'ABUSE_SPEED'
      when 'jump' then 'ABUSE_JUMP'
      when 'rate_user' then 'ABUSE_RATE_USER'
      when 'rate_device' then 'ABUSE_RATE_DEVICE'
      when 'repeat' then 'ABUSE_REPEAT'
      when 'sanction' then 'ABUSE_SANCTION'
      else 'ABUSE_EVENT'
    end as error_code,
    'abuse'::text as failure_category,
    nullif(detail ->> 'auth_mode', '') as auth_mode,
    false as fallback_used,
    count(*)::bigint as event_count,
    count(distinct owner_user_id)::bigint as affected_users,
    null::double precision as avg_latency_ms,
    null::double precision as p95_latency_ms,
    'live_presence_abuse_events'::text as data_source
  from public.live_presence_abuse_events
  where created_at >= now() - interval '24 hours'
  group by
    date_trunc('hour', created_at),
    case event_type
      when 'speed' then 'ABUSE_SPEED'
      when 'jump' then 'ABUSE_JUMP'
      when 'rate_user' then 'ABUSE_RATE_USER'
      when 'rate_device' then 'ABUSE_RATE_DEVICE'
      when 'repeat' then 'ABUSE_REPEAT'
      when 'sanction' then 'ABUSE_SANCTION'
      else 'ABUSE_EVENT'
    end,
    nullif(detail ->> 'auth_mode', '')
)
select * from caricature_failures
union all
select * from privacy_failures
union all
select * from abuse_failures
order by hour_bucket desc, event_count desc, function_name asc;

grant select on public.view_backend_edge_failure_dashboard_24h to authenticated;
