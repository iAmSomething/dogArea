-- #125 season stage2 aggregation schema + daily decay/finalize pipeline

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

create table if not exists public.season_runs (
  id uuid primary key default gen_random_uuid(),
  season_key text not null unique,
  period_type text not null default 'weekly' check (period_type in ('weekly')),
  week_start date not null,
  week_end date not null,
  status text not null default 'active' check (status in ('active', 'settling', 'settled')),
  settlement_delay_hours integer not null default 2 check (settlement_delay_hours between 0 and 24),
  scoring_policy_key text not null default 'season_weekly_stage1_v1',
  new_tile_score double precision not null default 5 check (new_tile_score >= 0),
  hold_tile_daily_score double precision not null default 1 check (hold_tile_daily_score >= 0),
  hold_tile_daily_cap integer not null default 1 check (hold_tile_daily_cap between 0 and 5),
  decay_grace_hours integer not null default 48 check (decay_grace_hours between 0 and 336),
  decay_per_day double precision not null default 2 check (decay_per_day >= 0),
  tier_threshold_bronze integer not null default 80 check (tier_threshold_bronze >= 0),
  tier_threshold_silver integer not null default 180 check (tier_threshold_silver >= 0),
  tier_threshold_gold integer not null default 320 check (tier_threshold_gold >= 0),
  tier_threshold_platinum integer not null default 520 check (tier_threshold_platinum >= 0),
  finalized_at timestamptz,
  last_decay_run_at timestamptz,
  last_settlement_run_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint season_runs_week_valid check (week_end > week_start),
  constraint season_runs_weekly_unique unique (period_type, week_start)
);

create index if not exists idx_season_runs_status_week
  on public.season_runs(status, week_start desc);

