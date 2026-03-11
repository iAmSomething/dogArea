#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/supabase_integration_harness.sh"

harness_load_env
harness_note "matrix start project_ref=${HARNESS_PROJECT_REF:-unknown} filter=${DOGAREA_SUPABASE_CASE_FILTER:-all}"

if harness_login_member; then
  login_response="$(printf '%s\n%s' "$HARNESS_LAST_LOGIN_STATUS" "$HARNESS_LAST_LOGIN_BODY")"
else
  login_response="$(printf '%s\n%s' "$HARNESS_LAST_LOGIN_STATUS" "$HARNESS_LAST_LOGIN_BODY")"
fi
harness_expect_status "auth.member_login" "200" "$login_response" "route=/auth/v1/token?grant_type=password"

if [[ "$HARNESS_LAST_LOGIN_STATUS" != "200" ]]; then
  harness_finish
  exit 1
fi

member_auth="Bearer $HARNESS_MEMBER_TOKEN"
anon_auth="Bearer $SUPABASE_ANON_KEY"
invalid_auth="Bearer invalid.integration.token"
now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fixed_session_id="${DOGAREA_SUPABASE_SMOKE_SESSION_ID:-00000000-0000-4000-8000-000000000416}"
foreign_user_id="${DOGAREA_SUPABASE_FOREIGN_USER_ID:-00000000-0000-4000-8000-000000000099}"
tiny_png_base64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+7zEAAAAASUVORK5CYII="
anon_upload_owner_id="anon-onboarding-smoke-${HARNESS_MEMBER_USER_ID:0:8}"

sync_profile_snapshot_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-profile" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"get_profile_snapshot"}')"
harness_expect_status "sync-profile.snapshot.member" "200" "$sync_profile_snapshot_member" "route=/functions/v1/sync-profile action=get_profile_snapshot"
member_snapshot_body="$(harness_response_body "$sync_profile_snapshot_member")"
member_pet_id="${DOGAREA_SUPABASE_SMOKE_PET_ID:-$(harness_json_field "$member_snapshot_body" "snapshot.pets.0.id")}"
member_pet_name="${DOGAREA_SUPABASE_SMOKE_PET_NAME:-$(harness_json_field "$member_snapshot_body" "snapshot.pets.0.name")}"
if [[ -z "$member_pet_id" ]]; then
  harness_note "FAIL fixture.member_pet_missing route=/functions/v1/sync-profile action=get_profile_snapshot body=no_pet_id_in_snapshot"
  exit 1
fi
if [[ -z "$member_pet_name" ]]; then
  member_pet_name="SmokePet"
fi

auth_user_member="$(harness_request_json \
  "GET" \
  "$SUPABASE_URL/auth/v1/user" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "")"
harness_expect_status "auth.user.member" "200" "$auth_user_member" "route=/auth/v1/user"

auth_refresh_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/auth/v1/token?grant_type=refresh_token" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"refresh_token\":\"$HARNESS_MEMBER_REFRESH_TOKEN\"}")"
harness_expect_status "auth.refresh.member" "200" "$auth_refresh_member" "route=/auth/v1/token?grant_type=refresh_token"

auth_resend_signup="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/auth/v1/resend" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"type\":\"signup\",\"email\":\"$DOGAREA_TEST_EMAIL\"}")"
harness_expect_status_in "auth.resend.signup.member_fixture" "200,429" "$auth_resend_signup" "route=/auth/v1/resend type=signup"

auth_recover_member_fixture="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/auth/v1/recover" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"email\":\"$DOGAREA_TEST_EMAIL\"}")"
harness_expect_status_in "auth.recover.member_fixture" "200,429" "$auth_recover_member_fixture" "route=/auth/v1/recover"

signup_email_availability_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_check_signup_email_availability" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"p_email\":\"$DOGAREA_TEST_EMAIL\"}")"
harness_expect_status "signup-email-availability.member" "200" "$signup_email_availability_member" "route=/rest/v1/rpc/rpc_check_signup_email_availability"

