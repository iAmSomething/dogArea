-- #470 realtime / hotspot / moderation retention cleanup rollout

create or replace view public.view_realtime_retention_delete_debt as
with boundaries as (
  select now() as now_ts
)
select
  'nearby_presence'::text as surface,
  'ephemeral_realtime'::text as retention_class,
  boundaries.now_ts - interval '24 hours' as cutoff_at,
  count(*) filter (
    where p.last_seen_at <= boundaries.now_ts - interval '24 hours'
  )::bigint as overdue_rows,
  min(p.last_seen_at) filter (
    where p.last_seen_at <= boundaries.now_ts - interval '24 hours'
  ) as oldest_overdue_at
from public.nearby_presence p
cross join boundaries
group by boundaries.now_ts

union all

select
  'widget_hotspot_summary_cache'::text as surface,
  'derived_operational_state'::text as retention_class,
  boundaries.now_ts - interval '24 hours' as cutoff_at,
  count(*) filter (
    where c.cached_at <= boundaries.now_ts - interval '24 hours'
  )::bigint as overdue_rows,
  min(c.cached_at) filter (
    where c.cached_at <= boundaries.now_ts - interval '24 hours'
  ) as oldest_overdue_at
from public.widget_hotspot_summary_cache c
cross join boundaries
group by boundaries.now_ts

union all

select
  'privacy_guard_audit_logs'::text as surface,
  'operational_audit'::text as retention_class,
  boundaries.now_ts - interval '30 days' as cutoff_at,
  count(*) filter (
    where l.created_at <= boundaries.now_ts - interval '30 days'
  )::bigint as overdue_rows,
  min(l.created_at) filter (
    where l.created_at <= boundaries.now_ts - interval '30 days'
  ) as oldest_overdue_at
from public.privacy_guard_audit_logs l
cross join boundaries
group by boundaries.now_ts

union all

select
  'live_presence_abuse_states'::text as surface,
  'derived_operational_state'::text as retention_class,
  boundaries.now_ts - interval '7 days' as cutoff_at,
  count(*) filter (
    where greatest(coalesce(s.sanction_until, '-infinity'::timestamptz), s.updated_at)
      <= boundaries.now_ts - interval '7 days'
  )::bigint as overdue_rows,
  min(greatest(coalesce(s.sanction_until, '-infinity'::timestamptz), s.updated_at)) filter (
    where greatest(coalesce(s.sanction_until, '-infinity'::timestamptz), s.updated_at)
      <= boundaries.now_ts - interval '7 days'
  ) as oldest_overdue_at
from public.live_presence_abuse_states s
cross join boundaries
group by boundaries.now_ts

union all

select
  'live_presence_abuse_device_windows'::text as surface,
  'derived_operational_state'::text as retention_class,
  boundaries.now_ts - interval '24 hours' as cutoff_at,
  count(*) filter (
    where w.updated_at <= boundaries.now_ts - interval '24 hours'
  )::bigint as overdue_rows,
  min(w.updated_at) filter (
    where w.updated_at <= boundaries.now_ts - interval '24 hours'
  ) as oldest_overdue_at
from public.live_presence_abuse_device_windows w
cross join boundaries
group by boundaries.now_ts

union all

select
  'live_presence_abuse_events'::text as surface,
  'operational_audit'::text as retention_class,
  boundaries.now_ts - interval '30 days' as cutoff_at,
  count(*) filter (
    where e.created_at <= boundaries.now_ts - interval '30 days'
  )::bigint as overdue_rows,
  min(e.created_at) filter (
    where e.created_at <= boundaries.now_ts - interval '30 days'
  ) as oldest_overdue_at
from public.live_presence_abuse_events e
cross join boundaries
group by boundaries.now_ts

union all

select
  'rival_abuse_audit_logs'::text as surface,
  'moderation_audit'::text as retention_class,
  boundaries.now_ts - interval '90 days' as cutoff_at,
  count(*) filter (
    where r.created_at <= boundaries.now_ts - interval '90 days'
  )::bigint as overdue_rows,
  min(r.created_at) filter (
    where r.created_at <= boundaries.now_ts - interval '90 days'
  ) as oldest_overdue_at
