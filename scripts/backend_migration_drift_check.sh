#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_check() {
  local target="$1"
  local check="$2"
  shift 2

  echo "[backend-drift] RUN target=${target} check=${check}"
  if "$@"; then
    echo "[backend-drift] PASS target=${target} check=${check}"
    return 0
  fi

  local exit_code=$?
  echo "[backend-drift] FAIL target=${target} check=${check} exit=${exit_code}"
  return "$exit_code"
}

run_check "migration-drift" "static-manifest" \
  swift scripts/backend_migration_drift_rpc_contract_unit_check.swift
run_check "rival-leaderboard+widget-quest-rival" "rpc-compat" \
  swift scripts/rival_rpc_param_compat_unit_check.swift
run_check "sync-walk" "404-fallback-policy" \
  swift scripts/sync_walk_404_policy_unit_check.swift
run_check "widget-territory" "rpc-contract" \
  swift scripts/territory_status_widget_unit_check.swift
run_check "widget-hotspot" "rpc-contract" \
  swift scripts/hotspot_widget_privacy_unit_check.swift
run_check "quest-engine" "rpc-contract" \
  swift scripts/quest_stage2_engine_unit_check.swift
run_check "feature-control" "availability-cooldown" \
  swift scripts/feature_control_404_cooldown_unit_check.swift