sync_profile_invalid_token="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-profile" \
  "$SUPABASE_ANON_KEY" \
  "$invalid_auth" \
  '{"action":"get_profile_snapshot"}')"
harness_expect_status "sync-profile.snapshot.invalid_token" "401" "$sync_profile_invalid_token" "route=/functions/v1/sync-profile action=get_profile_snapshot"

sync_profile_user_mismatch="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-profile" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"get_profile_snapshot\",\"user_id\":\"$foreign_user_id\"}")"
harness_expect_status "sync-profile.permission.user_mismatch" "403" "$sync_profile_user_mismatch" "route=/functions/v1/sync-profile action=get_profile_snapshot"

sync_walk_stage_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"sync_walk_stage\",\"stage\":\"session\",\"walk_session_id\":\"$fixed_session_id\",\"request_id\":\"smoke-426-sync-walk-session-request\",\"idempotency_key\":\"smoke-416-session\",\"payload\":{\"created_at\":1700000000,\"started_at\":1700000000,\"ended_at\":1700000600,\"duration_sec\":600,\"area_m2\":12.5,\"source_device\":\"ios\",\"pet_id\":\"$member_pet_id\"}}")"
harness_expect_status "sync-walk.session.member" "200" "$sync_walk_stage_member" "route=/functions/v1/sync-walk action=sync_walk_stage"

sync_walk_session_missing_pet="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"sync_walk_stage","stage":"session","walk_session_id":"00000000-0000-4000-8000-000000006861","request_id":"smoke-686-sync-walk-missing-pet","idempotency_key":"smoke-686-missing-pet","payload":{"created_at":1700000000,"started_at":1700000000,"ended_at":1700000600,"duration_sec":600,"area_m2":12.5,"source_device":"ios"}}')"
harness_expect_status "sync-walk.session.invalid_payload.missing_pet" "422" "$sync_walk_session_missing_pet" "route=/functions/v1/sync-walk action=sync_walk_stage"

sync_walk_session_invalid_pet="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"sync_walk_stage\",\"stage\":\"session\",\"walk_session_id\":\"00000000-0000-4000-8000-000000006862\",\"request_id\":\"smoke-686-sync-walk-invalid-pet\",\"idempotency_key\":\"smoke-686-invalid-pet\",\"payload\":{\"created_at\":1700000000,\"started_at\":1700000000,\"ended_at\":1700000600,\"duration_sec\":600,\"area_m2\":12.5,\"source_device\":\"ios\",\"pet_id\":\"00000000-0000-4000-8000-000000009999\"}}")"
harness_expect_status "sync-walk.session.invalid_payload.invalid_pet" "422" "$sync_walk_session_invalid_pet" "route=/functions/v1/sync-walk action=sync_walk_stage"

sync_walk_session_reverse_time="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"sync_walk_stage\",\"stage\":\"session\",\"walk_session_id\":\"00000000-0000-4000-8000-000000006864\",\"request_id\":\"smoke-687-sync-walk-reverse-time\",\"idempotency_key\":\"smoke-687-reverse-time\",\"payload\":{\"created_at\":1700000000,\"started_at\":1700000600,\"ended_at\":1700000000,\"duration_sec\":0,\"area_m2\":12.5,\"source_device\":\"ios\",\"pet_id\":\"$member_pet_id\"}}")"
harness_expect_status "sync-walk.session.invalid_payload.reverse_time" "422" "$sync_walk_session_reverse_time" "route=/functions/v1/sync-walk action=sync_walk_stage"

sync_walk_summary_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"get_backfill_summary\",\"session_ids\":[\"$fixed_session_id\"]}")"
harness_expect_status "sync-walk.summary.member" "200" "$sync_walk_summary_member" "route=/functions/v1/sync-walk action=get_backfill_summary"

