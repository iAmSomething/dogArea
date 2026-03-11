#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[PRFastSmoke][FS-002] widget family / clipping checks"
swift scripts/widget_lock_screen_accessory_plan_unit_check.swift
swift scripts/walk_control_widget_family_layout_unit_check.swift
swift scripts/home_widget_family_layout_budget_unit_check.swift
swift scripts/widget_state_cta_taxonomy_unit_check.swift

echo "[PRFastSmoke][FS-002] Done"
