#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dogArea-feature-regression}"

echo "[FeatureRegressionUI] Destination: $DESTINATION"
echo "[FeatureRegressionUI] DerivedData: $DERIVED_DATA_PATH"

run_ui_test() {
  local test_case="${1:-}"
  if [[ -z "$test_case" ]]; then
    echo "[FeatureRegressionUI] Missing test case name"
    return 1
  fi
  xcodebuild -scheme dogArea \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "$DESTINATION" \
    "-only-testing:dogAreaUITests/DesignAuditUITests/$test_case" \
    test-without-building
}

cd "$PROJECT_ROOT"

echo "[FeatureRegressionUI] build-for-testing"
xcodebuild -scheme dogArea \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "$DESTINATION" \
  build-for-testing

run_ui_test "testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar"
run_ui_test "testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar"
run_ui_test "testFeatureRegression_RivalFooterButtonsRouteToMapAndSettings"
run_ui_test "testFeatureRegression_SettingsAuthEntryPoints"

echo "[FeatureRegressionUI] Done"
