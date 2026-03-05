#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17,OS=26.1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dogArea-rival-auth-revalidation}"
TEST_TARGET="dogAreaUITests/DesignAuditUITests/testFeatureRegression_RivalAuthRevalidationFlow"
LOG_DIR="${DOGAREA_REVALIDATION_LOG_DIR:-$PROJECT_ROOT/build/rival-auth-revalidation}"
MAX_ATTEMPTS="${DOGAREA_REVALIDATION_MAX_ATTEMPTS:-0}"
REQUIRE_HTTP_LOGS="${DOGAREA_REVALIDATION_REQUIRE_HTTP_LOGS:-0}"

mkdir -p "$LOG_DIR"

if [[ -z "${DOGAREA_TEST_EMAIL:-}" || -z "${DOGAREA_TEST_PASSWORD:-}" ]]; then
  echo "[RivalAuthRevalidation] DOGAREA_TEST_EMAIL / DOGAREA_TEST_PASSWORD 환경변수가 필요합니다."
  echo "[RivalAuthRevalidation] 예: DOGAREA_TEST_EMAIL='user@example.com' DOGAREA_TEST_PASSWORD='password' $0"
  exit 1
fi

cd "$PROJECT_ROOT"

CREDENTIALS_FILE="$PROJECT_ROOT/.design_audit_credentials.json"
cat > "$CREDENTIALS_FILE" <<EOF
{"email":"$DOGAREA_TEST_EMAIL","password":"$DOGAREA_TEST_PASSWORD"}
EOF
trap 'rm -f "$CREDENTIALS_FILE"' EXIT

echo "[RivalAuthRevalidation] Destination: $DESTINATION"
echo "[RivalAuthRevalidation] DerivedData: $DERIVED_DATA_PATH"
echo "[RivalAuthRevalidation] build-for-testing"
xcodebuild -scheme dogArea \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "$DESTINATION" \
  build-for-testing

attempt=1
while true; do
  timestamp="$(date +%Y%m%d-%H%M%S)"
  log_file="$LOG_DIR/attempt-${attempt}-${timestamp}.log"

  echo "[RivalAuthRevalidation] attempt=$attempt test-without-building"
  set +e
  DOGAREA_TEST_EMAIL="$DOGAREA_TEST_EMAIL" \
  DOGAREA_TEST_PASSWORD="$DOGAREA_TEST_PASSWORD" \
  xcodebuild -scheme dogArea \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "$DESTINATION" \
    "-only-testing:$TEST_TARGET" \
    test-without-building | tee "$log_file"
  test_status=${PIPESTATUS[0]}
  set -e

  token_200="0"
  nearby_200="0"
  if rg -q "\\[SupabaseAuth\\] <- token status=200" "$log_file"; then
    token_200="1"
  fi
  if rg -q "\\[SupabaseHTTP\\] <- POST .*functions/v1/nearby-presence status=200" "$log_file"; then
    nearby_200="1"
  fi

  if [[ "$test_status" -eq 0 && "$REQUIRE_HTTP_LOGS" != "1" ]]; then
    token_200="1"
    nearby_200="1"
  fi

  echo "[RivalAuthRevalidation] result attempt=$attempt test_status=$test_status token200=$token_200 nearby200=$nearby_200 log=$log_file"

  if [[ "$test_status" -eq 0 && "$token_200" == "1" && "$nearby_200" == "1" ]]; then
    echo "[RivalAuthRevalidation] SUCCESS"
    exit 0
  fi

  if [[ "$MAX_ATTEMPTS" -gt 0 && "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
    echo "[RivalAuthRevalidation] FAILED: max attempts reached ($MAX_ATTEMPTS)"
    exit 1
  fi

  attempt=$((attempt + 1))
  echo "[RivalAuthRevalidation] retrying from step 1 (logout -> login -> rival)"
done
