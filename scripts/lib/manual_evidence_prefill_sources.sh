#!/usr/bin/env bash
set -euo pipefail

MANUAL_EVIDENCE_PREFILL_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

manual_evidence_trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

widget_prefill_autodetect_disabled() {
  [[ "${DOGAREA_DISABLE_WIDGET_PREFILL_AUTODETECT:-0}" == "1" ]]
}

widget_prefill_date() {
  printf '%s' "${DOGAREA_WIDGET_EVIDENCE_DATE:-$(date '+%F')}"
}

widget_prefill_tester() {
  printf '%s' "${DOGAREA_WIDGET_EVIDENCE_TESTER:-${USER:-codex}}"
}

widget_prefill_connected_device_os_autodetect() {
  command -v xcrun >/dev/null 2>&1 || return
  command -v jq >/dev/null 2>&1 || return

  local device_json
  device_json="$(xcrun xcdevice list 2>/dev/null || true)"
  [[ -n "$device_json" ]] || return

  printf '%s' "$device_json" | jq -r '
    [ .[]
      | select(.simulator == false)
      | select(.available == true)
      | select(.platform == "com.apple.platform.iphoneos")
    ][0]
    | if . == null then
        empty
      else
        "\(.modelName) / iOS \(.operatingSystemVersion | split(" ")[0])"
      end
  '
}

widget_prefill_app_build_autodetect() {
  command -v xcodebuild >/dev/null 2>&1 || return

  local settings marketing current
  settings="$(xcodebuild -project "$MANUAL_EVIDENCE_PREFILL_ROOT_DIR/dogArea.xcodeproj" -scheme dogArea -showBuildSettings 2>/dev/null || true)"
  [[ -n "$settings" ]] || return

  marketing="$(printf '%s\n' "$settings" | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')"
  current="$(printf '%s\n' "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = / { print $2; exit }')"
  marketing="$(manual_evidence_trim "$marketing")"
  current="$(manual_evidence_trim "$current")"

  if [[ -n "$marketing" && -n "$current" ]]; then
    printf '%s (%s)' "$marketing" "$current"
  elif [[ -n "$marketing" ]]; then
    printf '%s' "$marketing"
  elif [[ -n "$current" ]]; then
    printf '%s' "$current"
  fi
}

widget_prefill_ensure_device_os_cache() {
  local detected
  if [[ -n "${__DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE:-}" ]]; then
    return
  fi

  if [[ -n "$(manual_evidence_trim "${DOGAREA_WIDGET_EVIDENCE_DEVICE_OS:-}")" ]]; then
    __DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE="env"
    __DOGAREA_WIDGET_PREFILL_DEVICE_OS_VALUE_CACHE="${DOGAREA_WIDGET_EVIDENCE_DEVICE_OS}"
    return
  fi

  if [[ -n "$(manual_evidence_trim "${DOGAREA_WIDGET_PREFILL_DEVICE_OS_STUB:-}")" ]]; then
    __DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE="stub"
    __DOGAREA_WIDGET_PREFILL_DEVICE_OS_VALUE_CACHE="${DOGAREA_WIDGET_PREFILL_DEVICE_OS_STUB}"
    return
  fi

  if ! widget_prefill_autodetect_disabled; then
    detected="$(manual_evidence_trim "$(widget_prefill_connected_device_os_autodetect)")"
    if [[ -n "$detected" ]]; then
      __DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE="connected-ios-device"
      __DOGAREA_WIDGET_PREFILL_DEVICE_OS_VALUE_CACHE="$detected"
      return
    fi
  fi

  __DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE="missing"
  __DOGAREA_WIDGET_PREFILL_DEVICE_OS_VALUE_CACHE=""
}

widget_prefill_device_os_source() {
  widget_prefill_ensure_device_os_cache
  printf '%s' "${__DOGAREA_WIDGET_PREFILL_DEVICE_OS_SOURCE_CACHE}"
}

widget_prefill_ensure_app_build_cache() {
  local detected
  if [[ -n "${__DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE:-}" ]]; then
    return
  fi

  if [[ -n "$(manual_evidence_trim "${DOGAREA_WIDGET_EVIDENCE_APP_BUILD:-}")" ]]; then
    __DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE="env"
    __DOGAREA_WIDGET_PREFILL_APP_BUILD_VALUE_CACHE="${DOGAREA_WIDGET_EVIDENCE_APP_BUILD}"
    return
  fi

  if [[ -n "$(manual_evidence_trim "${DOGAREA_WIDGET_PREFILL_APP_BUILD_STUB:-}")" ]]; then
    __DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE="stub"
    __DOGAREA_WIDGET_PREFILL_APP_BUILD_VALUE_CACHE="${DOGAREA_WIDGET_PREFILL_APP_BUILD_STUB}"
    return
  fi

  if ! widget_prefill_autodetect_disabled; then
    detected="$(manual_evidence_trim "$(widget_prefill_app_build_autodetect)")"
    if [[ -n "$detected" ]]; then
      __DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE="xcodebuild-settings"
      __DOGAREA_WIDGET_PREFILL_APP_BUILD_VALUE_CACHE="$detected"
      return
    fi
  fi

  __DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE="missing"
  __DOGAREA_WIDGET_PREFILL_APP_BUILD_VALUE_CACHE=""
}

widget_prefill_app_build_source() {
  widget_prefill_ensure_app_build_cache
  printf '%s' "${__DOGAREA_WIDGET_PREFILL_APP_BUILD_SOURCE_CACHE}"
}

widget_prefill_device_os() {
  widget_prefill_ensure_device_os_cache
  printf '%s' "${__DOGAREA_WIDGET_PREFILL_DEVICE_OS_VALUE_CACHE}"
}

widget_prefill_app_build() {
  widget_prefill_ensure_app_build_cache
  printf '%s' "${__DOGAREA_WIDGET_PREFILL_APP_BUILD_VALUE_CACHE}"
}
