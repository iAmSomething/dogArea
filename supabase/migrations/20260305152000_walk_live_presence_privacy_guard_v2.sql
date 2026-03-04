-- #240 live presence privacy guard v2

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
  'walk_live_presence',
  3,
  0.80,
  1,
  3,
  10,
  22,
  6,
  'Asia/Seoul',
  true
)
on conflict (policy_key) do update
set
  min_sample_size = excluded.min_sample_size,
  percentile_fallback = excluded.percentile_fallback,
  daytime_delay_minutes = excluded.daytime_delay_minutes,
  nighttime_delay_minutes = excluded.nighttime_delay_minutes,
  active_window_minutes = excluded.active_window_minutes,
  night_start_hour = excluded.night_start_hour,
  night_end_hour = excluded.night_end_hour,
  policy_timezone = excluded.policy_timezone,
  sensitive_mask_enabled = excluded.sensitive_mask_enabled,
  updated_at = now();

alter table public.privacy_guard_audit_logs
  add column if not exists request_min_lat double precision,
  add column if not exists request_max_lat double precision,
  add column if not exists request_min_lng double precision,
  add column if not exists request_max_lng double precision,
  add column if not exists total_presence integer not null default 0,
  add column if not exists suppressed_presence integer not null default 0,
  add column if not exists delayed_presence integer not null default 0,
  add column if not exists sensitive_presence integer not null default 0,
  add column if not exists k_anon_presence integer not null default 0,
  add column if not exists excluded_presence integer not null default 0,
  add column if not exists obfuscation_meters integer not null default 0;

drop function if exists public.rpc_get_walk_live_presence(
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  text,
  timestamptz
);

