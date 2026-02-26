-- #114 User/Pet extended profile fields sync foundation
-- Adds profile_message/breed/age_years/gender with safe backfill and constraints.

alter table public.profiles
  add column if not exists profile_message text;

alter table public.pets
  add column if not exists breed text,
  add column if not exists age_years integer,
  add column if not exists gender text not null default 'unknown';

update public.pets
set gender = 'unknown'
where gender is null
   or gender not in ('unknown', 'male', 'female');

update public.pets
set age_years = null
where age_years is not null
  and (age_years < 0 or age_years > 30);

update public.pets
set breed = null
where breed is not null
  and length(btrim(breed)) = 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_age_years_range_check'
  ) then
    alter table public.pets
      add constraint pets_age_years_range_check
      check (age_years is null or (age_years >= 0 and age_years <= 30));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_gender_allowed_check'
  ) then
    alter table public.pets
      add constraint pets_gender_allowed_check
      check (gender in ('unknown', 'male', 'female'));
  end if;
end $$;

create index if not exists idx_pets_owner_gender_updated
  on public.pets(owner_user_id, gender, updated_at desc);
