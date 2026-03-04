-- #237 Live Presence 스키마 + RPC + TTL + RLS

create extension if not exists pgcrypto;

create table if not exists public.walk_live_presence (
  owner_user_id uuid primary key,
  session_id uuid not null,
  lat_rounded double precision not null,
  lng_rounded double precision not null,
  geohash7 text not null,
  speed_mps double precision,
  sequence bigint not null default 0,
  idempotency_key text not null default gen_random_uuid()::text,
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 seconds'),
  created_at timestamptz not null default now(),
  constraint walk_live_presence_speed_non_negative
    check (speed_mps is null or speed_mps >= 0),
  constraint walk_live_presence_lat_range
    check (lat_rounded between -90 and 90),
  constraint walk_live_presence_lng_range
    check (lng_rounded between -180 and 180)
);

create index if not exists idx_walk_live_presence_geohash7
  on public.walk_live_presence(geohash7);

create index if not exists idx_walk_live_presence_updated_at
  on public.walk_live_presence(updated_at desc);

create index if not exists idx_walk_live_presence_expires_at
  on public.walk_live_presence(expires_at asc);

create index if not exists idx_walk_live_presence_owner_user_id
  on public.walk_live_presence(owner_user_id);

alter table public.walk_live_presence enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'walk_live_presence'
      and policyname = 'walk_live_presence_select_visible_or_own'
  ) then
    create policy walk_live_presence_select_visible_or_own
      on public.walk_live_presence
      for select
      using (
        auth.role() = 'service_role'
        or auth.uid() = owner_user_id
        or (
          auth.role() = 'authenticated'
          and exists (
            select 1
            from public.user_visibility_settings v
            where v.user_id = owner_user_id
              and v.location_sharing_enabled = true
          )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'walk_live_presence'
      and policyname = 'walk_live_presence_write_own_or_service'
  ) then
    create policy walk_live_presence_write_own_or_service
      on public.walk_live_presence
      for all
      using (auth.role() = 'service_role' or auth.uid() = owner_user_id)
      with check (auth.role() = 'service_role' or auth.uid() = owner_user_id);
  end if;
end $$;

grant select, insert, update, delete on public.walk_live_presence to authenticated, service_role;

drop function if exists public.rpc_upsert_walk_live_presence(
  uuid,
  uuid,
  double precision,
  double precision,
  text,
  double precision,
  bigint,
  text,
  timestamptz,
  integer
);

create or replace function public.rpc_upsert_walk_live_presence(
  in_owner_user_id uuid,
  in_session_id uuid,
  in_lat_rounded double precision,
  in_lng_rounded double precision,
  in_geohash7 text,
  in_speed_mps double precision default null,
  in_sequence bigint default 0,
  in_idempotency_key text default null,
  in_updated_at timestamptz default now(),
  in_ttl_seconds integer default 90
)
returns table (
  owner_user_id uuid,
  session_id uuid,
  lat_rounded double precision,
  lng_rounded double precision,
  geohash7 text,
  speed_mps double precision,
  sequence bigint,
  idempotency_key text,
  updated_at timestamptz,
  expires_at timestamptz,
  write_applied boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_role text := coalesce(auth.role(), '');
  requester_uid uuid := auth.uid();
  normalized_lat double precision;
  normalized_lng double precision;
  normalized_geohash text;
  effective_updated_at timestamptz := coalesce(in_updated_at, now());
  effective_idempotency_key text := coalesce(nullif(trim(in_idempotency_key), ''), gen_random_uuid()::text);
  effective_sequence bigint := greatest(coalesce(in_sequence, 0), 0);
  effective_ttl_seconds integer := least(greatest(coalesce(in_ttl_seconds, 90), 60), 90);
  affected_count integer := 0;
begin
  if in_owner_user_id is null or in_session_id is null then
    raise exception 'owner_user_id and session_id are required';
  end if;

  if requester_role <> 'service_role' then
    if requester_uid is null then
      raise exception 'authenticated session required';
    end if;
    if requester_uid <> in_owner_user_id then
      raise exception 'request user mismatch';
    end if;
  end if;

  normalized_lat := round(in_lat_rounded::numeric, 4)::double precision;
  normalized_lng := round(in_lng_rounded::numeric, 4)::double precision;
  normalized_geohash := lower(trim(in_geohash7));

  if normalized_geohash = '' then
    raise exception 'geohash7 is required';
  end if;

  with upserted as (
    insert into public.walk_live_presence (
      owner_user_id,
      session_id,
      lat_rounded,
      lng_rounded,
      geohash7,
      speed_mps,
      sequence,
      idempotency_key,
      updated_at,
      expires_at
    )
    values (
      in_owner_user_id,
      in_session_id,
      normalized_lat,
      normalized_lng,
      normalized_geohash,
      in_speed_mps,
      effective_sequence,
      effective_idempotency_key,
      effective_updated_at,
      effective_updated_at + make_interval(secs => effective_ttl_seconds)
    )
    on conflict (owner_user_id) do update
      set session_id = excluded.session_id,
          lat_rounded = excluded.lat_rounded,
          lng_rounded = excluded.lng_rounded,
          geohash7 = excluded.geohash7,
          speed_mps = excluded.speed_mps,
          sequence = excluded.sequence,
          idempotency_key = excluded.idempotency_key,
          updated_at = excluded.updated_at,
          expires_at = excluded.expires_at
      where public.walk_live_presence.idempotency_key is distinct from excluded.idempotency_key
        and (
          excluded.updated_at > public.walk_live_presence.updated_at
          or (
            excluded.updated_at = public.walk_live_presence.updated_at
            and excluded.sequence >= public.walk_live_presence.sequence
          )
        )
    returning 1
  )
  select count(*)::integer
  into affected_count
  from upserted;

  return query
  select
    p.owner_user_id,
    p.session_id,
    p.lat_rounded,
    p.lng_rounded,
    p.geohash7,
    p.speed_mps,
    p.sequence,
    p.idempotency_key,
    p.updated_at,
    p.expires_at,
    affected_count > 0
  from public.walk_live_presence p
  where p.owner_user_id = in_owner_user_id;
end;
$$;

grant execute on function public.rpc_upsert_walk_live_presence(
  uuid,
  uuid,
  double precision,
  double precision,
  text,
  double precision,
  bigint,
  text,
  timestamptz,
  integer
) to authenticated, service_role;

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
  in_now_ts timestamptz default now()
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
  privacy_mode text
)
language sql
security definer
set search_path = public
as $$
  with bounded as (
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
  )
  select
    b.owner_user_id,
    b.session_id,
    b.lat_rounded,
    b.lng_rounded,
    b.geohash7,
    b.speed_mps,
    b.updated_at,
    b.expires_at,
    case when b.is_public then 'public' else 'private' end as privacy_mode
  from bounded b
  where case lower(coalesce(in_privacy_mode, 'public'))
    when 'all' then true
    when 'private' then b.is_public = false
    else b.is_public = true or b.owner_user_id = auth.uid()
  end
  order by b.updated_at desc, b.owner_user_id asc
  limit greatest(1, least(coalesce(in_max_rows, 200), 1000));
$$;

grant execute on function public.rpc_get_walk_live_presence(
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  text,
  timestamptz
) to authenticated, service_role;

create or replace function public.rpc_cleanup_walk_live_presence(
  in_now_ts timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  delete from public.walk_live_presence
  where expires_at <= coalesce(in_now_ts, now());

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

grant execute on function public.rpc_cleanup_walk_live_presence(timestamptz) to service_role;

do $$
declare
  existing_job_id integer;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_namespace where nspname = 'cron') then
    select jobid
    into existing_job_id
    from cron.job
    where jobname = 'walk_live_presence_ttl_cleanup'
    limit 1;

    if existing_job_id is not null then
      perform cron.unschedule(existing_job_id);
    end if;

    perform cron.schedule(
      'walk_live_presence_ttl_cleanup',
      '* * * * *',
      'select public.rpc_cleanup_walk_live_presence();'
    );
  end if;
exception
  when undefined_table or undefined_function or invalid_schema_name then
    raise notice 'walk_live_presence ttl cleanup scheduler skipped (cron unavailable)';
  when others then
    raise notice 'walk_live_presence ttl cleanup scheduler skipped: %', sqlerrm;
end;
$$;
