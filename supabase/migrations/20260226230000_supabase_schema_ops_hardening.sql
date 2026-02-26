-- #22 Supabase schema/RLS/storage operational hardening

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

-- 1) Core tables (create-if-missing + shape hardening)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  profile_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists display_name text not null default '',
  add column if not exists profile_image_url text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  photo_url text,
  caricature_url text,
  caricature_status text not null default 'queued',
  caricature_provider text,
  caricature_style text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.pets
  add column if not exists owner_user_id uuid,
  add column if not exists name text,
  add column if not exists photo_url text,
  add column if not exists caricature_url text,
  add column if not exists caricature_status text not null default 'queued',
  add column if not exists caricature_provider text,
  add column if not exists caricature_style text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_owner_user_id_fkey'
  ) then
    alter table public.pets
      add constraint pets_owner_user_id_fkey
      foreign key (owner_user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_name_nonempty_check'
  ) then
    alter table public.pets
      add constraint pets_name_nonempty_check
      check (length(btrim(name)) > 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_caricature_status_check'
  ) then
    alter table public.pets
      add constraint pets_caricature_status_check
      check (caricature_status in ('queued', 'processing', 'ready', 'failed'));
  end if;
end $$;

create table if not exists public.walk_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  pet_id uuid references public.pets(id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_sec integer not null default 0,
  area_m2 double precision not null default 0,
  map_image_url text,
  source_device text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.walk_sessions
  add column if not exists owner_user_id uuid,
  add column if not exists pet_id uuid,
  add column if not exists started_at timestamptz not null default now(),
  add column if not exists ended_at timestamptz,
  add column if not exists duration_sec integer not null default 0,
  add column if not exists area_m2 double precision not null default 0,
  add column if not exists map_image_url text,
  add column if not exists source_device text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_sessions_owner_user_id_fkey'
  ) then
    alter table public.walk_sessions
      add constraint walk_sessions_owner_user_id_fkey
      foreign key (owner_user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_sessions_pet_id_fkey'
  ) then
    alter table public.walk_sessions
      add constraint walk_sessions_pet_id_fkey
      foreign key (pet_id) references public.pets(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_sessions_duration_nonnegative_check'
  ) then
    alter table public.walk_sessions
      add constraint walk_sessions_duration_nonnegative_check
      check (duration_sec >= 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_sessions_area_nonnegative_check'
  ) then
    alter table public.walk_sessions
      add constraint walk_sessions_area_nonnegative_check
      check (area_m2 >= 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_sessions_ended_after_started_check'
  ) then
    alter table public.walk_sessions
      add constraint walk_sessions_ended_after_started_check
      check (ended_at is null or ended_at >= started_at);
  end if;
end $$;

create table if not exists public.walk_points (
  id bigint generated always as identity primary key,
  walk_session_id uuid not null references public.walk_sessions(id) on delete cascade,
  seq_no integer not null,
  lat double precision not null,
  lng double precision not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.walk_points
  add column if not exists walk_session_id uuid,
  add column if not exists seq_no integer,
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists recorded_at timestamptz not null default now(),
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_points_walk_session_id_fkey'
  ) then
    alter table public.walk_points
      add constraint walk_points_walk_session_id_fkey
      foreign key (walk_session_id) references public.walk_sessions(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_points_walk_session_id_seq_no_key'
  ) then
    alter table public.walk_points
      add constraint walk_points_walk_session_id_seq_no_key
      unique (walk_session_id, seq_no);
  end if;
end $$;

create table if not exists public.area_milestones (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  pet_id uuid references public.pets(id) on delete set null,
  area_name text not null,
  area_m2 double precision not null,
  achieved_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.area_milestones
  add column if not exists owner_user_id uuid,
  add column if not exists pet_id uuid,
  add column if not exists area_name text,
  add column if not exists area_m2 double precision,
  add column if not exists achieved_at timestamptz not null default now(),
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_milestones_owner_user_id_fkey'
  ) then
    alter table public.area_milestones
      add constraint area_milestones_owner_user_id_fkey
      foreign key (owner_user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_milestones_pet_id_fkey'
  ) then
    alter table public.area_milestones
      add constraint area_milestones_pet_id_fkey
      foreign key (pet_id) references public.pets(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_milestones_area_nonnegative_check'
  ) then
    alter table public.area_milestones
      add constraint area_milestones_area_nonnegative_check
      check (area_m2 >= 0);
  end if;
