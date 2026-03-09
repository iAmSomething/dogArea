#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dogArea-feature-regression}"
CREDENTIALS_FILE="$PROJECT_ROOT/.design_audit_credentials.json"

echo "[FeatureRegressionUI] Destination: $DESTINATION"
echo "[FeatureRegressionUI] DerivedData: $DERIVED_DATA_PATH"

cleanup_credentials_file() {
  if [[ -f "$CREDENTIALS_FILE" && "${FEATURE_REGRESSION_TEMP_CREDENTIALS:-0}" == "1" ]]; then
    rm -f "$CREDENTIALS_FILE"
  fi
}

prepare_credentials_file() {
  if [[ -f "$CREDENTIALS_FILE" ]]; then
    echo "[FeatureRegressionUI] Using existing credentials file"
    return 0
  fi

  if [[ -n "${DOGAREA_TEST_EMAIL:-}" && -n "${DOGAREA_TEST_PASSWORD:-}" ]]; then
    cat > "$CREDENTIALS_FILE" <<EOF
{"email":"${DOGAREA_TEST_EMAIL}","password":"${DOGAREA_TEST_PASSWORD}"}
EOF
    FEATURE_REGRESSION_TEMP_CREDENTIALS=1
    echo "[FeatureRegressionUI] Wrote temporary credentials file"
    return 0
  fi

  echo "[FeatureRegressionUI] No credentials file or DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD provided"
}

run_ui_test() {
  local test_case="${1:-}"
  if [[ -z "$test_case" ]]; then
    echo "[FeatureRegressionUI] Missing test case name"
    return 1
  fi
  xcodebuild -scheme dogArea \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "$DESTINATION" \
    "-only-testing:dogAreaUITests/FeatureRegressionUITests/$test_case" \
    test-without-building
}

cd "$PROJECT_ROOT"
trap cleanup_credentials_file EXIT
prepare_credentials_file

echo "[FeatureRegressionUI] build-for-testing"
xcodebuild -scheme dogArea \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "$DESTINATION" \
  build-for-testing

run_ui_test "testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar"
run_ui_test "testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking"
run_ui_test "testFeatureRegression_MapStopAlertPresentsClearActionHierarchy"
run_ui_test "testFeatureRegression_MapWalkValueGuideAutoPresentsOnFirstVisit"
run_ui_test "testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving"
run_ui_test "testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold"
run_ui_test "testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar"
run_ui_test "testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames"
run_ui_test "testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle"
run_ui_test "testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop"
run_ui_test "testFeatureRegression_HomeMissionHelpLayerExplainsWhatWhyHowAndOutcome"
run_ui_test "testFeatureRegression_HomeMissionCardDifferentiatesAutoAndManualTrackingModes"
run_ui_test "testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar"
run_ui_test "testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards"
run_ui_test "testFeatureRegression_WalkListTabSelectedIconRemainsVisibleInBothStyles"
run_ui_test "testFeatureRegression_WalkListCalendarSelectionFiltersToChosenDate"
run_ui_test "testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy"
run_ui_test "testFeatureRegression_WalkListDetailRestoresTopBackAffordance"
run_ui_test "testFeatureRegression_WalkListShareActionPresentsSystemSharePresenter"
run_ui_test "testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar"
run_ui_test "testFeatureRegression_RivalFooterButtonsRouteToMapAndSettings"
run_ui_test "testFeatureRegression_SettingsAuthEntryPoints"
run_ui_test "testFeatureRegression_SettingsProductSectionsExposeOperationalEntries"
run_ui_test "testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState"
run_ui_test "testFeatureRegression_HomeWeatherDetailCardShowsRawSnapshotMetrics"
run_ui_test "testFeatureRegression_HomeWeatherGuidanceSheetShowsActionableFallbackAndSections"
run_ui_test "testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit"
run_ui_test "testFeatureRegression_MemberProfileEditPersistsUpdatedPetName"
run_ui_test "testFeatureRegression_MemberPetManagementEditsExistingPet"
run_ui_test "testFeatureRegression_RivalAuthRevalidationFlow"
run_ui_test "testFeatureRegression_WidgetRouteOpensRivalTab"

echo "[FeatureRegressionUI] Done"