sync_walk_invalid_token="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-walk" \
  "$SUPABASE_ANON_KEY" \
  "$invalid_auth" \
  '{"action":"get_backfill_summary","session_ids":[]}')"
harness_expect_status "sync-walk.summary.invalid_token" "401" "$sync_walk_invalid_token" "route=/functions/v1/sync-walk action=get_backfill_summary"

nearby_visibility_get_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/nearby-presence" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"get_visibility\",\"userId\":\"$HARNESS_MEMBER_USER_ID\"}")"
harness_expect_status "nearby-presence.visibility.get.member" "200" "$nearby_visibility_get_member" "route=/functions/v1/nearby-presence action=get_visibility"
current_visibility_enabled="$(harness_json_field "$(harness_response_body "$nearby_visibility_get_member")" "visibility.enabled")"
if [[ "$current_visibility_enabled" == "true" ]]; then
  visibility_json=true
else
  visibility_json=false
fi
nearby_visibility_set_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/nearby-presence" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"set_visibility\",\"userId\":\"$HARNESS_MEMBER_USER_ID\",\"enabled\":$visibility_json}")"
harness_expect_status "nearby-presence.visibility.set.member" "200" "$nearby_visibility_set_member" "route=/functions/v1/nearby-presence action=set_visibility"

nearby_hotspots_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/nearby-presence" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"action\":\"get_hotspots\",\"userId\":\"$HARNESS_MEMBER_USER_ID\",\"centerLat\":37.42199,\"centerLng\":126.68327,\"radiusKm\":1.0}")"
harness_expect_status "nearby-presence.hotspots.member" "200" "$nearby_hotspots_member" "route=/functions/v1/nearby-presence action=get_hotspots"

nearby_hotspots_app_policy="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/nearby-presence" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"action\":\"get_hotspots\",\"userId\":\"$HARNESS_MEMBER_USER_ID\",\"centerLat\":37.42199,\"centerLng\":126.68327,\"radiusKm\":1.0}")"
harness_expect_status "nearby-presence.hotspots.app_policy" "200" "$nearby_hotspots_app_policy" "route=/functions/v1/nearby-presence action=get_hotspots"

rival_league_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/rival-league" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"get_leaderboard","periodType":"week","topN":5}')"
harness_expect_status "rival-league.leaderboard.member" "200" "$rival_league_member" "route=/functions/v1/rival-league action=get_leaderboard"

rival_league_invalid_token="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/rival-league" \
  "$SUPABASE_ANON_KEY" \
  "$invalid_auth" \
  '{"action":"get_leaderboard","periodType":"week","topN":5}')"
harness_expect_status "rival-league.leaderboard.invalid_token" "401" "$rival_league_invalid_token" "route=/functions/v1/rival-league action=get_leaderboard"

rival_rpc_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_rival_leaderboard" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"period_type\":\"week\",\"top_n\":5,\"now_ts\":\"$now_ts\"}}")"
harness_expect_status "rival-rpc.compat.member" "200" "$rival_rpc_member" "route=/rest/v1/rpc/rpc_get_rival_leaderboard"

widget_territory_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_widget_territory_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "widget-territory.summary.member" "200" "$widget_territory_member" "route=/rest/v1/rpc/rpc_get_widget_territory_summary"

widget_hotspot_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_widget_hotspot_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_radius_km\":1.2,\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "widget-hotspot.summary.member" "200" "$widget_hotspot_member" "route=/rest/v1/rpc/rpc_get_widget_hotspot_summary"

widget_quest_rival_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_widget_quest_rival_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "widget-quest-rival.summary.member" "200" "$widget_quest_rival_member" "route=/rest/v1/rpc/rpc_get_widget_quest_rival_summary"