end $$;

create table if not exists public.walk_session_pets (
  walk_session_id uuid not null references public.walk_sessions(id) on delete cascade,
  pet_id uuid not null references public.pets(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (walk_session_id, pet_id)
);

alter table public.walk_session_pets
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_session_pets_walk_session_id_fkey'
  ) then
    alter table public.walk_session_pets
      add constraint walk_session_pets_walk_session_id_fkey
      foreign key (walk_session_id) references public.walk_sessions(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'walk_session_pets_pet_id_fkey'
  ) then
    alter table public.walk_session_pets
      add constraint walk_session_pets_pet_id_fkey
      foreign key (pet_id) references public.pets(id) on delete cascade;
  end if;
end $$;

create table if not exists public.area_references (
  id uuid primary key default gen_random_uuid(),
  reference_name text not null,
  area_m2 double precision not null,
  category text not null,
  country_code text,
  source_label text,
  source_url text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.area_references
  add column if not exists reference_name text,
  add column if not exists area_m2 double precision,
  add column if not exists category text,
  add column if not exists country_code text,
  add column if not exists source_label text,
  add column if not exists source_url text,
  add column if not exists is_active boolean not null default true,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_references_area_positive_check'
  ) then
    alter table public.area_references
      add constraint area_references_area_positive_check
      check (area_m2 > 0);
  end if;
end $$;

-- 2) Index hardening
create index if not exists idx_profiles_updated_at
  on public.profiles(updated_at desc);

create index if not exists idx_pets_owner_active_created
  on public.pets(owner_user_id, is_active, created_at desc);

create index if not exists idx_walk_sessions_owner_started
  on public.walk_sessions(owner_user_id, started_at desc);

create index if not exists idx_walk_sessions_pet_started
  on public.walk_sessions(pet_id, started_at desc);

create index if not exists idx_walk_points_session_seq
  on public.walk_points(walk_session_id, seq_no);

create index if not exists idx_walk_points_session_recorded
  on public.walk_points(walk_session_id, recorded_at asc);

create index if not exists idx_area_milestones_owner_achieved
  on public.area_milestones(owner_user_id, achieved_at desc);

create index if not exists idx_walk_session_pets_pet_session
  on public.walk_session_pets(pet_id, walk_session_id);

create index if not exists idx_area_references_active_category
  on public.area_references(is_active, category, area_m2 desc);

-- 3) updated_at triggers
drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_pets_updated_at on public.pets;
create trigger trg_pets_updated_at
before update on public.pets
for each row execute function public.touch_updated_at();

drop trigger if exists trg_walk_sessions_updated_at on public.walk_sessions;
create trigger trg_walk_sessions_updated_at
before update on public.walk_sessions
for each row execute function public.touch_updated_at();

drop trigger if exists trg_area_references_updated_at on public.area_references;
create trigger trg_area_references_updated_at
before update on public.area_references
for each row execute function public.touch_updated_at();

