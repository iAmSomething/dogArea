-- #121 area_references catalog management + seed expansion

create table if not exists public.area_reference_catalogs (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.area_reference_catalogs
  add column if not exists code text,
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists sort_order integer not null default 100,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

with ranked as (
  select ctid,
         row_number() over (
           partition by lower(reference_name)
           order by updated_at desc nulls last, created_at desc nulls last, id
         ) as rn
  from public.area_references
)
delete from public.area_references ar
using ranked r
where ar.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_area_references_reference_name_unique
  on public.area_references(reference_name);

create unique index if not exists idx_area_reference_catalogs_code_unique
  on public.area_reference_catalogs(code);

create index if not exists idx_area_reference_catalogs_active_sort
  on public.area_reference_catalogs(is_active, sort_order asc);

alter table public.area_references
  add column if not exists catalog_id uuid,
  add column if not exists display_order integer not null default 1000,
  add column if not exists is_featured boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_references_display_order_nonnegative_check'
  ) then
    alter table public.area_references
      add constraint area_references_display_order_nonnegative_check
      check (display_order >= 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_reference_catalogs_sort_order_nonnegative_check'
  ) then
    alter table public.area_reference_catalogs
      add constraint area_reference_catalogs_sort_order_nonnegative_check
      check (sort_order >= 0);
  end if;
end $$;

insert into public.area_reference_catalogs (code, name, description, sort_order, is_active)
values
  ('kr_local_government', '국내 지자체', '국내 시군구/광역 지자체 비교군', 10, true),
  ('global_urban_parks', '해외 도시 공원', '글로벌 주요 도시 공원 비교군', 20, true),
  ('national_parks', '국립공원/보호구역', '국내외 대규모 자연공원 비교군', 30, true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

with default_catalog as (
  select id
  from public.area_reference_catalogs
  where code = 'kr_local_government'
  limit 1
)
update public.area_references ar
set
  catalog_id = dc.id,
  display_order = coalesce(ar.display_order, 1000),
  is_featured = coalesce(ar.is_featured, false)
from default_catalog dc
where ar.catalog_id is null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'area_references_catalog_id_fkey'
  ) then
    alter table public.area_references
      add constraint area_references_catalog_id_fkey
      foreign key (catalog_id) references public.area_reference_catalogs(id) on delete restrict;
  end if;
end $$;

alter table public.area_references
  alter column catalog_id set not null;

create index if not exists idx_area_references_catalog_featured_order
  on public.area_references(catalog_id, is_featured desc, display_order asc, area_m2 desc);

create index if not exists idx_area_references_country_category
  on public.area_references(country_code, category, area_m2 desc);

drop trigger if exists trg_area_reference_catalogs_updated_at on public.area_reference_catalogs;
create trigger trg_area_reference_catalogs_updated_at
before update on public.area_reference_catalogs
for each row execute function public.touch_updated_at();

alter table public.area_reference_catalogs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'area_reference_catalogs' and policyname = 'area_reference_catalogs_select_all'
  ) then
    create policy area_reference_catalogs_select_all on public.area_reference_catalogs
      for select to anon, authenticated
      using (is_active = true or auth.role() = 'service_role');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'area_reference_catalogs' and policyname = 'area_reference_catalogs_service_role_write'
  ) then
    create policy area_reference_catalogs_service_role_write on public.area_reference_catalogs
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

grant select on public.area_reference_catalogs to anon, authenticated;
grant all on public.area_reference_catalogs to service_role;