indoor_summary_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_indoor_mission_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_pet_context_id\":\"$member_pet_id\",\"in_pet_name\":\"$member_pet_name\",\"in_recent_daily_minutes\":15,\"in_average_weekly_walk_count\":4,\"in_base_risk_level\":\"severe\",\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "indoor-mission.summary.member" "200" "$indoor_summary_member" "route=/rest/v1/rpc/rpc_get_indoor_mission_summary"
indoor_summary_body="$(harness_response_body "$indoor_summary_member")"
indoor_mission_id="$(harness_json_field "$indoor_summary_body" "0.missions.0.missionInstanceId")"
indoor_day_key="$(harness_json_field "$indoor_summary_body" "0.day_key")"
indoor_pet_context_id="$(harness_json_field "$indoor_summary_body" "0.pet_context_id")"
if [[ -z "$indoor_mission_id" || -z "$indoor_day_key" ]]; then
  harness_note "FAIL indoor-mission.fixture_missing route=/rest/v1/rpc/rpc_get_indoor_mission_summary body=mission_instance_id_or_day_key_missing"
  exit 1
fi

indoor_action_request_id="$(harness_uuid)"
indoor_record_action_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_record_indoor_mission_action" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_mission_instance_id\":\"$indoor_mission_id\",\"in_request_id\":\"$indoor_action_request_id\",\"in_event_id\":\"$indoor_action_request_id\",\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "indoor-mission.record-action.member" "200" "$indoor_record_action_member" "route=/rest/v1/rpc/rpc_record_indoor_mission_action"

indoor_claim_request_id="$(harness_uuid)"
if [[ -n "$indoor_pet_context_id" ]]; then
  indoor_claim_payload="{\"payload\":{\"in_mission_instance_id\":\"$indoor_mission_id\",\"in_day_key\":\"$indoor_day_key\",\"in_pet_context_id\":\"$indoor_pet_context_id\",\"in_request_id\":\"$indoor_claim_request_id\",\"in_now_ts\":\"$now_ts\"}}"
else
  indoor_claim_payload="{\"payload\":{\"in_mission_instance_id\":\"$indoor_mission_id\",\"in_day_key\":\"$indoor_day_key\",\"in_request_id\":\"$indoor_claim_request_id\",\"in_now_ts\":\"$now_ts\"}}"
fi
indoor_claim_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_claim_indoor_mission_reward" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "$indoor_claim_payload")"
harness_expect_status "indoor-mission.claim.member" "200" "$indoor_claim_member" "route=/rest/v1/rpc/rpc_claim_indoor_mission_reward"

indoor_easy_day_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_activate_indoor_easy_day" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_pet_context_id\":\"$member_pet_id\",\"in_pet_name\":\"$member_pet_name\",\"in_recent_daily_minutes\":15,\"in_average_weekly_walk_count\":4,\"in_base_risk_level\":\"severe\",\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "indoor-mission.easy-day.member" "200" "$indoor_easy_day_member" "route=/rest/v1/rpc/rpc_activate_indoor_easy_day"

weather_summary_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_weather_replacement_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_base_risk_level\":\"moderate\",\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "weather.summary.member" "200" "$weather_summary_member" "route=/rest/v1/rpc/rpc_get_weather_replacement_summary"

weather_feedback_request_id="$(harness_uuid)"
weather_feedback_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_submit_weather_feedback" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_base_risk_level\":\"moderate\",\"in_request_id\":\"$weather_feedback_request_id\",\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "weather.feedback.member" "200" "$weather_feedback_member" "route=/rest/v1/rpc/rpc_submit_weather_feedback"

season_summary_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_get_owner_season_summary" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"payload\":{\"in_now_ts\":\"$now_ts\"}}")"
harness_expect_status "season.summary.member" "200" "$season_summary_member" "route=/rest/v1/rpc/rpc_get_owner_season_summary"
season_summary_body="$(harness_response_body "$season_summary_member")"
season_week_key="$(harness_json_field "$season_summary_body" "0.current_week_key")"
season_completed_id="$(harness_json_field "$season_summary_body" "0.latest_completed_season_id")"
if [[ -z "$season_week_key" ]]; then
  harness_note "FAIL season.fixture_missing route=/rest/v1/rpc/rpc_get_owner_season_summary body=current_week_key_missing"
  exit 1
