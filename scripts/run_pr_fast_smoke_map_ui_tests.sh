#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dogArea-pr-fast-smoke-map}"

run_ui_test() {
  local test_case="${1:-}"
  if [[ -z "$test_case" ]]; then
    echo "[PRFastSmoke][FS-001] Missing test case name"
    return 1
  fi

  xcodebuild -scheme dogArea \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "$DESTINATION" \
    "-only-testing:dogAreaUITests/FeatureRegressionUITests/$test_case" \
    test-without-building
}

cd "$PROJECT_ROOT"

echo "[PRFastSmoke][FS-001] Destination: $DESTINATION"
echo "[PRFastSmoke][FS-001] DerivedData: $DERIVED_DATA_PATH"

echo "[PRFastSmoke][FS-001] build-for-testing"
xcodebuild -scheme dogArea \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "$DESTINATION" \
  build-for-testing

run_ui_test "testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar"
run_ui_test "testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking"
run_ui_test "testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest"
run_ui_test "testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls"

echo "[PRFastSmoke][FS-001] Done"