create table if not exists public.tile_events (
  id bigint generated always as identity primary key,
  season_id uuid not null references public.season_runs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  tile_id text not null,
  event_day date not null,
  event_kind text not null check (event_kind in ('capture', 'hold')),
  score_delta double precision not null default 0 check (score_delta >= 0),
  source_walk_session_id uuid references public.walk_sessions(id) on delete set null,
  source_seq_no integer,
  source_recorded_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text generated always as (
    md5(
      coalesce(season_id::text, '') || ':' ||
      coalesce(owner_user_id::text, '') || ':' ||
      coalesce(tile_id, '') || ':' ||
      coalesce((event_day - date '2000-01-01')::text, '')
    )
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tile_events_daily_unique unique (season_id, owner_user_id, tile_id, event_day)
);

create index if not exists idx_tile_events_owner_day
  on public.tile_events(owner_user_id, event_day desc);
create index if not exists idx_tile_events_season_owner
  on public.tile_events(season_id, owner_user_id);
create unique index if not exists idx_tile_events_idempotency_key
  on public.tile_events(idempotency_key);

create table if not exists public.season_tile_scores (
  season_id uuid not null references public.season_runs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  tile_id text not null,
  raw_score double precision not null default 0 check (raw_score >= 0),
  decay_penalty double precision not null default 0 check (decay_penalty >= 0),
  effective_score double precision not null default 0 check (effective_score >= 0),
  first_captured_at timestamptz,
  last_contribution_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (season_id, owner_user_id, tile_id)
);

create index if not exists idx_season_tile_scores_owner_effective
  on public.season_tile_scores(owner_user_id, effective_score desc);
create index if not exists idx_season_tile_scores_season_effective
  on public.season_tile_scores(season_id, effective_score desc);

create table if not exists public.season_user_scores (
  season_id uuid not null references public.season_runs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  active_tile_count integer not null default 0 check (active_tile_count >= 0),
  new_tile_capture_count integer not null default 0 check (new_tile_capture_count >= 0),
  raw_score double precision not null default 0 check (raw_score >= 0),
  total_decay double precision not null default 0 check (total_decay >= 0),
  total_score double precision not null default 0 check (total_score >= 0),
  rank_position integer,
  tier text not null default 'none' check (tier in ('none', 'bronze', 'silver', 'gold', 'platinum')),
  last_contribution_at timestamptz,
  score_updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (season_id, owner_user_id)
);

create index if not exists idx_season_user_scores_season_rank
  on public.season_user_scores(season_id, rank_position);
create index if not exists idx_season_user_scores_owner_updated
  on public.season_user_scores(owner_user_id, score_updated_at desc);

create table if not exists public.season_rewards (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.season_runs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  reward_code text not null,
  tier text not null check (tier in ('bronze', 'silver', 'gold', 'platinum')),
  reward_payload jsonb not null default '{}'::jsonb,
  source_total_score double precision not null default 0 check (source_total_score >= 0),
  source_rank_position integer,
  issued_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint season_rewards_unique unique (season_id, owner_user_id, reward_code)
);

create index if not exists idx_season_rewards_owner_issued
  on public.season_rewards(owner_user_id, issued_at desc);
create index if not exists idx_season_rewards_season_tier
  on public.season_rewards(season_id, tier, source_rank_position);

alter table public.season_runs enable row level security;
alter table public.tile_events enable row level security;
alter table public.season_tile_scores enable row level security;
alter table public.season_user_scores enable row level security;
alter table public.season_rewards enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_runs'
      and policyname = 'season_runs_select_all'
  ) then
    create policy season_runs_select_all
      on public.season_runs
      for select
      to anon, authenticated
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tile_events'
      and policyname = 'tile_events_owner_select'
  ) then
    create policy tile_events_owner_select
      on public.tile_events
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tile_events'
      and policyname = 'tile_events_service_write'
  ) then
    create policy tile_events_service_write
      on public.tile_events
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_tile_scores'
      and policyname = 'season_tile_scores_owner_select'
  ) then
    create policy season_tile_scores_owner_select
      on public.season_tile_scores
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_tile_scores'
      and policyname = 'season_tile_scores_service_write'
  ) then
    create policy season_tile_scores_service_write
      on public.season_tile_scores
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_user_scores'
      and policyname = 'season_user_scores_owner_select'
  ) then
    create policy season_user_scores_owner_select
      on public.season_user_scores
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_user_scores'
      and policyname = 'season_user_scores_service_write'
  ) then
    create policy season_user_scores_service_write
      on public.season_user_scores
      for all
      to service_role
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_rewards'
      and policyname = 'season_rewards_owner_select'
  ) then
    create policy season_rewards_owner_select
      on public.season_rewards
      for select
      to authenticated
      using (owner_user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'season_rewards'
      and policyname = 'season_rewards_service_write'
  ) then
    create policy season_rewards_service_write
      on public.season_rewards
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end $$;

drop trigger if exists trg_season_runs_updated_at on public.season_runs;
create trigger trg_season_runs_updated_at
before update on public.season_runs
for each row execute function public.touch_updated_at();

drop trigger if exists trg_tile_events_updated_at on public.tile_events;
create trigger trg_tile_events_updated_at
before update on public.tile_events
for each row execute function public.touch_updated_at();

drop trigger if exists trg_season_tile_scores_updated_at on public.season_tile_scores;
create trigger trg_season_tile_scores_updated_at
before update on public.season_tile_scores
for each row execute function public.touch_updated_at();

drop trigger if exists trg_season_user_scores_updated_at on public.season_user_scores;
create trigger trg_season_user_scores_updated_at
before update on public.season_user_scores
for each row execute function public.touch_updated_at();

drop trigger if exists trg_season_rewards_updated_at on public.season_rewards;
create trigger trg_season_rewards_updated_at
before update on public.season_rewards
for each row execute function public.touch_updated_at();