-- 4) RLS and owner policies
alter table public.profiles enable row level security;
alter table public.pets enable row level security;
alter table public.walk_sessions enable row level security;
alter table public.walk_points enable row level security;
alter table public.area_milestones enable row level security;
alter table public.walk_session_pets enable row level security;
alter table public.area_references enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_select_own'
  ) then
    create policy profiles_select_own on public.profiles
      for select using (id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_insert_own'
  ) then
    create policy profiles_insert_own on public.profiles
      for insert with check (id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own on public.profiles
      for update using (id = auth.uid()) with check (id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_delete_own'
  ) then
    create policy profiles_delete_own on public.profiles
      for delete using (id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'pets' and policyname = 'pets_owner_all'
  ) then
    create policy pets_owner_all on public.pets
      for all using (owner_user_id = auth.uid())
      with check (owner_user_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'walk_sessions' and policyname = 'walk_sessions_owner_all'
  ) then
    create policy walk_sessions_owner_all on public.walk_sessions
      for all using (owner_user_id = auth.uid())
      with check (owner_user_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'walk_points' and policyname = 'walk_points_owner_all'
  ) then
    create policy walk_points_owner_all on public.walk_points
      for all
      using (
        exists (
          select 1
          from public.walk_sessions ws
          where ws.id = walk_points.walk_session_id
            and ws.owner_user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.walk_sessions ws
          where ws.id = walk_points.walk_session_id
            and ws.owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'area_milestones' and policyname = 'area_milestones_owner_all'
  ) then
    create policy area_milestones_owner_all on public.area_milestones
      for all using (owner_user_id = auth.uid())
      with check (owner_user_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'walk_session_pets' and policyname = 'walk_session_pets_owner_all'
  ) then
    create policy walk_session_pets_owner_all on public.walk_session_pets
      for all
      using (
        exists (
          select 1
          from public.walk_sessions ws
          where ws.id = walk_session_pets.walk_session_id
            and ws.owner_user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.walk_sessions ws
          where ws.id = walk_session_pets.walk_session_id
            and ws.owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'area_references' and policyname = 'area_references_select_all'
  ) then
    create policy area_references_select_all on public.area_references
      for select to anon, authenticated
      using (is_active = true or auth.role() = 'service_role');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'area_references' and policyname = 'area_references_service_role_write'
  ) then
    create policy area_references_service_role_write on public.area_references
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

-- 5) Storage buckets + object policies
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    return;
  end if;

  insert into storage.buckets (id, name, public)
  values
    ('profiles', 'profiles', false),
    ('caricatures', 'caricatures', false),
    ('walk-maps', 'walk-maps', false)
  on conflict (id) do nothing;

  update storage.buckets
  set public = false
  where id in ('profiles', 'caricatures', 'walk-maps');

  execute 'alter table storage.objects enable row level security';
end $$;

do $$
begin
  if to_regclass('storage.objects') is null then
    return;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_profiles_select_own'
  ) then
    create policy storage_profiles_select_own on storage.objects
      for select
      using (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_profiles_insert_own'
  ) then
    create policy storage_profiles_insert_own on storage.objects
      for insert
      with check (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_profiles_update_own'
  ) then
    create policy storage_profiles_update_own on storage.objects
      for update
      using (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text)
      with check (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_profiles_delete_own'
  ) then
    create policy storage_profiles_delete_own on storage.objects
      for delete
      using (bucket_id = 'profiles' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_caricatures_select_own'
  ) then
    create policy storage_caricatures_select_own on storage.objects
      for select
      using (bucket_id = 'caricatures' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_caricatures_insert_own'
  ) then
    create policy storage_caricatures_insert_own on storage.objects
      for insert
      with check (bucket_id = 'caricatures' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_caricatures_update_own'
  ) then
    create policy storage_caricatures_update_own on storage.objects
      for update
      using (bucket_id = 'caricatures' and split_part(name, '/', 1) = auth.uid()::text)
      with check (bucket_id = 'caricatures' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_caricatures_delete_own'
  ) then
    create policy storage_caricatures_delete_own on storage.objects
      for delete
      using (bucket_id = 'caricatures' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_walk_maps_select_own'
  ) then
    create policy storage_walk_maps_select_own on storage.objects
      for select
      using (bucket_id = 'walk-maps' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_walk_maps_insert_own'
  ) then
    create policy storage_walk_maps_insert_own on storage.objects
      for insert
      with check (bucket_id = 'walk-maps' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_walk_maps_update_own'
  ) then
    create policy storage_walk_maps_update_own on storage.objects
      for update
      using (bucket_id = 'walk-maps' and split_part(name, '/', 1) = auth.uid()::text)
      with check (bucket_id = 'walk-maps' and split_part(name, '/', 1) = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'storage_walk_maps_delete_own'
  ) then
    create policy storage_walk_maps_delete_own on storage.objects
      for delete
      using (bucket_id = 'walk-maps' and split_part(name, '/', 1) = auth.uid()::text);
  end if;
end $$;

-- 6) Operational verification view (stats)
create or replace view public.view_owner_walk_stats as
with session_stats as (
  select
    owner_user_id,
    count(*)::bigint as session_count,
    coalesce(sum(area_m2), 0)::double precision as total_area_m2
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
  coalesce(s.total_area_m2, 0)::double precision as total_area_m2
from session_stats s
full outer join point_stats p on p.owner_user_id = s.owner_user_id;

grant select on public.view_owner_walk_stats to authenticated, service_role;
