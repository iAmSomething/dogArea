-- DRAFT: Multi-pet N:M phase-2 migration for walk_session_pets
-- Issue: #64
-- NOTE:
-- - This migration is intentionally guarded so it can be committed before
--   full table rollout. It only executes DDL/DML when required base tables exist.

do $$
begin
  if to_regclass('public.walk_sessions') is null
     or to_regclass('public.pets') is null then
    raise notice 'skip walk_session_pets phase2 draft: base tables missing';
    return;
  end if;
end $$;

-- 1) Bridge table ensure
do $$
begin
  if to_regclass('public.walk_session_pets') is null then
    execute $sql$
      create table public.walk_session_pets (
        walk_session_id uuid not null,
        pet_id uuid not null,
        is_primary boolean not null default false,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now(),
        primary key (walk_session_id, pet_id)
      )
    $sql$;
  end if;
end $$;

-- 2) Column ensure for existing bridge table
do $$
begin
  if to_regclass('public.walk_session_pets') is not null then
    begin
      execute 'alter table public.walk_session_pets add column if not exists is_primary boolean not null default false';
      execute 'alter table public.walk_session_pets add column if not exists created_at timestamptz not null default now()';
      execute 'alter table public.walk_session_pets add column if not exists updated_at timestamptz not null default now()';
    exception when others then
      raise notice 'column ensure skipped: %', sqlerrm;
    end;
  end if;
end $$;

-- 3) FK/Index ensure
do $$
begin
  if to_regclass('public.walk_session_pets') is null then
    return;
  end if;

  begin
    execute '
      alter table public.walk_session_pets
      add constraint walk_session_pets_walk_session_id_fkey
      foreign key (walk_session_id)
      references public.walk_sessions(id)
      on delete cascade
    ';
  exception when duplicate_object then
    null;
  end;

  begin
    execute '
      alter table public.walk_session_pets
      add constraint walk_session_pets_pet_id_fkey
      foreign key (pet_id)
      references public.pets(id)
      on delete cascade
    ';
  exception when duplicate_object then
    null;
  end;

  execute 'create index if not exists idx_walk_session_pets_pet_session on public.walk_session_pets (pet_id, walk_session_id)';
  execute 'create index if not exists idx_walk_session_pets_primary on public.walk_session_pets (walk_session_id, is_primary)';
end $$;

-- 4) Backfill from single-pet model (idempotent)
do $$
begin
  if to_regclass('public.walk_session_pets') is null then
    return;
  end if;

  execute $sql$
    insert into public.walk_session_pets (walk_session_id, pet_id, is_primary, created_at, updated_at)
    select ws.id, ws.pet_id, true, now(), now()
    from public.walk_sessions ws
    where ws.pet_id is not null
    on conflict (walk_session_id, pet_id)
    do update set is_primary = excluded.is_primary,
                  updated_at = now()
  $sql$;
end $$;

-- 5) Validation helper view (non-breaking)
create or replace view public.v_walk_session_pets_backfill_check as
select
  (select count(*) from public.walk_sessions ws where ws.pet_id is not null) as session_with_pet_count,
  (select count(distinct wsp.walk_session_id) from public.walk_session_pets wsp) as bridged_session_count,
  (
    select count(*)
    from public.walk_sessions ws
    left join public.walk_session_pets wsp on ws.id = wsp.walk_session_id
    where ws.pet_id is not null
      and wsp.walk_session_id is null
  ) as missing_bridge_count;
