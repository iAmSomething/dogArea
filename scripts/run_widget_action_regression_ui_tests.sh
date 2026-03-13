#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/widget_simulator_baseline_status.sh"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dogArea-widget-action-regression}"
BASELINE_STATUS="fail"
BASELINE_COMMAND="bash scripts/run_widget_action_regression_ui_tests.sh '$DESTINATION'"

record_baseline_status() {
  write_widget_simulator_baseline_status "action-regression" "$BASELINE_STATUS" "$DESTINATION" "$BASELINE_COMMAND"
}

trap record_baseline_status EXIT

echo "[WidgetActionRegressionUI] Destination: $DESTINATION"
echo "[WidgetActionRegressionUI] DerivedData: $DERIVED_DATA_PATH"

run_ui_test() {
  local test_case="${1:-}"
  if [[ -z "$test_case" ]]; then
    echo "[WidgetActionRegressionUI] Missing test case name"
    return 1
  fi

  xcodebuild -scheme dogArea \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "$DESTINATION" \
    "-only-testing:dogAreaUITests/FeatureRegressionUITests/$test_case" \
    test-without-building
}

cd "$PROJECT_ROOT"

echo "[WidgetActionRegressionUI] build-for-testing"
xcodebuild -scheme dogArea \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "$DESTINATION" \
  build-for-testing

run_ui_test "testFeatureRegression_WidgetRouteOpensRivalTab"
run_ui_test "testFeatureRegression_WidgetEndRouteSurfacesSavedOutcomeCard"
run_ui_test "testFeatureRegression_WidgetStartRouteConvergesMapWalkingState"
run_ui_test "testFeatureRegression_HotspotWidgetRouteOpensRivalWithMatchingRadiusPreset"
run_ui_test "testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard"
run_ui_test "testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard"
run_ui_test "testFeatureRegression_TerritoryWidgetRouteOpensGoalDetail"

BASELINE_STATUS="pass"
echo "[WidgetActionRegressionUI] Done"
