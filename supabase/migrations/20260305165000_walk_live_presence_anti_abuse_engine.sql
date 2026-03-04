-- #241 live presence anti-abuse engine (speed/jump/rate/repeat + sanction)

create table if not exists public.live_presence_abuse_policies (
  policy_key text primary key,
  max_speed_mps double precision not null default 16.0 check (max_speed_mps >= 3 and max_speed_mps <= 60),
  max_jump_meters double precision not null default 250.0 check (max_jump_meters >= 20 and max_jump_meters <= 5000),
  jump_window_seconds integer not null default 12 check (jump_window_seconds between 1 and 120),
  min_update_interval_seconds integer not null default 2 check (min_update_interval_seconds between 1 and 60),
  user_max_updates_per_minute integer not null default 60 check (user_max_updates_per_minute between 5 and 600),
  device_max_updates_per_minute integer not null default 45 check (device_max_updates_per_minute between 5 and 600),
  repeat_window_seconds integer not null default 8 check (repeat_window_seconds between 1 and 60),
  repeat_distance_meters double precision not null default 4 check (repeat_distance_meters >= 0 and repeat_distance_meters <= 100),
  repeat_streak_threshold integer not null default 4 check (repeat_streak_threshold between 2 and 20),
  points_speed integer not null default 2 check (points_speed between 0 and 20),
  points_jump integer not null default 3 check (points_jump between 0 and 20),
  points_rate integer not null default 2 check (points_rate between 0 and 20),
  points_repeat integer not null default 1 check (points_repeat between 0 and 20),
  score_decay_per_hour double precision not null default 0.50 check (score_decay_per_hour >= 0 and score_decay_per_hour <= 20),
  score_threshold_warn double precision not null default 3.0 check (score_threshold_warn >= 0),
  score_threshold_restrict double precision not null default 6.0 check (score_threshold_restrict >= 0),
  score_threshold_block double precision not null default 10.0 check (score_threshold_block >= 0),
  restrict_cooldown_minutes integer not null default 10 check (restrict_cooldown_minutes between 1 and 1440),
  block_cooldown_minutes integer not null default 60 check (block_cooldown_minutes between 1 and 10080),
  updated_at timestamptz not null default now()
);

insert into public.live_presence_abuse_policies (
  policy_key,
  max_speed_mps,
  max_jump_meters,
  jump_window_seconds,
  min_update_interval_seconds,
  user_max_updates_per_minute,
  device_max_updates_per_minute,
  repeat_window_seconds,
  repeat_distance_meters,
  repeat_streak_threshold,
  points_speed,
  points_jump,
  points_rate,
  points_repeat,
  score_decay_per_hour,
  score_threshold_warn,
  score_threshold_restrict,
  score_threshold_block,
  restrict_cooldown_minutes,
  block_cooldown_minutes
)
values (
  'walk_live_presence',
  16.0,
  250.0,
  12,
  2,
  60,
  45,
  8,
  4,
  4,
  2,
  3,
  2,
  1,
  0.50,
  3.0,
  6.0,
  10.0,
  10,
  60
)
on conflict (policy_key) do update
set
  max_speed_mps = excluded.max_speed_mps,
  max_jump_meters = excluded.max_jump_meters,
  jump_window_seconds = excluded.jump_window_seconds,
  min_update_interval_seconds = excluded.min_update_interval_seconds,
  user_max_updates_per_minute = excluded.user_max_updates_per_minute,
  device_max_updates_per_minute = excluded.device_max_updates_per_minute,
  repeat_window_seconds = excluded.repeat_window_seconds,
  repeat_distance_meters = excluded.repeat_distance_meters,
  repeat_streak_threshold = excluded.repeat_streak_threshold,
  points_speed = excluded.points_speed,
  points_jump = excluded.points_jump,
  points_rate = excluded.points_rate,
  points_repeat = excluded.points_repeat,
  score_decay_per_hour = excluded.score_decay_per_hour,
  score_threshold_warn = excluded.score_threshold_warn,
  score_threshold_restrict = excluded.score_threshold_restrict,
  score_threshold_block = excluded.score_threshold_block,
  restrict_cooldown_minutes = excluded.restrict_cooldown_minutes,
  block_cooldown_minutes = excluded.block_cooldown_minutes,
  updated_at = now();