create or replace function public.rpc_get_walk_live_presence(
  in_min_lat double precision,
  in_max_lat double precision,
  in_min_lng double precision,
  in_max_lng double precision,
  in_max_rows integer default 200,
  in_privacy_mode text default 'public',
  in_now_ts timestamptz default now(),
  in_request_user_id uuid default null,
  in_excluded_user_ids uuid[] default null
)
returns table (
  owner_user_id uuid,
  session_id uuid,
  lat_rounded double precision,
  lng_rounded double precision,
  geohash7 text,
  speed_mps double precision,
  updated_at timestamptz,
  expires_at timestamptz,
  privacy_mode text,
  suppression_reason text,
  delay_minutes integer,
  required_min_sample integer,
  obfuscation_meters integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  policy_row public.privacy_guard_policies%rowtype;
  requester_id uuid := coalesce(in_request_user_id, auth.uid());
  local_now timestamp;
  local_hour integer;
  is_night boolean;
  effective_delay integer;
  min_samples integer;
  timezone_name text;
  mask_enabled boolean;
  max_rows integer := greatest(1, least(coalesce(in_max_rows, 200), 1000));
begin
  select *
  into policy_row
  from public.privacy_guard_policies
  where policy_key = 'walk_live_presence'
  limit 1;

  if not found then
    min_samples := 3;
    effective_delay := 1;
    timezone_name := 'Asia/Seoul';
    mask_enabled := true;
    local_now := coalesce(in_now_ts, now()) at time zone timezone_name;
    local_hour := extract(hour from local_now)::integer;
    is_night := local_hour >= 22 or local_hour < 6;
    if is_night then
      effective_delay := 3;
    end if;
  else
    min_samples := greatest(2, coalesce(policy_row.min_sample_size, 3));
    mask_enabled := coalesce(policy_row.sensitive_mask_enabled, true);
    timezone_name := coalesce(nullif(policy_row.policy_timezone, ''), 'Asia/Seoul');

    local_now := coalesce(in_now_ts, now()) at time zone timezone_name;
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
      when is_night then greatest(0, coalesce(policy_row.nighttime_delay_minutes, 3))
      else greatest(0, coalesce(policy_row.daytime_delay_minutes, 1))
    end;
  end if;

  return query
  with base as (
    select
      p.owner_user_id,
      p.session_id,
      p.lat_rounded,
      p.lng_rounded,
      p.geohash7,
      p.speed_mps,
      p.updated_at,
      p.expires_at,
      coalesce(v.location_sharing_enabled, false) as is_public
    from public.walk_live_presence p
    left join public.user_visibility_settings v
      on v.user_id = p.owner_user_id
    where p.expires_at > coalesce(in_now_ts, now())
      and p.lat_rounded between least(in_min_lat, in_max_lat) and greatest(in_min_lat, in_max_lat)
      and p.lng_rounded between least(in_min_lng, in_max_lng) and greatest(in_min_lng, in_max_lng)
  ),
  scoped as (
    select
      b.*,
      (requester_id is not null and b.owner_user_id = requester_id) as is_own,
      (
        in_excluded_user_ids is not null
        and cardinality(in_excluded_user_ids) > 0
        and b.owner_user_id = any(in_excluded_user_ids)
      ) as is_excluded,
      case
        when mask_enabled then public.is_coordinate_in_sensitive_mask(b.lat_rounded, b.lng_rounded)
        else false
      end as is_sensitive,
      count(*) over (partition by b.geohash7) as sample_count
    from base b
  ),
  guarded as (
    select
      s.*,
      case
        when s.is_own then null
        when s.is_excluded then 'excluded'
        when s.is_sensitive then 'sensitive_mask'
        when s.updated_at > coalesce(in_now_ts, now()) - make_interval(mins => effective_delay) then 'delayed'
        when s.sample_count < min_samples then 'k_anon'
        else null
      end as suppression_reason,
      case
        when s.is_own then 0
        else 30 + mod(
          get_byte(
            decode(md5(s.owner_user_id::text || ':' || date_trunc('minute', s.updated_at)::text || ':' || s.geohash7), 'hex'),
            0
          ),
          21
        )
      end as obfuscation_meters
    from scoped s
  ),
  included as (
    select *
    from guarded g
    where g.suppression_reason is null
      and case lower(coalesce(in_privacy_mode, 'public'))
        when 'all' then true
        when 'private' then g.is_public = false
        else g.is_public = true or g.is_own
      end
  ),
  transformed as (
    select
      i.owner_user_id,
      i.session_id,
      round((
        i.lat_rounded +
        case
          when i.obfuscation_meters <= 0 then 0
          else (
            (i.obfuscation_meters::double precision / 111320.0) *
            sin(radians(mod(
              (get_byte(decode(md5(i.owner_user_id::text || ':lat:' || i.geohash7), 'hex'), 1)::integer * 256)
              + get_byte(decode(md5(i.owner_user_id::text || ':lat:' || i.geohash7), 'hex'), 2)::integer,
              360
            )::double precision))
          )
        end
      )::numeric, 4)::double precision as masked_lat,
      round((
        i.lng_rounded +
        case
          when i.obfuscation_meters <= 0 then 0
          else (
            (i.obfuscation_meters::double precision /
              (111320.0 * greatest(0.2, abs(cos(radians(i.lat_rounded)))))) *
            cos(radians(mod(
              (get_byte(decode(md5(i.owner_user_id::text || ':lng:' || i.geohash7), 'hex'), 1)::integer * 256)
              + get_byte(decode(md5(i.owner_user_id::text || ':lng:' || i.geohash7), 'hex'), 2)::integer,
              360
            )::double precision))
          )
        end
      )::numeric, 4)::double precision as masked_lng,
      i.geohash7,
      i.speed_mps,
      i.updated_at,
      i.expires_at,
      case
        when i.is_own then coalesce(case when i.is_public then 'public' else 'private' end, 'private')
        when i.obfuscation_meters > 0 then 'guarded'
        when i.is_public then 'public'
        else 'private'
      end as privacy_mode,
      i.suppression_reason,
      effective_delay as delay_minutes,
      min_samples as required_min_sample,
      i.obfuscation_meters
    from included i
  )
  select
    t.owner_user_id,
    t.session_id,
    t.masked_lat as lat_rounded,
    t.masked_lng as lng_rounded,
    t.geohash7,
    t.speed_mps,
    t.updated_at,
    t.expires_at,
    t.privacy_mode,
    t.suppression_reason,
    t.delay_minutes,
    t.required_min_sample,
    t.obfuscation_meters
  from transformed t
  order by t.updated_at desc, t.owner_user_id asc
  limit max_rows;
end;
$$;

grant execute on function public.rpc_get_walk_live_presence(
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  text,
  timestamptz,
  uuid,
  uuid[]
) to authenticated, service_role;
