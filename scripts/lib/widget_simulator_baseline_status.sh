#!/usr/bin/env bash
set -euo pipefail

widget_simulator_baseline_dir() {
  printf '%s' "${DOGAREA_WIDGET_SIM_BASELINE_DIR:-.codex_tmp/widget-simulator-baseline}"
}

widget_simulator_baseline_path() {
  local suite="${1:?suite is required}"
  printf '%s/%s.status' "$(widget_simulator_baseline_dir)" "$suite"
}

write_widget_simulator_baseline_status() {
  local suite="${1:?suite is required}"
  local status="${2:?status is required}"
  local destination="${3:-n/a}"
  local command_line="${4:-n/a}"
  local status_path

  status_path="$(widget_simulator_baseline_path "$suite")"
  mkdir -p "$(dirname "$status_path")"

  cat > "$status_path" <<EOF
suite=$suite
status=$status
ran_at_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
destination=$destination
command=$command_line
EOF
}
