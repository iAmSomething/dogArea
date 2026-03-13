#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/widget_simulator_baseline_status.sh"

BASELINE_STATUS="fail"
BASELINE_COMMAND="bash scripts/run_pr_fast_smoke_widget_layout_checks.sh"
BASELINE_COVERAGE="WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008"

record_baseline_status() {
  write_widget_simulator_baseline_status \
    "layout-fast-smoke" \
    "$BASELINE_STATUS" \
    "static-checks" \
    "$BASELINE_COMMAND" \
    "$BASELINE_COVERAGE"
}

trap record_baseline_status EXIT

echo "[PRFastSmoke][FS-002] widget family / clipping checks"
swift scripts/widget_lock_screen_accessory_plan_unit_check.swift
swift scripts/walk_control_widget_family_layout_unit_check.swift
swift scripts/home_widget_family_layout_budget_unit_check.swift
swift scripts/widget_state_cta_taxonomy_unit_check.swift

BASELINE_STATUS="pass"
echo "[PRFastSmoke][FS-002] Done"
