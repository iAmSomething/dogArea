-- #595 owner walk stats duration parity

create or replace view public.view_owner_walk_stats as
with session_stats as (
  select
    owner_user_id,
    count(*)::bigint as session_count,
    coalesce(sum(area_m2), 0)::double precision as total_area_m2,
    coalesce(sum(duration_sec), 0)::double precision as total_duration_sec
  from public.walk_sessions
  group by owner_user_id
),
point_stats as (
  select
    ws.owner_user_id,
    count(wp.id)::bigint as point_count
  from public.walk_points wp
  join public.walk_sessions ws on ws.id = wp.walk_session_id
  group by ws.owner_user_id
)
select
  coalesce(s.owner_user_id, p.owner_user_id) as owner_user_id,
  coalesce(s.session_count, 0)::bigint as session_count,
  coalesce(p.point_count, 0)::bigint as point_count,
  coalesce(s.total_area_m2, 0)::double precision as total_area_m2,
  coalesce(s.total_duration_sec, 0)::double precision as total_duration_sec
from session_stats s
full outer join point_stats p on p.owner_user_id = s.owner_user_id;

grant select on public.view_owner_walk_stats to authenticated, service_role;