insert into public.season_runs (
  season_key,
  period_type,
  week_start,
  week_end,
  status,
  settlement_delay_hours,
  scoring_policy_key,
  new_tile_score,
  hold_tile_daily_score,
  hold_tile_daily_cap,
  decay_grace_hours,
  decay_per_day,
  tier_threshold_bronze,
  tier_threshold_silver,
  tier_threshold_gold,
  tier_threshold_platinum,
  metadata
)
values (
  'weekly_' || to_char(date_trunc('week', now())::date, 'YYYYMMDD'),
  'weekly',
  date_trunc('week', now())::date,
  (date_trunc('week', now())::date + 7),
  'active',
  2,
  'season_weekly_stage1_v1',
  5,
  1,
  1,
  48,
  2,
  80,
  180,
  320,
  520,
  jsonb_build_object('seed', 'stage2_v1')
)
on conflict (period_type, week_start) do nothing;

create or replace function public.season_resolve_tier(
  score_value double precision,
  bronze_threshold integer,
  silver_threshold integer,
  gold_threshold integer,
  platinum_threshold integer
)
returns text
language sql
immutable
as $$
  select case
    when score_value >= platinum_threshold then 'platinum'
    when score_value >= gold_threshold then 'gold'
    when score_value >= silver_threshold then 'silver'
    when score_value >= bronze_threshold then 'bronze'
    else 'none'
  end;
$$;