create table if not exists public.live_presence_abuse_states (
  owner_user_id uuid primary key,
  last_lat_rounded double precision,
  last_lng_rounded double precision,
  last_updated_at timestamptz,
  last_sequence bigint,
  user_window_started_at timestamptz,
  user_window_count integer not null default 0,
  repeat_streak integer not null default 0,
  abuse_score double precision not null default 0,
  sanction_level text not null default 'none' check (sanction_level in ('none', 'warn', 'restrict', 'block')),
  sanction_until timestamptz,
  last_violation_reason text,
  last_device_key text,
  total_violations integer not null default 0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.live_presence_abuse_device_windows (
  device_key text primary key,
  window_started_at timestamptz not null,
  window_count integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.live_presence_abuse_events (
  id bigint generated always as identity primary key,
  owner_user_id uuid,
  device_key text,
  event_type text not null check (event_type in ('speed', 'jump', 'rate_user', 'rate_device', 'repeat', 'sanction')),
  severity text not null check (severity in ('info', 'warn', 'critical')),
  points integer not null default 0,
  sanction_level text,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_live_presence_abuse_states_updated
  on public.live_presence_abuse_states(updated_at desc);
create index if not exists idx_live_presence_abuse_states_sanction
  on public.live_presence_abuse_states(sanction_level, updated_at desc);
create index if not exists idx_live_presence_abuse_device_windows_updated
  on public.live_presence_abuse_device_windows(updated_at desc);
create index if not exists idx_live_presence_abuse_events_created
  on public.live_presence_abuse_events(created_at desc);
create index if not exists idx_live_presence_abuse_events_owner_created
  on public.live_presence_abuse_events(owner_user_id, created_at desc);
create index if not exists idx_live_presence_abuse_events_type_created
  on public.live_presence_abuse_events(event_type, created_at desc);

alter table public.live_presence_abuse_policies enable row level security;
alter table public.live_presence_abuse_states enable row level security;
alter table public.live_presence_abuse_device_windows enable row level security;
alter table public.live_presence_abuse_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_policies'
      and policyname = 'live_presence_abuse_policies_select_all'
  ) then
    create policy live_presence_abuse_policies_select_all
      on public.live_presence_abuse_policies
      for select
      to authenticated
      using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_states'
      and policyname = 'live_presence_abuse_states_owner_select'
  ) then
    create policy live_presence_abuse_states_owner_select
      on public.live_presence_abuse_states
      for select
      using (auth.role() = 'service_role' or auth.uid() = owner_user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_states'
      and policyname = 'live_presence_abuse_states_service_write'
  ) then
    create policy live_presence_abuse_states_service_write
      on public.live_presence_abuse_states
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_device_windows'
      and policyname = 'live_presence_abuse_device_windows_service_all'
  ) then
    create policy live_presence_abuse_device_windows_service_all
      on public.live_presence_abuse_device_windows
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_events'
      and policyname = 'live_presence_abuse_events_owner_select'
  ) then
    create policy live_presence_abuse_events_owner_select
      on public.live_presence_abuse_events
      for select
      using (auth.role() = 'service_role' or auth.uid() = owner_user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_presence_abuse_events'
      and policyname = 'live_presence_abuse_events_service_write'
  ) then
    create policy live_presence_abuse_events_service_write
      on public.live_presence_abuse_events
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

