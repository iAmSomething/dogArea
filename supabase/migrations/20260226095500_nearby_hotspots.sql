-- #45 nearby anonymous hotspot v1

create extension if not exists pgcrypto;

create table if not exists public.user_visibility_settings (
  user_id uuid primary key,
  location_sharing_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.nearby_presence (
  user_id uuid primary key,
  geohash7 text not null,
  lat_rounded double precision not null,
  lng_rounded double precision not null,
  last_seen_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists idx_nearby_presence_geohash7 on public.nearby_presence(geohash7);
create index if not exists idx_nearby_presence_last_seen on public.nearby_presence(last_seen_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_visibility_settings_updated_at on public.user_visibility_settings;
create trigger trg_user_visibility_settings_updated_at
before update on public.user_visibility_settings
for each row execute function public.touch_updated_at();

drop trigger if exists trg_nearby_presence_updated_at on public.nearby_presence;
create trigger trg_nearby_presence_updated_at
before update on public.nearby_presence
for each row execute function public.touch_updated_at();

alter table public.user_visibility_settings enable row level security;
alter table public.nearby_presence enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_visibility_settings'
      and policyname = 'user_visibility_settings_select_own'
  ) then
    create policy user_visibility_settings_select_own
      on public.user_visibility_settings
      for select
      using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_visibility_settings'
      and policyname = 'user_visibility_settings_upsert_own'
  ) then
    create policy user_visibility_settings_upsert_own
      on public.user_visibility_settings
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'nearby_presence'
      and policyname = 'nearby_presence_select_own'
  ) then
    create policy nearby_presence_select_own
      on public.nearby_presence
      for select
      using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'nearby_presence'
      and policyname = 'nearby_presence_upsert_own'
  ) then
    create policy nearby_presence_upsert_own
      on public.nearby_presence
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

create or replace view public.view_nearby_hotspots as
with alive as (
  select *
  from public.nearby_presence
  where last_seen_at >= now() - interval '10 minutes'
)
select
  geohash7,
  count(*)::int as count,
  avg(lat_rounded)::double precision as center_lat,
  avg(lng_rounded)::double precision as center_lng,
  case
    when max(count(*)) over () = 0 then 0
    else count(*)::double precision / max(count(*)) over ()
  end as intensity
from alive
group by geohash7;

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
  center_lng double precision
)
language sql
security definer
set search_path = public
as $$
  with alive as (
    select *
    from public.nearby_presence
    where last_seen_at >= now_ts - interval '10 minutes'
  ),
  grouped as (
    select
      p.geohash7,
      count(*)::int as count,
      avg(p.lat_rounded)::double precision as center_lat,
      avg(p.lng_rounded)::double precision as center_lng
    from alive p
    where
      sqrt(
        power((p.lat_rounded - center_lat), 2) +
        power((p.lng_rounded - center_lng) * cos(radians(center_lat)), 2)
      ) * 111.32 <= radius_km
    group by p.geohash7
  )
  select
    g.geohash7,
    g.count,
    case
      when max(g.count) over () = 0 then 0
      else g.count::double precision / max(g.count) over ()
    end as intensity,
    g.center_lat,
    g.center_lng
  from grouped g
  order by g.count desc, g.geohash7 asc;
$$;

grant execute on function public.rpc_get_nearby_hotspots(double precision, double precision, double precision, timestamptz) to anon, authenticated;
grant select on public.view_nearby_hotspots to anon, authenticated;
