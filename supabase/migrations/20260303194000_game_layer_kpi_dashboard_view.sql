-- #247 game-layer 7d KPI dashboard view

create or replace view public.view_game_layer_kpis_7d as
with metrics_7d as (
  select
    event_name,
    coalesce(nullif(user_key, ''), nullif(app_instance_id, '')) as actor_key
  from public.app_metric_events
  where created_at >= now() - interval '7 days'
),
metrics_24h as (
  select event_name
  from public.app_metric_events
  where created_at >= now() - interval '24 hours'
),
agg_7d as (
  select
    count(*) filter (where event_name = 'quest_progress_applied')::double precision as quest_progress_applied_count,
    count(*) filter (where event_name = 'quest_reward_claimed')::double precision as quest_reward_claimed_count,
    count(*) filter (where event_name = 'quest_claim_duplicate_blocked')::double precision as quest_claim_duplicate_blocked_count,
    count(distinct actor_key) filter (
      where actor_key is not null and event_name = 'season_score_applied'
    )::double precision as season_participated_users,
    count(distinct actor_key) filter (
      where actor_key is not null and event_name in (
        'walk_save_success',
        'quest_progress_applied',
        'season_score_applied',
        'rival_leaderboard_fetched',
        'weather_replacement_applied'
      )
    )::double precision as game_layer_active_users,
    count(distinct actor_key) filter (
      where actor_key is not null and event_name = 'rival_privacy_opt_in_completed'
    )::double precision as rival_opt_in_users,
    count(distinct actor_key) filter (
      where actor_key is not null and event_name in (
        'rival_privacy_opt_in_completed',
        'rival_leaderboard_fetched',
        'rival_privacy_guard_blocked'
      )
    )::double precision as rival_touched_users,
    count(*) filter (where event_name = 'weather_replacement_applied')::double precision as weather_replacement_applied_count,
    count(*) filter (
      where event_name in ('weather_replacement_applied', 'weather_shield_consumed')
    )::double precision as weather_replacement_offer_count
  from metrics_7d
),
agg_24h as (
  select
    count(*) filter (where event_name = 'sync_auth_refresh_failed')::double precision as sync_auth_refresh_failed_count,
    count(*) filter (
      where event_name in ('sync_auth_refresh_failed', 'sync_auth_refresh_succeeded')
    )::double precision as sync_auth_refresh_total_count
  from metrics_24h
)
select
  now() as calculated_at,
  case
    when quest_progress_applied_count = 0 then null
    else quest_reward_claimed_count / nullif(quest_progress_applied_count, 0)
  end as quest_completion_rate_7d,
  case
    when (quest_reward_claimed_count + quest_claim_duplicate_blocked_count) = 0 then null
    else quest_claim_duplicate_blocked_count / nullif((quest_reward_claimed_count + quest_claim_duplicate_blocked_count), 0)
  end as quest_claim_duplicate_rate_7d,
  case
    when game_layer_active_users = 0 then null
    else season_participated_users / nullif(game_layer_active_users, 0)
  end as season_participation_rate_7d,
  case
    when rival_touched_users = 0 then null
    else rival_opt_in_users / nullif(rival_touched_users, 0)
  end as rival_opt_in_rate_7d,
  case
    when weather_replacement_offer_count = 0 then null
    else weather_replacement_applied_count / nullif(weather_replacement_offer_count, 0)
  end as weather_replacement_acceptance_rate_7d,
  case
    when sync_auth_refresh_total_count = 0 then null
    else sync_auth_refresh_failed_count / nullif(sync_auth_refresh_total_count, 0)
  end as sync_auth_refresh_failure_rate_24h,
  quest_progress_applied_count::bigint as quest_progress_applied_count,
  quest_reward_claimed_count::bigint as quest_reward_claimed_count,
  quest_claim_duplicate_blocked_count::bigint as quest_claim_duplicate_blocked_count,
  season_participated_users::bigint as season_participated_users,
  game_layer_active_users::bigint as game_layer_active_users,
  rival_opt_in_users::bigint as rival_opt_in_users,
  rival_touched_users::bigint as rival_touched_users,
  weather_replacement_applied_count::bigint as weather_replacement_applied_count,
  weather_replacement_offer_count::bigint as weather_replacement_offer_count,
  sync_auth_refresh_failed_count::bigint as sync_auth_refresh_failed_count,
  sync_auth_refresh_total_count::bigint as sync_auth_refresh_total_count
from agg_7d
cross join agg_24h;

grant select on public.view_game_layer_kpis_7d to anon, authenticated;