grant select on public.live_presence_abuse_policies to authenticated;
grant select on public.live_presence_abuse_states to authenticated;
grant select on public.live_presence_abuse_events to authenticated;
grant select, insert, update, delete on public.live_presence_abuse_states to service_role;
grant select, insert, update, delete on public.live_presence_abuse_device_windows to service_role;
grant select, insert, update, delete on public.live_presence_abuse_events to service_role;

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
  in_ttl_seconds integer default 90,
  in_device_key text default null
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
  write_applied boolean,
  abuse_reason text,
  abuse_score double precision,
  sanction_level text,
  sanction_until timestamptz
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
  effective_device_key text := coalesce(nullif(trim(in_device_key), ''), in_session_id::text);

  max_speed_mps double precision := 16.0;
  max_jump_meters double precision := 250.0;
  jump_window_seconds integer := 12;
  min_update_interval_seconds integer := 2;
  user_max_updates_per_minute integer := 60;
  device_max_updates_per_minute integer := 45;
  repeat_window_seconds integer := 8;
  repeat_distance_meters double precision := 4.0;
  repeat_streak_threshold integer := 4;
  points_speed integer := 2;
  points_jump integer := 3;
  points_rate integer := 2;
  points_repeat integer := 1;
  score_decay_per_hour double precision := 0.5;
  score_threshold_warn double precision := 3.0;
  score_threshold_restrict double precision := 6.0;
  score_threshold_block double precision := 10.0;
  restrict_cooldown_minutes integer := 10;
  block_cooldown_minutes integer := 60;

  state_row public.live_presence_abuse_states%rowtype;
  previous_state_exists boolean := false;

  user_window_started_at timestamptz;
  user_window_count integer := 0;
  device_window_started_at timestamptz;
  device_window_count integer := 0;

  previous_distance_meters double precision := 0;
  previous_delta_seconds double precision := 0;
  repeat_streak integer := 0;

  violation_speed boolean := false;
  violation_jump boolean := false;
  violation_rate_user boolean := false;
  violation_rate_device boolean := false;
  violation_repeat boolean := false;
  violation_points integer := 0;

  previous_sanction_level text := 'none';
  previous_sanction_until timestamptz := null;
  decayed_score double precision := 0;
  next_score double precision := 0;
  next_sanction_level text := 'none';
  next_sanction_until timestamptz := null;

  should_drop boolean := false;
  decided_reason text := null;
  severity_text text := 'info';

  upsert_affected_count integer := 0;
  persisted_row public.walk_live_presence%rowtype;

  next_last_lat double precision;
  next_last_lng double precision;
  next_last_updated_at timestamptz;
  next_last_sequence bigint;
  next_total_violations integer;
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

  select
    p.max_speed_mps,
    p.max_jump_meters,
    p.jump_window_seconds,
    p.min_update_interval_seconds,
    p.user_max_updates_per_minute,
    p.device_max_updates_per_minute,
    p.repeat_window_seconds,
    p.repeat_distance_meters,
    p.repeat_streak_threshold,
    p.points_speed,
    p.points_jump,
    p.points_rate,
    p.points_repeat,
    p.score_decay_per_hour,
    p.score_threshold_warn,
    p.score_threshold_restrict,
    p.score_threshold_block,
    p.restrict_cooldown_minutes,
    p.block_cooldown_minutes
  into
    max_speed_mps,
    max_jump_meters,
    jump_window_seconds,
    min_update_interval_seconds,
    user_max_updates_per_minute,
    device_max_updates_per_minute,
    repeat_window_seconds,
    repeat_distance_meters,
    repeat_streak_threshold,
    points_speed,
    points_jump,
    points_rate,
    points_repeat,
    score_decay_per_hour,
    score_threshold_warn,
    score_threshold_restrict,
    score_threshold_block,
    restrict_cooldown_minutes,
    block_cooldown_minutes
  from public.live_presence_abuse_policies p
  where p.policy_key = 'walk_live_presence'
  limit 1;

  select *
  into state_row
  from public.live_presence_abuse_states
  where owner_user_id = in_owner_user_id
  for update;

  previous_state_exists := found;

  if previous_state_exists then
    previous_sanction_level := coalesce(state_row.sanction_level, 'none');
    previous_sanction_until := state_row.sanction_until;
    decayed_score := greatest(
      0,
      coalesce(state_row.abuse_score, 0) - (
        greatest(0, extract(epoch from (effective_updated_at - coalesce(state_row.updated_at, effective_updated_at)))) / 3600.0
      ) * score_decay_per_hour
    );
    user_window_started_at := coalesce(state_row.user_window_started_at, effective_updated_at);
    user_window_count := greatest(0, coalesce(state_row.user_window_count, 0));
    repeat_streak := greatest(0, coalesce(state_row.repeat_streak, 0));

    if state_row.last_updated_at is not null then
      previous_delta_seconds := greatest(0, extract(epoch from (effective_updated_at - state_row.last_updated_at)));
    end if;

    if state_row.last_lat_rounded is not null and state_row.last_lng_rounded is not null then
      previous_distance_meters := sqrt(
        power((normalized_lat - state_row.last_lat_rounded) * 111320.0, 2) +
        power((normalized_lng - state_row.last_lng_rounded) * (111320.0 * greatest(0.2, abs(cos(radians(normalized_lat))))), 2)
      );
    end if;
  else
    decayed_score := 0;
    user_window_started_at := effective_updated_at;
    user_window_count := 0;
    repeat_streak := 0;
  end if;

  if effective_updated_at - user_window_started_at >= interval '60 seconds' then
    user_window_started_at := effective_updated_at;
    user_window_count := 1;
  else
    user_window_count := user_window_count + 1;
  end if;
  violation_rate_user := user_window_count > user_max_updates_per_minute;

  insert into public.live_presence_abuse_device_windows (
    device_key,
    window_started_at,
    window_count,
    updated_at
  )
  values (
    effective_device_key,
    effective_updated_at,
    0,
    effective_updated_at
  )
  on conflict (device_key) do nothing;

  select
    w.window_started_at,
    w.window_count
  into
    device_window_started_at,
    device_window_count
  from public.live_presence_abuse_device_windows w
  where w.device_key = effective_device_key
  for update;

  if effective_updated_at - device_window_started_at >= interval '60 seconds' then
    device_window_started_at := effective_updated_at;
    device_window_count := 1;
  else
    device_window_count := device_window_count + 1;
  end if;
  violation_rate_device := device_window_count > device_max_updates_per_minute;

  update public.live_presence_abuse_device_windows
  set
    window_started_at = device_window_started_at,
    window_count = device_window_count,
    updated_at = effective_updated_at
  where device_key = effective_device_key;

  violation_speed := in_speed_mps is not null and in_speed_mps > max_speed_mps;
  violation_jump := previous_state_exists
    and previous_delta_seconds > 0
    and previous_delta_seconds <= jump_window_seconds
    and previous_distance_meters > max_jump_meters;

  if previous_state_exists
    and previous_delta_seconds > 0
    and previous_delta_seconds <= repeat_window_seconds
    and previous_distance_meters <= repeat_distance_meters then
    repeat_streak := repeat_streak + 1;
  else
    repeat_streak := 0;
  end if;
  violation_repeat := repeat_streak >= repeat_streak_threshold;

  if violation_speed then
    violation_points := violation_points + points_speed;
  end if;
  if violation_jump then
    violation_points := violation_points + points_jump;
  end if;
  if violation_rate_user or violation_rate_device then
    violation_points := violation_points + points_rate;
  end if;
  if violation_repeat then
    violation_points := violation_points + points_repeat;
  end if;

  next_score := decayed_score + violation_points;

  if previous_sanction_until is not null
    and previous_sanction_until > effective_updated_at
    and previous_sanction_level in ('restrict', 'block') then
    next_sanction_level := previous_sanction_level;
    next_sanction_until := previous_sanction_until;
  else
    if next_score >= score_threshold_block then
      next_sanction_level := 'block';
      next_sanction_until := effective_updated_at + make_interval(mins => block_cooldown_minutes);
    elsif next_score >= score_threshold_restrict then
      next_sanction_level := 'restrict';
      next_sanction_until := effective_updated_at + make_interval(mins => restrict_cooldown_minutes);
    elsif next_score >= score_threshold_warn then
      next_sanction_level := 'warn';
      next_sanction_until := null;
    else
      next_sanction_level := 'none';
      next_sanction_until := null;
    end if;
  end if;

  if next_sanction_level = 'block' then
    should_drop := true;
    decided_reason := 'blocked';
  elsif violation_speed then
    should_drop := true;
    decided_reason := 'speed';
  elsif violation_jump then
    should_drop := true;
    decided_reason := 'jump';
  elsif violation_rate_device then
    should_drop := true;
    decided_reason := 'rate_device';
  elsif violation_rate_user then
    should_drop := true;
    decided_reason := 'rate_user';
  elsif violation_repeat then
    should_drop := true;
    decided_reason := 'repeat';
  elsif next_sanction_level = 'restrict'
    and previous_delta_seconds > 0
    and previous_delta_seconds < (min_update_interval_seconds * 2) then
    should_drop := true;
    decided_reason := 'restricted';
  end if;

  if next_sanction_level = 'block' then
    severity_text := 'critical';
  elsif next_sanction_level = 'restrict' or violation_points > 0 then
    severity_text := 'warn';
  else
    severity_text := 'info';
  end if;

  next_last_lat := case
    when should_drop and previous_state_exists then state_row.last_lat_rounded
    else normalized_lat
  end;
  next_last_lng := case
    when should_drop and previous_state_exists then state_row.last_lng_rounded
    else normalized_lng
  end;
  next_last_updated_at := case
    when should_drop and previous_state_exists then state_row.last_updated_at
    else effective_updated_at
  end;
  next_last_sequence := case
    when should_drop and previous_state_exists then state_row.last_sequence
    else effective_sequence
  end;
  next_total_violations := coalesce(state_row.total_violations, 0) + case when violation_points > 0 then 1 else 0 end;

  insert into public.live_presence_abuse_states (
    owner_user_id,
    last_lat_rounded,
    last_lng_rounded,
    last_updated_at,
    last_sequence,
    user_window_started_at,
    user_window_count,
    repeat_streak,
    abuse_score,
    sanction_level,
    sanction_until,
    last_violation_reason,
    last_device_key,
    total_violations,
    updated_at
  )
  values (
    in_owner_user_id,
    next_last_lat,
    next_last_lng,
    next_last_updated_at,
    next_last_sequence,
    user_window_started_at,
    user_window_count,
    repeat_streak,
    next_score,
    next_sanction_level,
    next_sanction_until,
    decided_reason,
    effective_device_key,
    next_total_violations,
    effective_updated_at
  )
  on conflict (owner_user_id) do update
    set last_lat_rounded = excluded.last_lat_rounded,
        last_lng_rounded = excluded.last_lng_rounded,
        last_updated_at = excluded.last_updated_at,
        last_sequence = excluded.last_sequence,
        user_window_started_at = excluded.user_window_started_at,
        user_window_count = excluded.user_window_count,
        repeat_streak = excluded.repeat_streak,
        abuse_score = excluded.abuse_score,
        sanction_level = excluded.sanction_level,
        sanction_until = excluded.sanction_until,
        last_violation_reason = excluded.last_violation_reason,
        last_device_key = excluded.last_device_key,
        total_violations = excluded.total_violations,
        updated_at = excluded.updated_at;

  if violation_speed then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'speed',
      severity_text,
      points_speed,
      next_sanction_level,
      jsonb_build_object(
        'speed_mps', in_speed_mps,
        'max_speed_mps', max_speed_mps
      )
    );
  end if;

  if violation_jump then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'jump',
      severity_text,
      points_jump,
      next_sanction_level,
      jsonb_build_object(
        'distance_meters', previous_distance_meters,
        'max_jump_meters', max_jump_meters,
        'delta_seconds', previous_delta_seconds,
        'jump_window_seconds', jump_window_seconds
      )
    );
  end if;

  if violation_rate_user then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'rate_user',
      severity_text,
      points_rate,
      next_sanction_level,
      jsonb_build_object(
        'window_count', user_window_count,
        'limit_per_minute', user_max_updates_per_minute
      )
    );
  end if;

  if violation_rate_device then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'rate_device',
      severity_text,
      points_rate,
      next_sanction_level,
      jsonb_build_object(
        'window_count', device_window_count,
        'limit_per_minute', device_max_updates_per_minute
      )
    );
  end if;

  if violation_repeat then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'repeat',
      severity_text,
      points_repeat,
      next_sanction_level,
      jsonb_build_object(
        'repeat_streak', repeat_streak,
        'repeat_streak_threshold', repeat_streak_threshold,
        'repeat_distance_meters', repeat_distance_meters,
        'distance_meters', previous_distance_meters
      )
    );
  end if;

  if previous_sanction_level is distinct from next_sanction_level
    or previous_sanction_until is distinct from next_sanction_until then
    insert into public.live_presence_abuse_events (
      owner_user_id,
      device_key,
      event_type,
      severity,
      points,
      sanction_level,
      detail
    ) values (
      in_owner_user_id,
      effective_device_key,
      'sanction',
      case when next_sanction_level = 'block' then 'critical' when next_sanction_level = 'none' then 'info' else 'warn' end,
      0,
      next_sanction_level,
      jsonb_build_object(
        'previous_level', previous_sanction_level,
        'next_level', next_sanction_level,
        'previous_until', previous_sanction_until,
        'next_until', next_sanction_until,
        'score', next_score
      )
    );
  end if;

  if should_drop then
    if next_sanction_level = 'block' then
      delete from public.walk_live_presence
      where owner_user_id = in_owner_user_id;
    end if;

    select *
    into persisted_row
    from public.walk_live_presence
    where owner_user_id = in_owner_user_id;

    if found then
      return query
      select
        persisted_row.owner_user_id,
        persisted_row.session_id,
        persisted_row.lat_rounded,
        persisted_row.lng_rounded,
        persisted_row.geohash7,
        persisted_row.speed_mps,
        persisted_row.sequence,
        persisted_row.idempotency_key,
        persisted_row.updated_at,
        persisted_row.expires_at,
        false,
        decided_reason,
        next_score,
        next_sanction_level,
        next_sanction_until;
      return;
    end if;

    return query
    select
      in_owner_user_id,
      in_session_id,
      normalized_lat,
      normalized_lng,
      normalized_geohash,
      in_speed_mps,
      effective_sequence,
      effective_idempotency_key,
      effective_updated_at,
      effective_updated_at + make_interval(secs => effective_ttl_seconds),
      false,
      decided_reason,
      next_score,
      next_sanction_level,
      next_sanction_until;
    return;
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
  into upsert_affected_count
  from upserted;

  select *
  into persisted_row
  from public.walk_live_presence
  where owner_user_id = in_owner_user_id;

  return query
  select
    persisted_row.owner_user_id,
    persisted_row.session_id,
    persisted_row.lat_rounded,
    persisted_row.lng_rounded,
    persisted_row.geohash7,
    persisted_row.speed_mps,
    persisted_row.sequence,
    persisted_row.idempotency_key,
    persisted_row.updated_at,
    persisted_row.expires_at,
    upsert_affected_count > 0,
    null,
    next_score,
    next_sanction_level,
    next_sanction_until;
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
  integer,
  text
) to authenticated, service_role;

create or replace view public.view_live_presence_abuse_report_24h as
select
  date_trunc('hour', created_at) as hour_bucket,
  event_type,
  severity,
  count(*)::bigint as event_count,
  count(distinct owner_user_id)::bigint as affected_users,
  coalesce(sum(points), 0)::bigint as total_points
from public.live_presence_abuse_events
where created_at >= now() - interval '24 hours'
group by date_trunc('hour', created_at), event_type, severity
order by hour_bucket desc, event_count desc;

create or replace view public.view_live_presence_abuse_top_users_24h as
select
  owner_user_id,
  count(*)::bigint as event_count,
  coalesce(sum(points), 0)::bigint as total_points,
  max(created_at) as last_event_at
from public.live_presence_abuse_events
where created_at >= now() - interval '24 hours'
  and owner_user_id is not null
group by owner_user_id
order by total_points desc, event_count desc;

grant select on public.view_live_presence_abuse_report_24h to authenticated;
grant select on public.view_live_presence_abuse_top_users_24h to authenticated;
