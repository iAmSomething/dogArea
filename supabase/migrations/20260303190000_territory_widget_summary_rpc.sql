-- #217 territory status widget summary RPC (today/weekly/defense due)

create or replace function public.rpc_get_widget_territory_summary(
  now_ts timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid := auth.uid();
  run_row public.season_runs%rowtype;
  utc_today date := (now_ts at time zone 'utc')::date;
  today_tile_count integer := 0;
  weekly_tile_count integer := 0;
  defense_scheduled_tile_count integer := 0;
  score_updated_at timestamptz := null;
begin
  if requester_uid is null then
    return jsonb_build_object(
      'today_tile_count', null,
      'weekly_tile_count', null,
      'defense_scheduled_tile_count', null,
      'score_updated_at', null,
      'refreshed_at', now_ts,
      'has_data', false
    );
  end if;

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

  if run_row.id is null then
    return jsonb_build_object(
      'today_tile_count', 0,
      'weekly_tile_count', 0,
      'defense_scheduled_tile_count', 0,
      'score_updated_at', null,
      'refreshed_at', now_ts,
      'has_data', false
    );
  end if;

  select coalesce(count(distinct te.tile_id), 0)::integer
  into today_tile_count
  from public.tile_events te
  where te.season_id = run_row.id
    and te.owner_user_id = requester_uid
    and te.event_day = utc_today
    and te.event_kind = 'capture';

  select
    coalesce(sus.active_tile_count, 0)::integer,
    sus.score_updated_at
  into weekly_tile_count, score_updated_at
  from public.season_user_scores sus
  where sus.season_id = run_row.id
    and sus.owner_user_id = requester_uid
  limit 1;

  select coalesce(count(*), 0)::integer
  into defense_scheduled_tile_count
  from public.season_tile_scores sts
  where sts.season_id = run_row.id
    and sts.owner_user_id = requester_uid
    and sts.effective_score > 0
    and sts.last_contribution_at is not null
    and (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)) > now_ts
    and (sts.last_contribution_at + make_interval(hours => run_row.decay_grace_hours)) <= (now_ts + interval '24 hours');

  return jsonb_build_object(
    'today_tile_count', coalesce(today_tile_count, 0),
    'weekly_tile_count', coalesce(weekly_tile_count, 0),
    'defense_scheduled_tile_count', coalesce(defense_scheduled_tile_count, 0),
    'score_updated_at', score_updated_at,
    'refreshed_at', now_ts,
    'has_data', (coalesce(today_tile_count, 0) > 0 or coalesce(weekly_tile_count, 0) > 0)
  );
end;
$$;

grant execute on function public.rpc_get_widget_territory_summary(timestamptz) to authenticated, service_role;
