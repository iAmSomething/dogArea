import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 로드합니다.
/// - Parameter relativePath: 저장소 루트에서 시작하는 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let matrix = load("docs/ui-regression-matrix-v1.md")
let designAuditUITests = load("dogAreaUITests/DesignAuditUITests.swift")
let featureRegressionUITests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let designAuditScript = load("scripts/run_design_audit_ui_tests.sh")

for token in [
    "DA-HOME-001",
    "FR-MAP-001",
    "FR-MAP-002",
    "FR-MAP-003",
    "FR-WALK-001",
    "FR-WALK-002",
    "FR-WALK-003",
    "FR-GOAL-001",
    "FR-HOME-QUEST-001",
    "FR-AUTH-001",
    "FR-SET-001",
    "FR-PROFILE-001",
    "FR-RIVAL-001",
    "FR-WIDGET-001",
    "QA-MULTIPET-001",
    "scripts/run_feature_regression_ui_tests.sh",
    "scripts/run_design_audit_ui_tests.sh"
] {
    assertTrue(matrix.contains(token), "ui regression matrix should document \(token)")
}

assertTrue(
    designAuditUITests.contains("final class DesignAuditUITests: XCTestCase"),
    "DesignAuditUITests should remain the dedicated design audit suite"
)
assertTrue(
    !designAuditUITests.contains("func testFeatureRegression_"),
    "DesignAuditUITests should not host feature regression test methods"
)
assertTrue(
    featureRegressionUITests.contains("final class FeatureRegressionUITests: XCTestCase"),
    "FeatureRegressionUITests should exist as a separate feature regression suite"
)
for testName in [
    "testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar",
    "testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking",
    "testFeatureRegression_MapStopAlertPresentsClearActionHierarchy",
    "testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar",
    "testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards",
    "testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy",
    "testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar",
    "testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState",
    "testFeatureRegression_SettingsAuthEntryPoints",
    "testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit",
    "testFeatureRegression_MemberProfileEditPersistsUpdatedPetName",
    "testFeatureRegression_RivalAuthRevalidationFlow",
    "testFeatureRegression_WidgetRouteOpensRivalTab"
] {
    assertTrue(
        featureRegressionUITests.contains(testName),
        "FeatureRegressionUITests should cover \(testName)"
    )
}

assertTrue(
    featureRegressionScript.contains("FeatureRegressionUITests"),
    "run_feature_regression_ui_tests.sh should target FeatureRegressionUITests"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar"),
    "run_feature_regression_ui_tests.sh should run the walk list tabbar regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards"),
    "run_feature_regression_ui_tests.sh should run the walk list header hub regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy"),
    "run_feature_regression_ui_tests.sh should run the walk list detail hierarchy regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking"),
    "run_feature_regression_ui_tests.sh should run the walking add-point regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_MapStopAlertPresentsClearActionHierarchy"),
    "run_feature_regression_ui_tests.sh should run the map stop alert hierarchy regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState"),
    "run_feature_regression_ui_tests.sh should run the home mission lifecycle regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit"),
    "run_feature_regression_ui_tests.sh should run the settings image affordance regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_MemberProfileEditPersistsUpdatedPetName"),
    "run_feature_regression_ui_tests.sh should run the profile edit regression"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_WidgetRouteOpensRivalTab"),
    "run_feature_regression_ui_tests.sh should run the widget route regression"
)
assertTrue(
    designAuditScript.contains("DesignAuditUITests"),
    "run_design_audit_ui_tests.sh should target DesignAuditUITests"
)

print("PASS: ui regression matrix unit checks")
