#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[PRFastSmoke][FS-004] watch baseline contract checks"
swift scripts/watch_control_info_surface_split_unit_check.swift
swift scripts/watch_control_surface_density_unit_check.swift
swift scripts/watch_action_feedback_ux_unit_check.swift
swift scripts/watch_addpoint_haptic_policy_unit_check.swift
swift scripts/watch_walk_end_summary_ux_unit_check.swift

echo "[PRFastSmoke][FS-004] Done"
echo "[PRFastSmoke][FS-004] Manual device confirmation remains a release/nightly evidence task when watch surface is impacted"
