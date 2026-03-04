-- Add richer QA variants to geo test data.
-- Covers:
-- 1) source_device mix (ios/watchos/imported)
-- 2) in-progress sessions (ended_at null)
-- 3) map_image_url mixed (real URL / null / seed tag)
-- 4) caricature_url partially populated
-- 5) boundary sessions (very short duration, 3-point polygons)

do $$
declare
  base_lat constant double precision := 37.4565;
  base_lng constant double precision := 126.7052;
  lat_meter constant double precision := 111320.0;
  lng_meter constant double precision := 111320.0 * cos(radians(37.4565));
  max_radius_m constant double precision := 1950.0;

  u record;
  p_idx integer;

  short_tag text;
  active_tag text;
  short_session_id uuid;
  active_session_id uuid;

  center_r_m double precision;
  center_theta double precision;
  center_lat double precision;
  center_lng double precision;
  ring_r_m double precision;
  ring_theta double precision;

  dx_m double precision;
  dy_m double precision;
  dist_m double precision;
  scale_factor double precision;
  point_lat double precision;
  point_lng double precision;

  short_duration_sec integer;
  short_started_at timestamptz;
  short_ended_at timestamptz;

  active_started_at timestamptz;
  active_duration_sec integer;
  active_area_m2 double precision;
  active_point_count integer;