fi
season_claim_request_id="$(harness_uuid)"
if [[ -n "$season_completed_id" ]]; then
  season_claim_payload="{\"payload\":{\"in_season_id\":\"$season_completed_id\",\"in_week_key\":\"$season_week_key\",\"in_request_id\":\"$season_claim_request_id\",\"in_now_ts\":\"$now_ts\",\"in_source\":\"ios\"}}"
else
  season_claim_payload="{\"payload\":{\"in_week_key\":\"$season_week_key\",\"in_request_id\":\"$season_claim_request_id\",\"in_now_ts\":\"$now_ts\",\"in_source\":\"ios\"}}"
fi
season_claim_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/rest/v1/rpc/rpc_claim_season_reward" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "$season_claim_payload")"
harness_expect_status "season.claim.member" "200" "$season_claim_member" "route=/rest/v1/rpc/rpc_claim_season_reward"

quest_engine_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/quest-engine" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"list_active"}')"
harness_expect_status "quest-engine.list_active.member" "200" "$quest_engine_member" "route=/functions/v1/quest-engine action=list_active"

quest_engine_invalid_token="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/quest-engine" \
  "$SUPABASE_ANON_KEY" \
  "$invalid_auth" \
  '{"action":"list_active"}')"
harness_expect_status "quest-engine.list_active.invalid_token" "401" "$quest_engine_invalid_token" "route=/functions/v1/quest-engine action=list_active"

feature_control_flags_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/feature-control" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"get_flags","keys":["ff_heatmap_v1","ff_nearby_hotspot_v1"]}')"
harness_expect_status "feature-control.flags.member" "200" "$feature_control_flags_member" "route=/functions/v1/feature-control action=get_flags"

feature_control_flags="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/feature-control" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  '{"action":"get_flags","keys":["ff_heatmap_v1","ff_nearby_hotspot_v1"]}')"
harness_expect_status "feature-control.flags.anon" "200" "$feature_control_flags" "route=/functions/v1/feature-control action=get_flags"

feature_control_kpis="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/feature-control" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  '{"action":"get_rollout_kpis"}')"
harness_expect_status "feature-control.rollout_kpis.anon" "200" "$feature_control_kpis" "route=/functions/v1/feature-control action=get_rollout_kpis"

caricature_invalid_request_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/caricature" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"version\":\"2026-02-26.v1\",\"petId\":\"$member_pet_id\",\"requestId\":\"$(harness_uuid)\"}")"
harness_expect_status "caricature.invalid_request.member" "400" "$caricature_invalid_request_member" "route=/functions/v1/caricature invalid-request"

upload_profile_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/upload-profile-image" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"ownerId\":\"$HARNESS_MEMBER_USER_ID\",\"imageBase64\":\"$tiny_png_base64\",\"imageKind\":\"user\"}")"
harness_expect_status "upload-profile-image.member" "200" "$upload_profile_member" "route=/functions/v1/upload-profile-image"

upload_profile_app="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/upload-profile-image" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"ownerId\":\"$anon_upload_owner_id\",\"imageBase64\":\"$tiny_png_base64\",\"imageKind\":\"user\"}")"
harness_expect_status "upload-profile-image.app_policy" "200" "$upload_profile_app" "route=/functions/v1/upload-profile-image"

upload_profile_member_mismatch="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/upload-profile-image" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  "{\"ownerId\":\"$anon_upload_owner_id\",\"imageBase64\":\"$tiny_png_base64\",\"imageKind\":\"user\"}")"
harness_expect_status "upload-profile-image.member_owner_mismatch" "403" "$upload_profile_member_mismatch" "route=/functions/v1/upload-profile-image"

harness_finish