from public.rival_abuse_audit_logs r
cross join boundaries
group by boundaries.now_ts;

grant select on public.view_realtime_retention_delete_debt to service_role;

create or replace function public.rpc_cleanup_realtime_retention(
  in_now_ts timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  effective_now timestamptz := coalesce(in_now_ts, now());
  nearby_presence_deleted integer := 0;
  widget_hotspot_summary_cache_deleted integer := 0;
  privacy_guard_audit_logs_deleted integer := 0;
  live_presence_abuse_states_deleted integer := 0;
  live_presence_abuse_device_windows_deleted integer := 0;
  live_presence_abuse_events_deleted integer := 0;
  rival_abuse_audit_logs_deleted integer := 0;
begin
  delete from public.nearby_presence
  where last_seen_at <= effective_now - interval '24 hours';
  get diagnostics nearby_presence_deleted = row_count;

  delete from public.widget_hotspot_summary_cache
  where cached_at <= effective_now - interval '24 hours';
  get diagnostics widget_hotspot_summary_cache_deleted = row_count;

  delete from public.privacy_guard_audit_logs
  where created_at <= effective_now - interval '30 days';
  get diagnostics privacy_guard_audit_logs_deleted = row_count;

  delete from public.live_presence_abuse_states
  where greatest(coalesce(sanction_until, '-infinity'::timestamptz), updated_at)
    <= effective_now - interval '7 days';
  get diagnostics live_presence_abuse_states_deleted = row_count;

  delete from public.live_presence_abuse_device_windows
  where updated_at <= effective_now - interval '24 hours';
  get diagnostics live_presence_abuse_device_windows_deleted = row_count;

  delete from public.live_presence_abuse_events
  where created_at <= effective_now - interval '30 days';
  get diagnostics live_presence_abuse_events_deleted = row_count;

  delete from public.rival_abuse_audit_logs
  where created_at <= effective_now - interval '90 days';
  get diagnostics rival_abuse_audit_logs_deleted = row_count;

  return jsonb_build_object(
    'executed_at', effective_now,
    'nearby_presence', nearby_presence_deleted,
    'widget_hotspot_summary_cache', widget_hotspot_summary_cache_deleted,
    'privacy_guard_audit_logs', privacy_guard_audit_logs_deleted,
    'live_presence_abuse_states', live_presence_abuse_states_deleted,
    'live_presence_abuse_device_windows', live_presence_abuse_device_windows_deleted,
    'live_presence_abuse_events', live_presence_abuse_events_deleted,
    'rival_abuse_audit_logs', rival_abuse_audit_logs_deleted,
    'total_deleted',
    nearby_presence_deleted
      + widget_hotspot_summary_cache_deleted
      + privacy_guard_audit_logs_deleted
      + live_presence_abuse_states_deleted
      + live_presence_abuse_device_windows_deleted
      + live_presence_abuse_events_deleted
      + rival_abuse_audit_logs_deleted
  );
end;
$$;

grant execute on function public.rpc_cleanup_realtime_retention(timestamptz) to service_role;

do $$
declare
  existing_job_id integer;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_namespace where nspname = 'cron') then
    select jobid
    into existing_job_id
    from cron.job
    where jobname = 'realtime_retention_cleanup_hourly'
    limit 1;

    if existing_job_id is not null then
      perform cron.unschedule(existing_job_id);
    end if;

    perform cron.schedule(
      'realtime_retention_cleanup_hourly',
      '17 * * * *',
      'select public.rpc_cleanup_realtime_retention();'
    );
  end if;
exception
  when undefined_table or undefined_function or invalid_schema_name then
    raise notice 'realtime retention cleanup scheduler skipped (cron unavailable)';
  when others then
    raise notice 'realtime retention cleanup scheduler skipped: %', sqlerrm;
end;
$$;