create or replace function public.rpc_ingest_season_tile_events(
  target_walk_session_id uuid,
  now_ts timestamptz default now()
)
returns table (
  season_id uuid,
  season_key text,
  ingested_rows integer,
  tile_rows integer,
  user_total_score double precision,
  user_rank integer,
  run_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  session_owner uuid;
  session_started_at timestamptz;
  requester_uid uuid;
  requester_role text;
  run_row public.season_runs%rowtype;
  v_week_start date;
  v_now_ts timestamptz := coalesce(now_ts, now());
  v_ingested_rows integer := 0;
  v_tile_rows integer := 0;
  v_active_tile_count integer := 0;
  v_new_tile_capture_count integer := 0;
  v_raw_score double precision := 0;
  v_total_decay double precision := 0;
  v_total_score double precision := 0;
  v_last_contribution_at timestamptz := null;
  v_user_rank integer := null;
  v_user_tier text := 'none';
begin
  if target_walk_session_id is null then
    return;
  end if;

  select ws.owner_user_id, ws.started_at
  into session_owner, session_started_at
  from public.walk_sessions ws
  where ws.id = target_walk_session_id
  limit 1;

  if session_owner is null then
    return;
  end if;

  requester_uid := auth.uid();
  requester_role := auth.role();

  if requester_role <> 'service_role' then
    if requester_uid is null or requester_uid <> session_owner then
      raise exception 'permission denied for walk session %', target_walk_session_id;
    end if;
  end if;

  v_week_start := date_trunc('week', session_started_at at time zone 'utc')::date;

  insert into public.season_runs (
    season_key,
    period_type,
    week_start,
    week_end,
    status,
    settlement_delay_hours,
    scoring_policy_key,
    new_tile_score,
    hold_tile_daily_score,
    hold_tile_daily_cap,
    decay_grace_hours,
    decay_per_day,
    tier_threshold_bronze,
    tier_threshold_silver,
    tier_threshold_gold,
    tier_threshold_platinum,
    metadata
  )
  values (
    'weekly_' || to_char(v_week_start, 'YYYYMMDD'),
    'weekly',
    v_week_start,
    (v_week_start + 7),
    case
      when v_now_ts < (v_week_start + 7) then 'active'
      else 'settling'
    end,
    2,
    'season_weekly_stage1_v1',
    5,
    1,
    1,
    48,
    2,
    80,
    180,
    320,
    520,
    jsonb_build_object('source', 'rpc_ingest_season_tile_events')
  )
  on conflict (period_type, week_start) do update
  set updated_at = excluded.updated_at
  returning * into run_row;

  if run_row.status = 'settled'
     and v_now_ts > run_row.week_end + make_interval(hours => run_row.settlement_delay_hours) then
    v_week_start := date_trunc('week', v_now_ts at time zone 'utc')::date;

    insert into public.season_runs (
      season_key,
      period_type,
      week_start,
      week_end,
      status,
      settlement_delay_hours,
      scoring_policy_key,
      new_tile_score,
      hold_tile_daily_score,
      hold_tile_daily_cap,
      decay_grace_hours,
      decay_per_day,
      tier_threshold_bronze,
      tier_threshold_silver,
      tier_threshold_gold,
      tier_threshold_platinum,
      metadata
    )
    values (
      'weekly_' || to_char(v_week_start, 'YYYYMMDD'),
      'weekly',
      v_week_start,
      (v_week_start + 7),
      'active',
      2,
      'season_weekly_stage1_v1',
      5,
      1,
      1,
      48,
      2,
      80,
      180,
      320,
      520,
      jsonb_build_object('source', 'late_upload_rollover')
    )
    on conflict (period_type, week_start) do update
    set updated_at = excluded.updated_at
    returning * into run_row;
  end if;

  perform public.rpc_score_walk_session_anti_farming(target_walk_session_id, v_now_ts);

  insert into public.tile_events (
    season_id,
    owner_user_id,
    tile_id,
    event_day,
    event_kind,
    score_delta,
    source_walk_session_id,
    source_seq_no,
    source_recorded_at,
    payload,
    created_at,
    updated_at
  )
  with grouped as (
    select
      se.geotile as tile_id,
      (se.recorded_at at time zone 'utc')::date as event_day,
      bool_or(se.is_first_tile_hit) as had_capture,
      min(se.seq_no) as source_seq_no,
      max(se.recorded_at) as source_recorded_at,
      count(*) as point_count
    from public.season_tile_score_events se
    where se.walk_session_id = target_walk_session_id
    group by se.geotile, (se.recorded_at at time zone 'utc')::date
  )
  select
    run_row.id,
    session_owner,
    g.tile_id,
    g.event_day,
    case when g.had_capture then 'capture' else 'hold' end,
    case
      when g.had_capture then run_row.new_tile_score
      else least(run_row.hold_tile_daily_cap, 1) * run_row.hold_tile_daily_score
    end,
    target_walk_session_id,
    g.source_seq_no,
    g.source_recorded_at,
    jsonb_build_object(
      'point_count', g.point_count,
      'policy_key', run_row.scoring_policy_key,
      'source', 'season_tile_score_events'
    ),
    v_now_ts,
    v_now_ts
  from grouped g
  on conflict (season_id, owner_user_id, tile_id, event_day)
  do update
  set event_kind = case
        when excluded.event_kind = 'capture' then 'capture'
        else public.tile_events.event_kind
      end,
      score_delta = greatest(public.tile_events.score_delta, excluded.score_delta),
      source_walk_session_id = excluded.source_walk_session_id,
      source_seq_no = least(public.tile_events.source_seq_no, excluded.source_seq_no),
      source_recorded_at = greatest(public.tile_events.source_recorded_at, excluded.source_recorded_at),
      payload = public.tile_events.payload || excluded.payload,
      updated_at = v_now_ts;

  get diagnostics v_ingested_rows = row_count;

  insert into public.season_tile_scores (
    season_id,
    owner_user_id,
    tile_id,
    raw_score,
    decay_penalty,
    effective_score,
    first_captured_at,
    last_contribution_at,
    created_at,
    updated_at
  )
  with aggregated as (
    select
      te.season_id,
      te.owner_user_id,
      te.tile_id,
      sum(te.score_delta)::double precision as raw_score,
      min(te.source_recorded_at) as first_captured_at,
      max(te.source_recorded_at) as last_contribution_at
    from public.tile_events te
    where te.season_id = run_row.id
      and te.owner_user_id = session_owner
    group by te.season_id, te.owner_user_id, te.tile_id
  )
  select
    a.season_id,
    a.owner_user_id,
    a.tile_id,
    a.raw_score,
    0,
    a.raw_score,
    a.first_captured_at,
    a.last_contribution_at,
    v_now_ts,
    v_now_ts
  from aggregated a
  on conflict (season_id, owner_user_id, tile_id)
  do update
  set raw_score = excluded.raw_score,
      first_captured_at = excluded.first_captured_at,
      last_contribution_at = excluded.last_contribution_at,
      updated_at = v_now_ts;

  get diagnostics v_tile_rows = row_count;

  delete from public.season_tile_scores sts
  where sts.season_id = run_row.id
    and sts.owner_user_id = session_owner
    and not exists (
      select 1
      from public.tile_events te
      where te.season_id = sts.season_id
        and te.owner_user_id = sts.owner_user_id
        and te.tile_id = sts.tile_id
    );

  update public.season_tile_scores sts
  set decay_penalty = (
        case
          when sts.last_contribution_at is null then 0
          when v_now_ts <= sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours) then 0
          else (floor(extract(epoch from (v_now_ts - (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)))) / 86400)::double precision + 1) * run_row.decay_per_day
        end
      ),
      effective_score = greatest(
        0,
        sts.raw_score - (
          case
            when sts.last_contribution_at is null then 0
            when v_now_ts <= sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours) then 0
            else (floor(extract(epoch from (v_now_ts - (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)))) / 86400)::double precision + 1) * run_row.decay_per_day
          end
        )
      ),
      updated_at = v_now_ts
  where sts.season_id = run_row.id
    and sts.owner_user_id = session_owner;

  select
    count(*) filter (where sts.effective_score > 0)::integer,
    coalesce(sum(sts.raw_score), 0::double precision),
    coalesce(sum(sts.raw_score - sts.effective_score), 0::double precision),
    coalesce(sum(sts.effective_score), 0::double precision),
    max(sts.last_contribution_at)
  into
    v_active_tile_count,
    v_raw_score,
    v_total_decay,
    v_total_score,
    v_last_contribution_at
  from public.season_tile_scores sts
  where sts.season_id = run_row.id
    and sts.owner_user_id = session_owner;

  select count(distinct te.tile_id)::integer
  into v_new_tile_capture_count
  from public.tile_events te
  where te.season_id = run_row.id
    and te.owner_user_id = session_owner
    and te.event_kind = 'capture';

  v_user_tier := public.season_resolve_tier(
    v_total_score,
    run_row.tier_threshold_bronze,
    run_row.tier_threshold_silver,
    run_row.tier_threshold_gold,
    run_row.tier_threshold_platinum
  );

  insert into public.season_user_scores (
    season_id,
    owner_user_id,
    active_tile_count,
    new_tile_capture_count,
    raw_score,
    total_decay,
    total_score,
    tier,
    last_contribution_at,
    score_updated_at,
    created_at,
    updated_at
  )
  values (
    run_row.id,
    session_owner,
    coalesce(v_active_tile_count, 0),
    coalesce(v_new_tile_capture_count, 0),
    coalesce(v_raw_score, 0),
    coalesce(v_total_decay, 0),
    coalesce(v_total_score, 0),
    v_user_tier,
    v_last_contribution_at,
    v_now_ts,
    v_now_ts,
    v_now_ts
  )
  on conflict (season_id, owner_user_id)
  do update
  set active_tile_count = excluded.active_tile_count,
      new_tile_capture_count = excluded.new_tile_capture_count,
      raw_score = excluded.raw_score,
      total_decay = excluded.total_decay,
      total_score = excluded.total_score,
      tier = excluded.tier,
      last_contribution_at = excluded.last_contribution_at,
      score_updated_at = excluded.score_updated_at,
      updated_at = v_now_ts;

  with ranked as (
    select
      sus.owner_user_id,
      row_number() over (
        order by
          sus.total_score desc,
          sus.active_tile_count desc,
          sus.new_tile_capture_count desc,
          sus.last_contribution_at asc nulls last,
          sus.owner_user_id asc
      )::integer as next_rank
    from public.season_user_scores sus
    where sus.season_id = run_row.id
  )
  update public.season_user_scores sus
  set rank_position = r.next_rank,
      updated_at = v_now_ts
  from ranked r
  where sus.season_id = run_row.id
    and sus.owner_user_id = r.owner_user_id;

  select sus.rank_position, sus.total_score
  into v_user_rank, v_total_score
  from public.season_user_scores sus
  where sus.season_id = run_row.id
    and sus.owner_user_id = session_owner
  limit 1;

  if run_row.status <> 'settled' then
    update public.season_runs
    set status = case
      when v_now_ts < run_row.week_end then 'active'
      else 'settling'
    end,
    updated_at = v_now_ts
    where id = run_row.id
    returning * into run_row;
  end if;

  return query
  select
    run_row.id,
    run_row.season_key,
    v_ingested_rows,
    v_tile_rows,
    coalesce(v_total_score, 0),
    v_user_rank,
    run_row.status;
