-- #46 feature flag + rollout monitoring

create table if not exists public.feature_flags (
  key text primary key,
  is_enabled boolean not null default false,
  rollout_percent integer not null default 0 check (rollout_percent >= 0 and rollout_percent <= 100),
  description text,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (key, is_enabled, rollout_percent, description)
values
  ('ff_heatmap_v1', true, 100, 'Heatmap overlay v1'),
  ('ff_caricature_async_v1', true, 100, 'Caricature async pipeline v1'),
  ('ff_nearby_hotspot_v1', true, 100, 'Nearby anonymous hotspot v1')
on conflict (key) do nothing;

create table if not exists public.app_metric_events (
  id bigint generated always as identity primary key,
  event_name text not null,
  feature_key text,
  event_value double precision,
  app_instance_id text not null,
  user_key text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_metric_events_created_at
  on public.app_metric_events(created_at desc);
create index if not exists idx_app_metric_events_event_name_created_at
  on public.app_metric_events(event_name, created_at desc);
create index if not exists idx_app_metric_events_feature_key
  on public.app_metric_events(feature_key);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_feature_flags_updated_at on public.feature_flags;
create trigger trg_feature_flags_updated_at
before update on public.feature_flags
for each row execute function public.touch_updated_at();

alter table public.feature_flags enable row level security;
alter table public.app_metric_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'feature_flags'
      and policyname = 'feature_flags_select_all'
  ) then
    create policy feature_flags_select_all
      on public.feature_flags
      for select
      to anon, authenticated
      using (true);
  end if;
end $$;

create or replace view public.view_rollout_kpis_24h as
with metrics as (
  select event_name, user_key
  from public.app_metric_events
  where created_at >= now() - interval '24 hours'
),
agg as (
  select
    count(*) filter (where event_name = 'walk_save_success')::double precision as walk_success,
    count(*) filter (where event_name = 'walk_save_failed')::double precision as walk_failed,
    count(*) filter (where event_name = 'watch_action_processed')::double precision as watch_processed,
    count(*) filter (where event_name = 'watch_action_applied')::double precision as watch_applied,
    count(*) filter (where event_name = 'caricature_success')::double precision as caricature_success,
    count(*) filter (where event_name = 'caricature_failed')::double precision as caricature_failed,
    count(distinct user_key) filter (where event_name = 'nearby_opt_in_enabled')::double precision as nearby_opt_in_users,
    count(distinct user_key) filter (where event_name in ('nearby_opt_in_enabled', 'nearby_opt_in_disabled'))::double precision as nearby_opt_in_touched_users
  from metrics
)
select
  now() as calculated_at,
  case
    when (walk_success + walk_failed) = 0 then null
    else walk_success / nullif(walk_success + walk_failed, 0)
  end as walk_save_success_rate,
  case
    when watch_processed = 0 then null
    else 1 - (watch_applied / nullif(watch_processed, 0))
  end as watch_action_loss_rate,
  case
    when (caricature_success + caricature_failed) = 0 then null
    else caricature_success / nullif(caricature_success + caricature_failed, 0)
  end as caricature_success_rate,
  case
    when nearby_opt_in_touched_users = 0 then null
    else nearby_opt_in_users / nullif(nearby_opt_in_touched_users, 0)
  end as nearby_opt_in_ratio,
  walk_success::bigint as walk_success_count,
  walk_failed::bigint as walk_failed_count,
  watch_processed::bigint as watch_processed_count,
  watch_applied::bigint as watch_applied_count,
  caricature_success::bigint as caricature_success_count,
  caricature_failed::bigint as caricature_failed_count,
  nearby_opt_in_users::bigint as nearby_opt_in_users,
  nearby_opt_in_touched_users::bigint as nearby_opt_in_touched_users
from agg;

grant select on public.feature_flags to anon, authenticated;
grant select on public.view_rollout_kpis_24h to anon, authenticated;
