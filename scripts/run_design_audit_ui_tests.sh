#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
OUTPUT_DIR="${DESIGN_AUDIT_OUTPUT_DIR:-$PROJECT_ROOT/DesignAuditShots}"
TEST_EMAIL="${DOGAREA_TEST_EMAIL:-}"
TEST_PASSWORD="${DOGAREA_TEST_PASSWORD:-}"
CREDENTIALS_FILE="$PROJECT_ROOT/.design_audit_credentials.json"

cleanup() {
  rm -f "$CREDENTIALS_FILE"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

echo "[DesignAudit] Output: $OUTPUT_DIR"
echo "[DesignAudit] Destination: $DESTINATION"
if [[ -n "$TEST_EMAIL" && -n "$TEST_PASSWORD" ]]; then
  echo "[DesignAudit] Test credentials: provided"
  cat > "$CREDENTIALS_FILE" <<EOF
{"email":"$TEST_EMAIL","password":"$TEST_PASSWORD"}
EOF
  chmod 600 "$CREDENTIALS_FILE"
else
  echo "[DesignAudit] Test credentials: not provided (guest flow only)"
fi

run_ui_test() {
  local test_case="${1:-}"
  if [[ -z "$test_case" ]]; then
    echo "[DesignAudit] Missing test case name"
    return 1
  fi
  DESIGN_AUDIT_OUTPUT_DIR="$OUTPUT_DIR" \
  xcodebuild -scheme dogArea \
    -destination "$DESTINATION" \
    "-only-testing:dogAreaUITests/DesignAuditUITests/$test_case" \
    test
}

echo "[DesignAudit] Running Light mode"
run_ui_test "testDesignAudit_LightMode"

echo "[DesignAudit] Running Dark mode"
run_ui_test "testDesignAudit_DarkMode"

echo "[DesignAudit] Done"
