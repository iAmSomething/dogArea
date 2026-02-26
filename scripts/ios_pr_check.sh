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
swift scripts/release_regression_checklist_unit_check.swift
swift scripts/fault_injection_matrix_unit_check.swift
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
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "[dogArea] building watchOS target"
xcodebuild \
  -skipPackagePluginValidation \
  -project dogArea.xcodeproj \
  -scheme "dogAreaWatch Watch App" \
  -configuration Debug \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO \
  build
