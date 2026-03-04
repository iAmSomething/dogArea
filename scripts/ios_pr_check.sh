#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ensure_file_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
  fi
}

ensure_file_if_missing "OpenAIConfiguration.xcconfig" "OPENAI_API_KEY="
ensure_file_if_missing "supabase/supabaseConfig.xcconfig" "SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
PROJECT_REF=
STORAGE_BUCKETS=
AUTH_REDIRECT_URL=
DB_CONN_STRING=
EXISTING_SCHEMA="

echo "[dogArea] running document/unit checks"
swift scripts/swift_stability_unit_check.swift
swift scripts/userdefault_store_split_unit_check.swift
swift scripts/map_motion_pack_unit_check.swift
swift scripts/quest_motion_pack_unit_check.swift
swift scripts/quest_stage1_policy_unit_check.swift
swift scripts/quest_stage2_engine_unit_check.swift
swift scripts/season_motion_pack_unit_check.swift
swift scripts/release_regression_checklist_unit_check.swift
swift scripts/game_layer_observability_qa_unit_check.swift
swift scripts/game_layer_kpi_dashboard_unit_check.swift
swift scripts/fault_injection_matrix_unit_check.swift
swift scripts/supabase_ops_hardening_unit_check.swift
swift scripts/rival_privacy_policy_stage1_unit_check.swift
swift scripts/rival_privacy_hard_guard_unit_check.swift
swift scripts/rival_observability_metrics_unit_check.swift
swift scripts/rival_location_services_threading_unit_check.swift
swift scripts/rival_league_matching_unit_check.swift
swift scripts/rival_stage2_backend_unit_check.swift
swift scripts/rival_stage3_client_ux_unit_check.swift
swift scripts/rival_auth_session_guard_unit_check.swift
swift scripts/season_anti_farming_unit_check.swift
swift scripts/season_comeback_catchup_unit_check.swift
swift scripts/season_stage2_pipeline_unit_check.swift
swift scripts/season_stage3_ui_unit_check.swift
swift scripts/territory_status_widget_unit_check.swift
swift scripts/hotspot_widget_privacy_unit_check.swift
swift scripts/season_policy_stage1_unit_check.swift
swift scripts/weather_risk_policy_stage1_unit_check.swift
swift scripts/weather_stage2_engine_unit_check.swift
swift scripts/weather_ux_stage3_unit_check.swift
swift scripts/weather_feedback_loop_unit_check.swift
swift scripts/quest_failure_buffer_unit_check.swift
swift scripts/pet_adaptive_quest_unit_check.swift
swift scripts/pet_context_badge_empty_state_unit_check.swift
swift scripts/area_reference_db_ui_unit_check.swift
swift scripts/walk_repository_contract_unit_check.swift
swift scripts/walk_repository_backfill_unit_check.swift
swift scripts/walk_session_pet_canonicalization_unit_check.swift
swift scripts/presentation_firebase_boundary_unit_check.swift
swift scripts/supabase_profile_image_upload_unit_check.swift
swift scripts/auth_session_autologin_unit_check.swift
swift scripts/auth_onboarding_session_consistency_unit_check.swift
swift scripts/auth_signup_entry_ux_unit_check.swift
swift scripts/security_key_exposure_unit_check.swift
swift scripts/map_home_viewmodel_boundary_unit_check.swift
swift scripts/tabbar_safearea_regression_unit_check.swift
swift scripts/map_camera_jump_fix_unit_check.swift
swift scripts/map_area_calculation_service_unit_check.swift
swift scripts/sync_walk_404_policy_unit_check.swift
swift scripts/home_guest_upgrade_retry_cta_unit_check.swift
swift scripts/settings_profile_account_actions_unit_check.swift
swift scripts/profile_edit_userinfo_recovery_unit_check.swift
swift scripts/project_stability_unit_check.swift

if [[ "${DOGAREA_SKIP_BUILD:-0}" == "1" ]]; then
  echo "[dogArea] DOGAREA_SKIP_BUILD=1, skipping xcodebuild"
  exit 0
fi

echo "[dogArea] building iOS target"
xcodebuild \
  -skipPackagePluginValidation \
  -project dogArea.xcodeproj \
  -scheme dogArea \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "[dogArea] building watchOS target"
xcodebuild \
  -skipPackagePluginValidation \
  -project dogArea.xcodeproj \
  -scheme "dogAreaWatch Watch App" \
  -configuration Debug \
  -destination "generic/platform=watchOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build
