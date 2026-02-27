-- #150 rival privacy hard guard (k-anon + nighttime delay)

create extension if not exists pgcrypto;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.privacy_guard_policies (
  policy_key text primary key,
  min_sample_size integer not null default 20 check (min_sample_size >= 2 and min_sample_size <= 500),
  percentile_fallback double precision not null default 0.8 check (percentile_fallback >= 0 and percentile_fallback <= 1),
  daytime_delay_minutes integer not null default 30 check (daytime_delay_minutes >= 0 and daytime_delay_minutes <= 240),
  nighttime_delay_minutes integer not null default 60 check (nighttime_delay_minutes >= 0 and nighttime_delay_minutes <= 240),
  active_window_minutes integer not null default 10 check (active_window_minutes >= 1 and active_window_minutes <= 120),
  night_start_hour integer not null default 22 check (night_start_hour >= 0 and night_start_hour <= 23),
  night_end_hour integer not null default 6 check (night_end_hour >= 0 and night_end_hour <= 23),
  policy_timezone text not null default 'Asia/Seoul',
  sensitive_mask_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.privacy_guard_policies (
  policy_key,
  min_sample_size,
  percentile_fallback,
  daytime_delay_minutes,
  nighttime_delay_minutes,
  active_window_minutes,
  night_start_hour,
  night_end_hour,
  policy_timezone,
  sensitive_mask_enabled
)
values (
  'nearby_hotspot',
  20,
  0.80,
  30,
  60,
  10,
  22,
  6,
  'Asia/Seoul',
  true
)
on conflict (policy_key) do nothing;

create table if not exists public.privacy_sensitive_geo_masks (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  min_lat double precision not null,
  max_lat double precision not null,
  min_lng double precision not null,
  max_lng double precision not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint privacy_sensitive_geo_masks_lat_bounds check (min_lat <= max_lat),
  constraint privacy_sensitive_geo_masks_lng_bounds check (min_lng <= max_lng)
);

create table if not exists public.privacy_guard_audit_logs (
  id bigint generated always as identity primary key,
  policy_key text not null,
  request_action text not null,
  request_user_id uuid,
  center_lat double precision,
  center_lng double precision,
  radius_km double precision,
  total_hotspots integer not null default 0,
  suppressed_hotspots integer not null default 0,
  masked_hotspots integer not null default 0,
  k_anon_hotspots integer not null default 0,
  delay_minutes integer not null default 0,
  alert_level text not null default 'info' check (alert_level in ('info', 'warn', 'critical')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_privacy_guard_logs_created_at
  on public.privacy_guard_audit_logs(created_at desc);
create index if not exists idx_privacy_guard_logs_alert_level_created_at
  on public.privacy_guard_audit_logs(alert_level, created_at desc);

alter table public.privacy_guard_policies enable row level security;
alter table public.privacy_sensitive_geo_masks enable row level security;
alter table public.privacy_guard_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'privacy_guard_policies'
      and policyname = 'privacy_guard_policies_select_all'
  ) then
    create policy privacy_guard_policies_select_all
      on public.privacy_guard_policies
      for select
      to anon, authenticated
      using (true);
  end if;
end $$;

drop trigger if exists trg_privacy_guard_policies_updated_at on public.privacy_guard_policies;
create trigger trg_privacy_guard_policies_updated_at
before update on public.privacy_guard_policies
for each row execute function public.touch_updated_at();

drop trigger if exists trg_privacy_sensitive_geo_masks_updated_at on public.privacy_sensitive_geo_masks;
create trigger trg_privacy_sensitive_geo_masks_updated_at
before update on public.privacy_sensitive_geo_masks
for each row execute function public.touch_updated_at();

create or replace function public.is_coordinate_in_sensitive_mask(
  target_lat double precision,
  target_lng double precision
)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.privacy_sensitive_geo_masks m
    where m.enabled = true
      and target_lat between m.min_lat and m.max_lat
      and target_lng between m.min_lng and m.max_lng
  );
$$;

drop function if exists public.rpc_get_nearby_hotspots(double precision, double precision, double precision, timestamptz);

create or replace function public.rpc_get_nearby_hotspots(
  center_lat double precision,
  center_lng double precision,
  radius_km double precision default 1.0,
  now_ts timestamptz default now()
)
returns table (
  geohash7 text,
  count int,
  intensity double precision,
  center_lat double precision,
  center_lng double precision,
  sample_count int,
  privacy_mode text,
  suppression_reason text,
  delay_minutes int,
  required_min_sample int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  policy_row public.privacy_guard_policies%rowtype;
  local_now timestamp;
  local_hour integer;
  is_night boolean;
  effective_delay integer;
  active_window integer;
  fallback_percentile double precision;
  min_samples integer;
  mask_enabled boolean;
  clamped_radius double precision;
  query_center_lat double precision;
  query_center_lng double precision;
begin
  select *
  into policy_row
  from public.privacy_guard_policies
  where policy_key = 'nearby_hotspot'
  limit 1;

  if not found then
    min_samples := 20;
    fallback_percentile := 0.80;
    effective_delay := 30;
    active_window := 10;
    mask_enabled := true;
    local_now := now_ts at time zone 'Asia/Seoul';
    local_hour := extract(hour from local_now)::integer;
    is_night := local_hour >= 22 or local_hour < 6;
    if is_night then
      effective_delay := 60;
    end if;
  else
    min_samples := greatest(2, coalesce(policy_row.min_sample_size, 20));
    fallback_percentile := least(1.0, greatest(0.0, coalesce(policy_row.percentile_fallback, 0.80)));
    active_window := greatest(1, coalesce(policy_row.active_window_minutes, 10));
    mask_enabled := coalesce(policy_row.sensitive_mask_enabled, true);

    local_now := now_ts at time zone coalesce(nullif(policy_row.policy_timezone, ''), 'Asia/Seoul');
    local_hour := extract(hour from local_now)::integer;

    if policy_row.night_start_hour = policy_row.night_end_hour then
      is_night := false;
    elsif policy_row.night_start_hour < policy_row.night_end_hour then
      is_night := local_hour >= policy_row.night_start_hour
        and local_hour < policy_row.night_end_hour;
    else
      is_night := local_hour >= policy_row.night_start_hour
        or local_hour < policy_row.night_end_hour;
    end if;

    effective_delay := case
      when is_night then coalesce(policy_row.nighttime_delay_minutes, 60)
      else coalesce(policy_row.daytime_delay_minutes, 30)
    end;
  end if;

  clamped_radius := least(5.0, greatest(0.1, coalesce(radius_km, 1.0)));
  query_center_lat := center_lat;
  query_center_lng := center_lng;

  return query
  with delayed as (
    select p.*
    from public.nearby_presence p
    where p.last_seen_at <= now_ts - make_interval(mins => effective_delay)
      and p.last_seen_at >= now_ts - make_interval(mins => (effective_delay + active_window))
  ),
  grouped as (
    select
      p.geohash7,
      count(*)::int as sample_count,
      avg(p.lat_rounded)::double precision as center_lat,
      avg(p.lng_rounded)::double precision as center_lng
    from delayed p
    where
      sqrt(
        power((p.lat_rounded - query_center_lat), 2) +
        power((p.lng_rounded - query_center_lng) * cos(radians(query_center_lat)), 2)
      ) * 111.32 <= clamped_radius
    group by p.geohash7
  ),
  ranked as (
    select
      g.*,
      percent_rank() over (order by g.sample_count asc, g.geohash7 asc) as percentile_rank,
      case
        when mask_enabled then public.is_coordinate_in_sensitive_mask(g.center_lat, g.center_lng)
        else false
      end as is_sensitive
    from grouped g
  ),
  guarded as (
    select
      r.*,
      (r.sample_count < min_samples) as is_k_anon_suppressed,
      case
        when r.is_sensitive then 'sensitive_mask'
        when r.sample_count < min_samples then 'k_anon'
        else null
      end as suppression_reason
    from ranked r
  ),
  filtered as (
    select
      g.*,
      case
        when g.suppression_reason = 'sensitive_mask' then false
        when g.suppression_reason = 'k_anon' then g.percentile_rank >= fallback_percentile
        else true
      end as include_row
    from guarded g
  ),
  included as (
    select *
    from filtered
    where include_row
  ),
  scored as (
    select
      i.*,
      max(
        case
          when i.suppression_reason is null then i.sample_count
          else null
        end
      ) over () as max_visible_count
    from included i
  )
  select
    s.geohash7,
    case
      when s.suppression_reason is null then s.sample_count
      else 0
    end as count,
    case
      when s.suppression_reason = 'k_anon' then greatest(0.05, least(1.0, s.percentile_rank))
      when coalesce(s.max_visible_count, 0) = 0 then 0
      else least(1.0, greatest(0.0, s.sample_count::double precision / s.max_visible_count::double precision))
    end as intensity,
    s.center_lat,
    s.center_lng,
    s.sample_count,
    case
      when s.suppression_reason = 'k_anon' then 'percentile_only'
      else 'full'
    end as privacy_mode,
    s.suppression_reason,
    effective_delay as delay_minutes,
    min_samples as required_min_sample
  from scored s
  order by intensity desc, s.geohash7 asc;
end;
$$;

create or replace view public.view_privacy_guard_alerts_24h as
select
  date_trunc('hour', created_at) as hour_bucket,
  policy_key,
  count(*) filter (where alert_level = 'warn')::bigint as warn_count,
  count(*) filter (where alert_level = 'critical')::bigint as critical_count,
  count(*)::bigint as total_count
from public.privacy_guard_audit_logs
where created_at >= now() - interval '24 hours'
group by date_trunc('hour', created_at), policy_key
order by hour_bucket desc;

grant select on public.privacy_guard_policies to anon, authenticated;
grant execute on function public.rpc_get_nearby_hotspots(double precision, double precision, double precision, timestamptz) to anon, authenticated;
grant select on public.view_privacy_guard_alerts_24h to authenticated;