end;
$$;

create or replace function public.rpc_apply_season_daily_decay(
  target_season_id uuid default null,
  now_ts timestamptz default now()
)
returns table (
  season_id uuid,
  season_key text,
  updated_tile_rows integer,
  updated_user_rows integer,
  run_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_role text;
  run_row public.season_runs%rowtype;
  v_now_ts timestamptz := coalesce(now_ts, now());
  v_tile_rows integer := 0;
  v_user_rows integer := 0;
begin
  requester_role := auth.role();
  if requester_role <> 'service_role' then
    raise exception 'permission denied: service role required';
  end if;

  for run_row in
    select *
    from public.season_runs sr
    where (target_season_id is null or sr.id = target_season_id)
      and sr.status <> 'settled'
    order by sr.week_start asc
  loop
    update public.season_runs
    set status = case
          when v_now_ts < run_row.week_end then 'active'
          else 'settling'
        end,
        last_decay_run_at = v_now_ts,
        updated_at = v_now_ts
    where id = run_row.id
    returning * into run_row;

    update public.season_tile_scores sts
    set decay_penalty = (
          case
            when sts.last_contribution_at is null then 0
            when v_now_ts <= sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours) then 0
            else (floor(extract(epoch from (v_now_ts - (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)))) / 86400)::double precision + 1) * run_row.decay_per_day
          end
        ),
        effective_score = greatest(
          0,
          sts.raw_score - (
            case
              when sts.last_contribution_at is null then 0
              when v_now_ts <= sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours) then 0
              else (floor(extract(epoch from (v_now_ts - (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)))) / 86400)::double precision + 1) * run_row.decay_per_day
            end
          )
        ),
        updated_at = v_now_ts
    where sts.season_id = run_row.id;

    get diagnostics v_tile_rows = row_count;

    insert into public.season_user_scores (
      season_id,
      owner_user_id,
      active_tile_count,
      new_tile_capture_count,
      raw_score,
      total_decay,
      total_score,
      tier,
      last_contribution_at,
      score_updated_at,
      created_at,
      updated_at
    )
    with tile_rollup as (
      select
        sts.season_id,
        sts.owner_user_id,
        count(*) filter (where sts.effective_score > 0)::integer as active_tile_count,
        coalesce(sum(sts.raw_score), 0::double precision) as raw_score,
        coalesce(sum(sts.raw_score - sts.effective_score), 0::double precision) as total_decay,
        coalesce(sum(sts.effective_score), 0::double precision) as total_score,
        max(sts.last_contribution_at) as last_contribution_at
      from public.season_tile_scores sts
      where sts.season_id = run_row.id
      group by sts.season_id, sts.owner_user_id
    ),
    capture_rollup as (
      select
        te.season_id,
        te.owner_user_id,
        count(distinct te.tile_id)::integer as new_tile_capture_count
      from public.tile_events te
      where te.season_id = run_row.id
        and te.event_kind = 'capture'
      group by te.season_id, te.owner_user_id
    )
    select
      tr.season_id,
      tr.owner_user_id,
      tr.active_tile_count,
      coalesce(cr.new_tile_capture_count, 0),
      tr.raw_score,
      tr.total_decay,
      tr.total_score,
      public.season_resolve_tier(
        tr.total_score,
        run_row.tier_threshold_bronze,
        run_row.tier_threshold_silver,
        run_row.tier_threshold_gold,
        run_row.tier_threshold_platinum
      ),
      tr.last_contribution_at,
      v_now_ts,
      v_now_ts,
      v_now_ts
    from tile_rollup tr
    left join capture_rollup cr
      on cr.season_id = tr.season_id
     and cr.owner_user_id = tr.owner_user_id
    on conflict (season_id, owner_user_id)
    do update
    set active_tile_count = excluded.active_tile_count,
        new_tile_capture_count = excluded.new_tile_capture_count,
        raw_score = excluded.raw_score,
        total_decay = excluded.total_decay,
        total_score = excluded.total_score,
        tier = excluded.tier,
        last_contribution_at = excluded.last_contribution_at,
        score_updated_at = excluded.score_updated_at,
        updated_at = v_now_ts;

    get diagnostics v_user_rows = row_count;

    delete from public.season_user_scores sus
    where sus.season_id = run_row.id
      and not exists (
        select 1
        from public.season_tile_scores sts
        where sts.season_id = sus.season_id
          and sts.owner_user_id = sus.owner_user_id
      );

    with ranked as (
      select
        sus.owner_user_id,
        row_number() over (
          order by
            sus.total_score desc,
            sus.active_tile_count desc,
            sus.new_tile_capture_count desc,
            sus.last_contribution_at asc nulls last,
            sus.owner_user_id asc
        )::integer as next_rank
      from public.season_user_scores sus
      where sus.season_id = run_row.id
    )
    update public.season_user_scores sus
    set rank_position = r.next_rank,
        updated_at = v_now_ts
    from ranked r
    where sus.season_id = run_row.id
      and sus.owner_user_id = r.owner_user_id;

    return query
    select
      run_row.id,
      run_row.season_key,
      v_tile_rows,
      v_user_rows,
      run_row.status;
  end loop;