with catalogs as (
  select code, id
  from public.area_reference_catalogs
),
seed(catalog_code, reference_name, area_m2, category, country_code, source_label, source_url, source_note, is_featured, display_order) as (
  values
    ('kr_local_government', '강원특별자치도 홍천군', 1820580000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', true, 10),
    ('kr_local_government', '강원특별자치도 인제군', 1646190000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', true, 20),
    ('kr_local_government', '경상북도 안동시', 1522210000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', true, 30),
    ('kr_local_government', '강원특별자치도 평창군', 1464190000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', true, 40),
    ('kr_local_government', '경상북도 경주시', 1324950000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 50),
    ('kr_local_government', '경상북도 상주시', 1254680000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 60),
    ('kr_local_government', '강원특별자치도 정선군', 1219880000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 70),
    ('kr_local_government', '경상북도 봉화군', 1202280000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 80),
    ('kr_local_government', '강원특별자치도 삼척시', 1187830000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 90),
    ('kr_local_government', '경상북도 의성군', 1174630000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 100),
    ('kr_local_government', '경상북도 포항시', 1130780000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 110),
    ('kr_local_government', '강원특별자치도 영월군', 1127330000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 120),
    ('kr_local_government', '강원특별자치도 춘천시', 1116410000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 130),
    ('kr_local_government', '전라남도 해남군', 1043840000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 140),
    ('kr_local_government', '강원특별자치도 강릉시', 1040680000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '면적 단위 km² -> m² 변환 시드', false, 150),
    ('kr_local_government', '서울특별시', 605210000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '광역 지자체 비교군', true, 300),
    ('kr_local_government', '세종특별자치시', 464920000::double precision, 'municipality', 'KR', 'KOSIS', 'https://kosis.kr', '광역 지자체 비교군', false, 310),

    ('global_urban_parks', 'Central Park (NYC)', 3410000::double precision, 'urban_park', 'US', 'NYC Open Data', 'https://data.cityofnewyork.us', '도시 공원 비교군', true, 10),
    ('global_urban_parks', 'Golden Gate Park', 4120000::double precision, 'urban_park', 'US', 'San Francisco Data', 'https://data.sfgov.org', '도시 공원 비교군', true, 20),
    ('global_urban_parks', 'Griffith Park', 17400000::double precision, 'urban_park', 'US', 'LA Open Data', 'https://data.lacity.org', '도시 공원 비교군', true, 30),
    ('global_urban_parks', 'Hyde Park (London)', 1420000::double precision, 'urban_park', 'GB', 'Royal Parks', 'https://www.royalparks.org.uk', '도시 공원 비교군', false, 40),
    ('global_urban_parks', 'Ueno Park', 538000::double precision, 'urban_park', 'JP', 'Tokyo Park Data', 'https://www.tokyo-park.or.jp', '도시 공원 비교군', false, 50),
    ('global_urban_parks', 'Yoyogi Park', 540000::double precision, 'urban_park', 'JP', 'Tokyo Park Data', 'https://www.tokyo-park.or.jp', '도시 공원 비교군', false, 60),
    ('global_urban_parks', 'Nara Park', 5020000::double precision, 'urban_park', 'JP', 'Nara City', 'https://www.city.nara.lg.jp', '도시 공원 비교군', false, 70),
    ('global_urban_parks', 'Tiergarten (Berlin)', 2100000::double precision, 'urban_park', 'DE', 'Berlin Open Data', 'https://daten.berlin.de', '도시 공원 비교군', false, 80),
    ('global_urban_parks', 'Stanley Park', 4050000::double precision, 'urban_park', 'CA', 'City of Vancouver', 'https://opendata.vancouver.ca', '도시 공원 비교군', false, 90),
    ('global_urban_parks', 'Chapultepec Park', 6860000::double precision, 'urban_park', 'MX', 'CDMX Data', 'https://datos.cdmx.gob.mx', '도시 공원 비교군', false, 100),
    ('global_urban_parks', 'Lumpini Park', 576000::double precision, 'urban_park', 'TH', 'Bangkok Metropolitan', 'https://www.bangkok.go.th', '도시 공원 비교군', false, 110),
    ('global_urban_parks', 'Ibirapuera Park', 1580000::double precision, 'urban_park', 'BR', 'Sao Paulo Data', 'https://www.prefeitura.sp.gov.br', '도시 공원 비교군', false, 120),
    ('global_urban_parks', 'Parque del Retiro', 1250000::double precision, 'urban_park', 'ES', 'Madrid City', 'https://www.madrid.es', '도시 공원 비교군', false, 130),
    ('global_urban_parks', 'Phoenix Park (Dublin)', 7070000::double precision, 'urban_park', 'IE', 'OPW Ireland', 'https://www.opw.ie', '도시 공원 비교군', false, 140),
    ('global_urban_parks', 'Bois de Boulogne', 8460000::double precision, 'urban_park', 'FR', 'Paris Open Data', 'https://opendata.paris.fr', '도시 공원 비교군', false, 150),

    ('national_parks', '설악산국립공원', 398000000::double precision, 'national_park', 'KR', '국립공원공단', 'https://www.knps.or.kr', '국내 국립공원 비교군', true, 10),
    ('national_parks', '지리산국립공원', 471758000::double precision, 'national_park', 'KR', '국립공원공단', 'https://www.knps.or.kr', '국내 국립공원 비교군', true, 20),
    ('national_parks', '한라산국립공원', 153300000::double precision, 'national_park', 'KR', '국립공원공단', 'https://www.knps.or.kr', '국내 국립공원 비교군', false, 30),
    ('national_parks', '북한산국립공원', 79900000::double precision, 'national_park', 'KR', '국립공원공단', 'https://www.knps.or.kr', '국내 국립공원 비교군', false, 40),
    ('national_parks', 'Yosemite National Park', 3027000000::double precision, 'national_park', 'US', 'US National Park Service', 'https://www.nps.gov', '해외 국립공원 비교군', true, 100),
    ('national_parks', 'Yellowstone National Park', 8983000000::double precision, 'national_park', 'US', 'US National Park Service', 'https://www.nps.gov', '해외 국립공원 비교군', true, 110),
    ('national_parks', 'Everglades National Park', 6105000000::double precision, 'national_park', 'US', 'US National Park Service', 'https://www.nps.gov', '해외 국립공원 비교군', false, 120),
    ('national_parks', 'Great Smoky Mountains', 2114000000::double precision, 'national_park', 'US', 'US National Park Service', 'https://www.nps.gov', '해외 국립공원 비교군', false, 130),
    ('national_parks', 'Grand Canyon National Park', 4927000000::double precision, 'national_park', 'US', 'US National Park Service', 'https://www.nps.gov', '해외 국립공원 비교군', false, 140),
    ('national_parks', 'Banff National Park', 6641000000::double precision, 'national_park', 'CA', 'Parks Canada', 'https://parks.canada.ca', '해외 국립공원 비교군', false, 150)
)
insert into public.area_references (
  catalog_id,
  reference_name,
  area_m2,
  category,
  country_code,
  source_label,
  source_url,
  is_active,
  metadata,
  display_order,
  is_featured
)
select
  c.id,
  s.reference_name,
  s.area_m2,
  s.category,
  s.country_code,
  s.source_label,
  s.source_url,
  true,
  jsonb_build_object(
    'source_note', s.source_note,
    'seed_version', '2026_q1_v2'
  ),
  s.display_order,
  s.is_featured
from seed s
join catalogs c on c.code = s.catalog_code
on conflict (reference_name)
do update set
  catalog_id = excluded.catalog_id,
  area_m2 = excluded.area_m2,
  category = excluded.category,
  country_code = excluded.country_code,
  source_label = excluded.source_label,
  source_url = excluded.source_url,
  is_active = excluded.is_active,
  metadata = excluded.metadata,
  display_order = excluded.display_order,
  is_featured = excluded.is_featured,
  updated_at = now();
