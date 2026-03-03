-- #218 anonymous hotspot widget summary RPC (privacy-guarded, cache + rate-limit)

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

create table if not exists public.widget_hotspot_summary_cache (
  owner_user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  cached_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.widget_hotspot_summary_cache enable row level security;

create index if not exists idx_widget_hotspot_summary_cache_cached_at
  on public.widget_hotspot_summary_cache(cached_at desc);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'widget_hotspot_summary_cache'
      and policyname = 'widget_hotspot_summary_cache_owner_select'
  ) then
    create policy widget_hotspot_summary_cache_owner_select
      on public.widget_hotspot_summary_cache
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'widget_hotspot_summary_cache'
      and policyname = 'widget_hotspot_summary_cache_service_write'
  ) then
    create policy widget_hotspot_summary_cache_service_write
      on public.widget_hotspot_summary_cache
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_widget_hotspot_summary_cache_updated_at on public.widget_hotspot_summary_cache;
create trigger trg_widget_hotspot_summary_cache_updated_at
before update on public.widget_hotspot_summary_cache
for each row execute function public.touch_updated_at();

create or replace function public.rpc_get_widget_hotspot_summary(
  radius_km double precision default 1.2,
  now_ts timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid := auth.uid();
  normalized_radius double precision := least(5.0, greatest(0.3, coalesce(radius_km, 1.2)));
  cache_ttl_seconds integer := 300;
  min_refresh_gap_seconds integer := 20;
  cached_payload jsonb;
  cached_at timestamptz;
  center_lat double precision;
  center_lng double precision;
  total_cells integer := 0;
  high_cells integer := 0;
  medium_cells integer := 0;
  low_cells integer := 0;
  suppressed_cells integer := 0;
  k_anon_cells integer := 0;
  sensitive_mask_cells integer := 0;
  delay_minutes integer := 0;
  privacy_mode text := 'none';
  suppression_reason text := null;
  signal_level text := 'none';
  guide_copy text := '';
  payload jsonb;
begin
  if requester_uid is null then
    return jsonb_build_object(
      'signal_level', 'none',
      'high_cells', 0,
      'medium_cells', 0,
      'low_cells', 0,
      'delay_minutes', 0,
      'privacy_mode', 'guest',
      'suppression_reason', 'guest_mode',
      'guide_copy', '비회원 모드에서는 주변 개인화 신호를 제공하지 않습니다.',
      'has_data', false,
      'is_cached', false,
      'server_policy', 'guest',
      'refreshed_at', now_ts
    );
  end if;

  select c.payload, c.cached_at
  into cached_payload, cached_at
  from public.widget_hotspot_summary_cache c
  where c.owner_user_id = requester_uid
  limit 1;

  if cached_payload is not null then
    if now_ts <= cached_at + make_interval(secs => min_refresh_gap_seconds) then
      return cached_payload || jsonb_build_object(
        'is_cached', true,
        'server_policy', 'rate_limited_cache',
        'refreshed_at', now_ts
      );
    end if;

    if now_ts <= cached_at + make_interval(secs => cache_ttl_seconds) then
      return cached_payload || jsonb_build_object(
        'is_cached', true,
        'server_policy', 'cache_hit',
        'refreshed_at', now_ts
      );
    end if;
  end if;

  select p.lat_rounded, p.lng_rounded
  into center_lat, center_lng
  from public.nearby_presence p
  where p.user_id = requester_uid
  order by p.last_seen_at desc
  limit 1;

  if center_lat is null or center_lng is null then
    payload := jsonb_build_object(
      'signal_level', 'none',
      'high_cells', 0,
      'medium_cells', 0,
      'low_cells', 0,
      'delay_minutes', 0,
      'privacy_mode', 'none',
      'suppression_reason', 'location_unavailable',
      'guide_copy', '최근 위치 기반 익명 핫스팟 데이터가 없어 안내 카드만 표시됩니다.',
      'has_data', false,
      'is_cached', false,
      'server_policy', 'fresh',
      'refreshed_at', now_ts
    );

    insert into public.widget_hotspot_summary_cache(owner_user_id, payload, cached_at, updated_at)
    values (requester_uid, payload, now_ts, now_ts)
    on conflict (owner_user_id)
    do update set payload = excluded.payload, cached_at = excluded.cached_at, updated_at = excluded.updated_at;

    return payload;
  end if;

  with source as (
    select *
    from public.rpc_get_nearby_hotspots(center_lat, center_lng, normalized_radius, now_ts)
  ), rollup as (
    select
      count(*)::integer as total_cells,
      count(*) filter (where suppression_reason is not null)::integer as suppressed_cells,
      count(*) filter (where suppression_reason = 'k_anon')::integer as k_anon_cells,
      count(*) filter (where suppression_reason = 'sensitive_mask')::integer as sensitive_mask_cells,
      count(*) filter (where suppression_reason is null and intensity >= 0.70)::integer as high_cells,
      count(*) filter (where suppression_reason is null and intensity >= 0.35 and intensity < 0.70)::integer as medium_cells,
      count(*) filter (where suppression_reason is null and intensity < 0.35)::integer as low_cells,
      coalesce(max(delay_minutes), 0)::integer as delay_minutes
    from source
  )
  select
    r.total_cells,
    r.high_cells,
    r.medium_cells,
    r.low_cells,
    r.suppressed_cells,
    r.k_anon_cells,
    r.sensitive_mask_cells,
    r.delay_minutes
  into
    total_cells,
    high_cells,
    medium_cells,
    low_cells,
    suppressed_cells,
    k_anon_cells,
    sensitive_mask_cells,
    delay_minutes
  from rollup r;

  if total_cells = 0 then
    privacy_mode := 'none';
    suppression_reason := 'no_hotspot';
    signal_level := 'none';
    guide_copy := '주변 익명 핫스팟 신호가 아직 충분하지 않습니다.';
  elsif sensitive_mask_cells > 0 then
    privacy_mode := 'guarded';
    suppression_reason := 'sensitive_mask';
    signal_level := case
      when high_cells > 0 then 'high'
      when medium_cells > 0 then 'medium'
      when low_cells > 0 then 'low'
      else 'none'
    end;
    guide_copy := '민감 지역은 보호 정책으로 상세 노출이 제한됩니다.';
  elsif k_anon_cells > 0 then
    privacy_mode := 'percentile_only';
    suppression_reason := 'k_anon';
    signal_level := case
      when high_cells > 0 then 'high'
      when medium_cells > 0 then 'medium'
      when low_cells > 0 then 'low'
      else 'none'
    end;
    guide_copy := 'k-익명 정책으로 백분위 단계 신호만 노출됩니다.';
  else
    privacy_mode := 'full';
    suppression_reason := null;
    signal_level := case
      when high_cells > 0 then 'high'
      when medium_cells > 0 then 'medium'
      when low_cells > 0 then 'low'
      else 'none'
    end;
    guide_copy := '개인 좌표와 정밀 카운트 없이 익명 셀 단계만 제공합니다.';
  end if;

  payload := jsonb_build_object(
    'signal_level', signal_level,
    'high_cells', high_cells,
    'medium_cells', medium_cells,
    'low_cells', low_cells,
    'delay_minutes', delay_minutes,
    'privacy_mode', privacy_mode,
    'suppression_reason', suppression_reason,
    'guide_copy', guide_copy,
    'has_data', (total_cells > 0),
    'is_cached', false,
    'server_policy', 'fresh',
    'refreshed_at', now_ts,
    'suppressed_cells', suppressed_cells
  );

  insert into public.widget_hotspot_summary_cache(owner_user_id, payload, cached_at, updated_at)
  values (requester_uid, payload, now_ts, now_ts)
  on conflict (owner_user_id)
  do update set payload = excluded.payload, cached_at = excluded.cached_at, updated_at = excluded.updated_at;

  return payload;
end;
$$;

grant select on public.widget_hotspot_summary_cache to authenticated;
grant execute on function public.rpc_get_widget_hotspot_summary(double precision, timestamptz) to anon, authenticated, service_role;