begin
  for u in
    select
      pr.id as user_id,
      pr.display_name,
      p.id as pet_id,
      row_number() over (order by pr.display_name) as user_idx
    from public.profiles pr
    join lateral (
      select pp.id
      from public.pets pp
      where pp.owner_user_id = pr.id
      order by pp.created_at asc nulls last, pp.id asc
      limit 1
    ) p on true
    where pr.display_name in ('하늘산책가', '별빛산책가', '노을산책가', '새벽산책가', '바람산책가')
    order by pr.display_name
  loop
    -- A) Very short finished walk (1~3 min, 3 points)
    short_tag := format('seed://dogarea/geo2km/v4/%s/micro-short', u.user_id);
    if not exists (
      select 1 from public.walk_sessions ws
      where ws.owner_user_id = u.user_id
        and ws.map_image_url = short_tag
    ) then
      short_duration_sec := 60 + floor(random() * 121)::integer; -- 60..180
      short_started_at := date_trunc('day', now())
                          - make_interval(days => 1 + (u.user_idx % 5)::integer)
                          + make_interval(hours => 6 + (u.user_idx % 4)::integer, mins => floor(random() * 50)::integer);
      short_ended_at := short_started_at + make_interval(secs => short_duration_sec);

      insert into public.walk_sessions (
        owner_user_id,
        pet_id,
        started_at,
        ended_at,
        duration_sec,
        area_m2,
        map_image_url,
        source_device
      )
      values (
        u.user_id,
        u.pet_id,
        short_started_at,
        short_ended_at,
        short_duration_sec,
        round((20 + random() * 120)::numeric, 2)::double precision,
        short_tag,
        case when (u.user_idx % 2) = 0 then 'watchos' else 'ios' end
      )
      returning id into short_session_id;

      insert into public.walk_session_pets (walk_session_id, pet_id)
      values (short_session_id, u.pet_id)
      on conflict do nothing;

      center_r_m := sqrt(random()) * 1650.0;
      center_theta := random() * 2 * pi();
      center_lat := base_lat + (center_r_m * cos(center_theta)) / lat_meter;
      center_lng := base_lng + (center_r_m * sin(center_theta)) / lng_meter;

      for p_idx in 0..2 loop
        ring_r_m := 8 + random() * 30;
        ring_theta := (2 * pi() * p_idx / 3) + ((random() - 0.5) * 0.4);
        point_lat := center_lat + (ring_r_m * cos(ring_theta)) / lat_meter;
        point_lng := center_lng + (ring_r_m * sin(ring_theta)) / lng_meter;

        dx_m := (point_lng - base_lng) * lng_meter;
        dy_m := (point_lat - base_lat) * lat_meter;
        dist_m := sqrt(dx_m * dx_m + dy_m * dy_m);
        if dist_m > max_radius_m then
          scale_factor := max_radius_m / dist_m;
          dx_m := dx_m * scale_factor;
          dy_m := dy_m * scale_factor;
          point_lng := base_lng + (dx_m / lng_meter);
          point_lat := base_lat + (dy_m / lat_meter);
        end if;

        insert into public.walk_points (walk_session_id, seq_no, lat, lng, recorded_at)
        values (
          short_session_id,
          p_idx,
          point_lat,
          point_lng,
          short_started_at + make_interval(secs => floor((short_duration_sec::double precision * p_idx) / 2)::integer)
        );
      end loop;
    end if;

    -- B) In-progress sessions for two users
    if u.display_name in ('노을산책가', '별빛산책가') then
      active_tag := format('seed://dogarea/geo2km/v4/%s/active', u.user_id);
      if not exists (
        select 1 from public.walk_sessions ws
        where ws.owner_user_id = u.user_id
          and ws.map_image_url = active_tag
      ) then
        if u.display_name = '노을산책가' then
          active_started_at := now() - interval '35 minutes';
          active_duration_sec := 2100;
          active_area_m2 := 280;
          active_point_count := 4;
        else
          active_started_at := now() - interval '8 minutes';
          active_duration_sec := 0;
          active_area_m2 := 0;
          active_point_count := 2;
        end if;

        insert into public.walk_sessions (
          owner_user_id,
          pet_id,
          started_at,
          ended_at,
          duration_sec,
          area_m2,
          map_image_url,
          source_device
        )
        values (
          u.user_id,
          u.pet_id,
          active_started_at,
          null,
          active_duration_sec,
          active_area_m2,
          active_tag,
          case when u.display_name = '노을산책가' then 'ios' else 'watchos' end
        )
        returning id into active_session_id;

        insert into public.walk_session_pets (walk_session_id, pet_id)
        values (active_session_id, u.pet_id)
        on conflict do nothing;

        center_r_m := sqrt(random()) * 1200.0;
        center_theta := random() * 2 * pi();
        center_lat := base_lat + (center_r_m * cos(center_theta)) / lat_meter;
        center_lng := base_lng + (center_r_m * sin(center_theta)) / lng_meter;

        for p_idx in 0..(active_point_count - 1) loop
          ring_r_m := 15 + random() * 70;
          ring_theta := (2 * pi() * p_idx / greatest(active_point_count, 1)) + ((random() - 0.5) * 0.6);
          point_lat := center_lat + (ring_r_m * cos(ring_theta)) / lat_meter;
          point_lng := center_lng + (ring_r_m * sin(ring_theta)) / lng_meter;

          dx_m := (point_lng - base_lng) * lng_meter;
          dy_m := (point_lat - base_lat) * lat_meter;
          dist_m := sqrt(dx_m * dx_m + dy_m * dy_m);
          if dist_m > max_radius_m then
            scale_factor := max_radius_m / dist_m;
            dx_m := dx_m * scale_factor;
            dy_m := dy_m * scale_factor;
            point_lng := base_lng + (dx_m / lng_meter);
            point_lat := base_lat + (dy_m / lat_meter);
          end if;

          insert into public.walk_points (walk_session_id, seq_no, lat, lng, recorded_at)
          values (
            active_session_id,
            p_idx,
            point_lat,
            point_lng,
            active_started_at + make_interval(secs => p_idx * 120)
          );
        end loop;
      end if;
    end if;
  end loop;

  -- C) Existing completed sessions: diversify source_device + map image nullability/real URLs.
  with target_users as (
    select id
    from public.profiles
    where display_name in ('하늘산책가', '별빛산책가', '노을산책가', '새벽산책가', '바람산책가')
  ),
  ranked as (
    select
      ws.id,
      row_number() over (partition by ws.owner_user_id order by ws.started_at asc, ws.id) as rn
    from public.walk_sessions ws
    join target_users tu on tu.id = ws.owner_user_id
    where ws.ended_at is not null
      and ws.map_image_url like 'seed://dogarea/geo2km/v3/%'
  )
  update public.walk_sessions ws
  set
    source_device = case
      when (r.rn % 4) = 0 then 'watchos'
      when (r.rn % 4) = 1 then 'ios'
      else 'imported'
    end,
    map_image_url = case
      when (r.rn % 3) = 1 then 'https://images.unsplash.com/photo-1472396961693-142e6e269027?auto=format&fit=crop&w=1400&q=80'
      when (r.rn % 3) = 2 then null
      else ws.map_image_url
    end
  from ranked r
  where ws.id = r.id;

  -- D) Partial caricature_url fill (mix of populated + null)
  update public.pets p
  set caricature_url = case pr.display_name
    when '하늘산책가' then 'https://api.dicebear.com/9.x/adventurer/svg?seed=haneul-mongsil'
    when '노을산책가' then 'https://api.dicebear.com/9.x/adventurer/svg?seed=noeul-coco'
    when '바람산책가' then 'https://api.dicebear.com/9.x/adventurer/svg?seed=baram-latte'
    else null
  end
  from public.profiles pr
  where p.owner_user_id = pr.id
    and pr.display_name in ('하늘산책가', '별빛산책가', '노을산책가', '새벽산책가', '바람산책가');
end
$$;