end;
$$;

create or replace function public.rpc_finalize_season(
  target_season_id uuid,
  now_ts timestamptz default now()
)
returns table (
  season_id uuid,
  season_key text,
  finalized boolean,
  reward_issued_count integer,
  settled_user_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_role text;
  run_row public.season_runs%rowtype;
  v_now_ts timestamptz := coalesce(now_ts, now());
  v_reward_count integer := 0;
  v_settled_user_count integer := 0;
begin
  requester_role := auth.role();
  if requester_role <> 'service_role' then
    raise exception 'permission denied: service role required';
  end if;

  if target_season_id is null then
    raise exception 'target_season_id is required';
  end if;

  select *
  into run_row
  from public.season_runs sr
  where sr.id = target_season_id
  limit 1;

  if run_row.id is null then
    raise exception 'season run not found: %', target_season_id;
  end if;

  if v_now_ts < run_row.week_end + make_interval(hours => run_row.settlement_delay_hours) then
    raise exception 'season settlement window not reached for %', run_row.season_key;
  end if;

  perform public.rpc_apply_season_daily_decay(run_row.id, v_now_ts);

  insert into public.season_rewards (
    season_id,
    owner_user_id,
    reward_code,
    tier,
    reward_payload,
    source_total_score,
    source_rank_position,
    issued_at,
    created_at,
    updated_at
  )
  select
    run_row.id,
    sus.owner_user_id,
    format('season_%s_%s_badge', to_char(run_row.week_start, 'YYYYMMDD'), lower(sus.tier)),
    sus.tier,
    jsonb_build_object(
      'season_key', run_row.season_key,
      'week_start', run_row.week_start,
      'week_end', run_row.week_end,
      'tier', sus.tier,
      'rank_position', sus.rank_position,
      'total_score', sus.total_score
    ),
    sus.total_score,
    sus.rank_position,
    v_now_ts,
    v_now_ts,
    v_now_ts
  from public.season_user_scores sus
  where sus.season_id = run_row.id
    and sus.tier <> 'none'
  on conflict (season_id, owner_user_id, reward_code) do nothing;

  get diagnostics v_reward_count = row_count;

  select count(*)::integer
  into v_settled_user_count
  from public.season_user_scores sus
  where sus.season_id = run_row.id;

  update public.season_runs
  set status = 'settled',
      finalized_at = coalesce(finalized_at, v_now_ts),
      last_settlement_run_at = v_now_ts,
      updated_at = v_now_ts
  where id = run_row.id
  returning * into run_row;

  return query
  select run_row.id, run_row.season_key, true, v_reward_count, v_settled_user_count;
end;
$$;

create or replace function public.rpc_get_season_leaderboard(
  target_season_id uuid default null,
  top_n integer default 50
)
returns table (
  season_id uuid,
  season_key text,
  rank_position integer,
  user_key text,
  total_score double precision,
  active_tile_count integer,
  new_tile_capture_count integer,
  tier text,
  is_me boolean,
  last_contribution_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  run_row public.season_runs%rowtype;
  limited_top_n integer := greatest(1, least(coalesce(top_n, 50), 200));
begin
  requester_uid := auth.uid();

  if target_season_id is not null then
    select *
    into run_row
    from public.season_runs sr
    where sr.id = target_season_id
    limit 1;
  else
    select *
    into run_row
    from public.season_runs sr
    order by
      case sr.status
        when 'active' then 1
        when 'settling' then 2
        else 3
      end,
      sr.week_start desc
    limit 1;
  end if;

  if run_row.id is null then
    return;
  end if;

  return query
  select
    run_row.id,
    run_row.season_key,
    sus.rank_position,
    md5(sus.owner_user_id::text) as user_key,
    sus.total_score,
    sus.active_tile_count,
    sus.new_tile_capture_count,
    sus.tier,
    (requester_uid is not null and sus.owner_user_id = requester_uid) as is_me,
    sus.last_contribution_at
  from public.season_user_scores sus
  where sus.season_id = run_row.id
  order by sus.rank_position asc nulls last
  limit limited_top_n;
end;
$$;

create or replace view public.view_season_batch_status_14d as
select
  sr.id as season_id,
  sr.season_key,
  sr.status,
  sr.last_decay_run_at,
  sr.last_settlement_run_at,
  sr.finalized_at,
  count(distinct te.owner_user_id)::bigint as participant_count,
  coalesce(sum(sus.total_score), 0::double precision) as leaderboard_total_score,
  count(distinct case when r.id is not null then r.owner_user_id end)::bigint as rewarded_user_count
from public.season_runs sr
left join public.tile_events te on te.season_id = sr.id
left join public.season_user_scores sus on sus.season_id = sr.id
left join public.season_rewards r on r.season_id = sr.id
where sr.week_start >= (date_trunc('week', now())::date - 14)
group by sr.id, sr.season_key, sr.status, sr.last_decay_run_at, sr.last_settlement_run_at, sr.finalized_at
order by sr.week_start desc;

grant select on public.season_runs to anon, authenticated;
grant select on public.tile_events to authenticated;
grant select on public.season_tile_scores to authenticated;
grant select on public.season_user_scores to authenticated;
grant select on public.season_rewards to authenticated;
grant execute on function public.rpc_ingest_season_tile_events(uuid, timestamptz) to authenticated, service_role;
grant execute on function public.rpc_apply_season_daily_decay(uuid, timestamptz) to service_role;
grant execute on function public.rpc_finalize_season(uuid, timestamptz) to service_role;
grant execute on function public.rpc_get_season_leaderboard(uuid, integer) to anon, authenticated, service_role;
grant select on public.view_season_batch_status_14d to authenticated, service_role;
