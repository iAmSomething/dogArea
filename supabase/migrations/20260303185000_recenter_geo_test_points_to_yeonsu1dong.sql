-- Recenter geo test walk points to Yeonsu 1-dong (Incheon).
-- Previous base: 37.4565, 126.7052
-- New base:      37.421944, 126.682778

do $$
declare
  old_base_lat constant double precision := 37.4565;
  old_base_lng constant double precision := 126.7052;
  new_base_lat constant double precision := 37.421944;
  new_base_lng constant double precision := 126.682778;
  delta_lat double precision := new_base_lat - old_base_lat;
  delta_lng double precision := new_base_lng - old_base_lng;
begin
  update public.walk_points wp
  set
    lat = wp.lat + delta_lat,
    lng = wp.lng + delta_lng
  where exists (
    select 1
    from public.walk_sessions ws
    join auth.users au on au.id = ws.owner_user_id
    where ws.id = wp.walk_session_id
      and au.email like 'dogarea.test.geo%@dogarea.test'
  );
end
$$;
