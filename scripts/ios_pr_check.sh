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
swift scripts/userdefault_setting_second_split_unit_check.swift
swift scripts/map_motion_pack_unit_check.swift
swift scripts/quest_motion_pack_unit_check.swift
swift scripts/quest_stage1_policy_unit_check.swift
swift scripts/quest_stage2_engine_unit_check.swift
swift scripts/season_motion_pack_unit_check.swift
swift scripts/release_regression_checklist_unit_check.swift
swift scripts/game_layer_observability_qa_unit_check.swift
swift scripts/game_layer_kpi_dashboard_unit_check.swift
swift scripts/fault_injection_matrix_unit_check.swift
swift scripts/realtime_ops_rollout_unit_check.swift
swift scripts/realtime_ops_rollout_gate.swift --input docs/realtime-ops-kpi-sample-pass.json
swift scripts/supabase_ops_hardening_unit_check.swift
swift scripts/supabase_integration_harness_unit_check.swift
swift scripts/backend_contract_versioning_unit_check.swift
swift scripts/backend_edge_observability_unit_check.swift
swift scripts/backend_edge_failure_dashboard_unit_check.swift
swift scripts/backend_edge_auth_unification_unit_check.swift
swift scripts/backend_edge_auth_inventory_unit_check.swift
swift scripts/backend_edge_secret_inventory_unit_check.swift
swift scripts/backend_edge_rpc_deploy_matrix_unit_check.swift
swift scripts/backend_legacy_fallback_sunset_unit_check.swift
swift scripts/backend_edge_shared_utility_module_unit_check.swift
swift scripts/backend_deploy_rollback_runbook_unit_check.swift
swift scripts/backend_realtime_moderation_retention_policy_unit_check.swift
swift scripts/backend_storage_upload_layer_unit_check.swift
swift scripts/upload_profile_image_owner_binding_policy_unit_check.swift
swift scripts/backend_request_id_idempotency_unit_check.swift
swift scripts/backend_scheduler_ops_unit_check.swift
swift scripts/backend_geo_fixture_lifecycle_unit_check.swift
swift scripts/widget_summary_rpc_response_model_unit_check.swift
swift scripts/widget_lock_screen_accessory_plan_unit_check.swift
swift scripts/walk_widget_action_state_model_unit_check.swift
swift scripts/walk_widget_pet_context_policy_unit_check.swift
swift scripts/territory_widget_goal_deeplink_unit_check.swift
swift scripts/territory_widget_next_goal_summary_unit_check.swift
swift scripts/quest_rival_widget_next_action_recovery_unit_check.swift
swift scripts/backend_migration_drift_rpc_contract_unit_check.swift
swift scripts/sync_walk_stage_handler_split_unit_check.swift
swift scripts/nearby_presence_handler_split_unit_check.swift
swift scripts/rival_privacy_policy_stage1_unit_check.swift
swift scripts/rival_privacy_policy_confirmed_unit_check.swift
swift scripts/rival_privacy_hard_guard_unit_check.swift
swift scripts/rival_observability_metrics_unit_check.swift
swift scripts/rival_location_services_threading_unit_check.swift
swift scripts/rival_league_matching_unit_check.swift
swift scripts/rival_stage2_backend_unit_check.swift
swift scripts/rival_stage3_client_ux_unit_check.swift
swift scripts/rival_auth_session_guard_unit_check.swift
swift scripts/rival_auth_session_sync_unit_check.swift
swift scripts/rival_cllocation_delegate_preconcurrency_unit_check.swift
swift scripts/rival_mainactor_callback_unit_check.swift
swift scripts/rival_viewmodel_support_split_unit_check.swift
swift scripts/season_anti_farming_unit_check.swift
swift scripts/season_comeback_catchup_unit_check.swift
swift scripts/season_stage2_pipeline_unit_check.swift
swift scripts/season_stage3_ui_unit_check.swift
swift scripts/widget_extension_split_unit_check.swift
swift scripts/territory_status_widget_unit_check.swift
swift scripts/hotspot_widget_privacy_unit_check.swift
swift scripts/hotspot_widget_radius_preset_unit_check.swift
swift scripts/season_policy_stage1_unit_check.swift
swift scripts/weather_risk_policy_stage1_unit_check.swift
swift scripts/weather_snapshot_provider_unit_check.swift
swift scripts/home_refresh_entrypoint_unit_check.swift
swift scripts/home_mission_pet_context_snapshot_unit_check.swift
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
swift scripts/auth_refresh_resilience_unit_check.swift
swift scripts/auth_onboarding_session_consistency_unit_check.swift
swift scripts/auth_signup_entry_ux_unit_check.swift
swift scripts/auth_signup_validation_unit_check.swift
swift scripts/auth_rate_limit_message_unit_check.swift
swift scripts/auth_mail_resend_state_machine_unit_check.swift
swift scripts/auth_captcha_fallback_ux_unit_check.swift
swift scripts/auth_smtp_provider_checklist_unit_check.swift
swift scripts/auth_mail_observability_unit_check.swift
swift scripts/signin_metal_overlay_guard_unit_check.swift
swift scripts/auth_overlay_widget_action_defer_unit_check.swift
swift scripts/auth_reauth_session_downgrade_unit_check.swift
swift scripts/auth_flow_session_snapshot_unit_check.swift
swift scripts/auth_flow_session_observer_unit_check.swift
swift scripts/auth_flow_coordinator_sheet_split_unit_check.swift
swift scripts/auth_http_401_session_invalidation_unit_check.swift
swift scripts/auth_401_refresh_retry_unit_check.swift
swift scripts/auth_edge_function_anon_retry_unit_check.swift
swift scripts/rival_rpc_param_compat_unit_check.swift
swift scripts/feature_flag_refresh_throttle_unit_check.swift
swift scripts/feature_flag_refresh_singleflight_unit_check.swift
swift scripts/security_key_exposure_unit_check.swift
swift scripts/map_home_viewmodel_boundary_unit_check.swift
swift scripts/tabbar_safearea_regression_unit_check.swift
swift scripts/root_view_supporting_type_split_unit_check.swift
swift scripts/home_presentation_split_unit_check.swift
swift scripts/home_card_row_rendering_split_unit_check.swift
swift scripts/home_viewmodel_support_split_unit_check.swift
swift scripts/home_viewmodel_state_aggregation_split_unit_check.swift
swift scripts/map_camera_jump_fix_unit_check.swift
swift scripts/walk_return_to_origin_suggestion_unit_check.swift
swift scripts/map_area_calculation_service_unit_check.swift
swift scripts/map_chrome_hierarchy_unit_check.swift
swift scripts/map_custom_alert_redesign_unit_check.swift
swift scripts/map_bottom_controls_hit_testing_unit_check.swift
swift scripts/map_log_unreachable_cleanup_unit_check.swift
swift scripts/map_append_walk_point_discardable_unit_check.swift
swift scripts/map_viewmodel_widget_watch_support_split_unit_check.swift
swift scripts/supabase_infrastructure_service_split_unit_check.swift
swift scripts/map_auth_session_sync_unit_check.swift
swift scripts/watch_context_update_gate_unit_check.swift
swift scripts/watch_legacy_string_path_cleanup_unit_check.swift
swift scripts/corelocation_trace_debug_gate_unit_check.swift
swift scripts/corelocation_trace_idle_log_suppression_unit_check.swift
swift scripts/corelocation_trace_heartbeat_autostop_unit_check.swift
swift scripts/live_presence_uplink_policy_unit_check.swift
swift scripts/sync_walk_404_policy_unit_check.swift
swift scripts/feature_control_404_cooldown_unit_check.swift
swift scripts/home_guest_upgrade_retry_cta_unit_check.swift
swift scripts/home_weather_status_card_restore_unit_check.swift
swift scripts/home_weather_detail_card_unit_check.swift
swift scripts/home_area_milestone_feedback_unit_check.swift
swift scripts/home_goal_tracker_ui_unit_check.swift
swift scripts/area_reference_db_ui_unit_check.swift
swift scripts/territory_goal_detail_ui_unit_check.swift
swift scripts/profile_edit_flow_unit_check.swift
swift scripts/settings_pet_management_unit_check.swift
swift scripts/settings_profile_account_actions_unit_check.swift
swift scripts/settings_product_surface_unit_check.swift
swift scripts/settings_image_entry_affordance_unit_check.swift
swift scripts/home_mission_lifecycle_ux_unit_check.swift
swift scripts/settings_auth_session_sync_unit_check.swift
swift scripts/profile_edit_userinfo_recovery_unit_check.swift
swift scripts/settings_viewmodel_split_unit_check.swift
swift scripts/ui_regression_matrix_unit_check.swift
swift scripts/ui_copy_sweep_map_home_unit_check.swift
swift scripts/custom_alert_present_state_unit_check.swift
swift scripts/custom_alert_auth_state_unit_check.swift
swift scripts/custom_alert_mainactor_unit_check.swift
swift scripts/custom_alert_unused_type_cleanup_unit_check.swift
swift scripts/alert_model_height_overload_cleanup_unit_check.swift
swift scripts/ios_pr_check_derived_data_path_unit_check.swift
swift scripts/ios_pr_check_skip_watch_build_unit_check.swift
swift scripts/project_stability_unit_check.swift
swift scripts/ux_copy_guideline_unit_check.swift

if [[ "${DOGAREA_SKIP_BUILD:-0}" == "1" ]]; then
  echo "[dogArea] DOGAREA_SKIP_BUILD=1, skipping xcodebuild"
  exit 0
fi

RUN_STAMP="$(date +%s)"
DERIVED_DATA_PATH="${DOGAREA_DERIVED_DATA_PATH:-$ROOT_DIR/.build/ios_pr_check_derived_data_${RUN_STAMP}_$$}"
mkdir -p "$DERIVED_DATA_PATH"
echo "[dogArea] using DerivedData path: $DERIVED_DATA_PATH"

echo "[dogArea] building iOS target"
xcodebuild \
  -skipPackagePluginValidation \
  -project dogArea.xcodeproj \
  -scheme dogArea \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ "${DOGAREA_SKIP_WATCH_BUILD:-0}" == "1" ]]; then
  echo "[dogArea] DOGAREA_SKIP_WATCH_BUILD=1, skipping watchOS xcodebuild"
  exit 0
fi

echo "[dogArea] building watchOS target"
xcodebuild \
  -skipPackagePluginValidation \
  -project dogArea.xcodeproj \
  -scheme "dogAreaWatch Watch App" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=watchOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build
