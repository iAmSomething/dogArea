-- #44 AI caricature async pipeline

create extension if not exists pgcrypto;

alter table if exists public.pets
  add column if not exists caricature_status text default 'queued',
  add column if not exists caricature_provider text,
  add column if not exists caricature_style text,
  add column if not exists caricature_url text;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'pets' and column_name = 'caricature_status'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'pets_caricature_status_check'
  ) then
    alter table public.pets
      add constraint pets_caricature_status_check
      check (caricature_status in ('queued', 'processing', 'ready', 'failed'));
  end if;
end $$;

create table if not exists public.caricature_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  pet_id uuid not null,
  style text not null default 'cute_cartoon',
  provider_chain text not null default 'gemini>openai',
  status text not null default 'queued',
  error_message text,
  retry_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint caricature_jobs_status_check
    check (status in ('queued', 'processing', 'ready', 'failed'))
);

create index if not exists idx_caricature_jobs_user_id on public.caricature_jobs(user_id);
create index if not exists idx_caricature_jobs_pet_id on public.caricature_jobs(pet_id);
create index if not exists idx_caricature_jobs_status on public.caricature_jobs(status);
create index if not exists idx_caricature_jobs_created_at on public.caricature_jobs(created_at desc);

do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'pets')
     and not exists (
       select 1 from pg_constraint where conname = 'caricature_jobs_pet_id_fkey'
     ) then
    alter table public.caricature_jobs
      add constraint caricature_jobs_pet_id_fkey
      foreign key (pet_id) references public.pets(id) on delete cascade;
  end if;
end $$;

alter table public.caricature_jobs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'caricature_jobs'
      and policyname = 'caricature_jobs_select_own'
  ) then
    create policy caricature_jobs_select_own
      on public.caricature_jobs
      for select
      using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'caricature_jobs'
      and policyname = 'caricature_jobs_insert_service_role'
  ) then
    create policy caricature_jobs_insert_service_role
      on public.caricature_jobs
      for insert
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'caricature_jobs'
      and policyname = 'caricature_jobs_update_service_role'
  ) then
    create policy caricature_jobs_update_service_role
      on public.caricature_jobs
      for update
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_caricature_jobs_updated_at on public.caricature_jobs;
create trigger trg_caricature_jobs_updated_at
before update on public.caricature_jobs
for each row execute function public.touch_updated_at();
