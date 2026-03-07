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

sync_profile_snapshot_member="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/sync-profile" \
  "$SUPABASE_ANON_KEY" \
  "$member_auth" \
  '{"action":"get_profile_snapshot"}')"
harness_expect_status "sync-profile.snapshot.member" "200" "$sync_profile_snapshot_member" "route=/functions/v1/sync-profile action=get_profile_snapshot"

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
  "{\"action\":\"sync_walk_stage\",\"stage\":\"session\",\"walk_session_id\":\"$fixed_session_id\",\"idempotency_key\":\"smoke-416-session\",\"payload\":{\"created_at\":1700000000,\"started_at\":1700000000,\"ended_at\":1700000600,\"duration_sec\":600,\"area_m2\":12.5,\"source_device\":\"ios-smoke\"}}")"
harness_expect_status "sync-walk.session.member" "200" "$sync_walk_stage_member" "route=/functions/v1/sync-walk action=sync_walk_stage"

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

nearby_hotspots_app_policy="$(harness_request_json \
  "POST" \
  "$SUPABASE_URL/functions/v1/nearby-presence" \
  "$SUPABASE_ANON_KEY" \
  "$anon_auth" \
  "{\"action\":\"get_hotspots\",\"userId\":\"$HARNESS_MEMBER_USER_ID\",\"centerLat\":37.42199,\"centerLng\":126.68327,\"radiusKm\":1.0}")"
harness_expect_not_status "nearby-presence.hotspots.app_policy" "401" "$nearby_hotspots_app_policy" "route=/functions/v1/nearby-presence action=get_hotspots"

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

harness_finish
