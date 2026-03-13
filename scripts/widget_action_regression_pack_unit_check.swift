import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a text file relative to the repository root.
/// - Parameter relativePath: Repository-relative file path.
/// - Returns: UTF-8 decoded text contents.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to load \(relativePath)\n", stderr)
        exit(1)
    }
    return text
}

/// Fails the script when the provided condition is false.
/// - Parameters:
///   - condition: Boolean condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let runner = load("scripts/run_widget_action_regression_ui_tests.sh")
let doc = load("docs/widget-action-real-device-validation-matrix-v1.md")
let readme = load("README.md")
let uiRegressionMatrix = load("docs/ui-regression-matrix-v1.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

let expectedTests = [
    "testFeatureRegression_WidgetRouteOpensRivalTab",
    "testFeatureRegression_WidgetEndRouteSurfacesSavedOutcomeCard",
    "testFeatureRegression_WidgetStartRouteDefersIntoAuthEntryWhenSessionMissing",
    "testFeatureRegression_HotspotWidgetRouteOpensRivalWithMatchingRadiusPreset",
    "testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard",
    "testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard",
    "testFeatureRegression_TerritoryWidgetRouteOpensGoalDetail"
]

assertTrue(runner.contains("[WidgetActionRegressionUI] build-for-testing"), "runner should perform build-for-testing")
assertTrue(runner.contains("test-without-building"), "runner should execute tests without rebuilding each case")
for testName in expectedTests {
    assertTrue(runner.contains(testName), "runner should include \(testName)")
}

assertTrue(doc.contains("# Widget Action Real-Device Validation Matrix v1"), "doc title should exist")
assertTrue(doc.contains("Issue: #731"), "doc should reference current blocker issue #731")
assertTrue(!doc.contains("Issue: #660"), "doc should not keep stale issue #660")
assertTrue(doc.contains("Relates to: #408"), "doc should reference #408")
assertTrue(doc.contains("cold start"), "doc should define cold start axis")
assertTrue(doc.contains("background"), "doc should define background axis")
assertTrue(doc.contains("foreground"), "doc should define foreground axis")
assertTrue(doc.contains("로그인"), "doc should define logged-in auth axis")
assertTrue(doc.contains("로그아웃"), "doc should define logged-out auth axis")
assertTrue(doc.contains("auth overlay"), "doc should define auth overlay defer axis")
assertTrue(doc.contains("walk_start"), "doc should include walk_start action")
assertTrue(doc.contains("walk_end"), "doc should include walk_end action")
assertTrue(doc.contains("WidgetAction"), "doc should require WidgetAction log evidence")
assertTrue(doc.contains("consumePendingWidgetActionIfNeeded"), "doc should require pending-action consumption evidence")
assertTrue(doc.contains("docs/widget-simulator-baseline-coverage-matrix-v1.md"), "doc should link the simulator coverage matrix")

assertTrue(readme.contains("docs/widget-action-real-device-validation-matrix-v1.md"), "README should link the widget action validation matrix")
assertTrue(readme.contains("docs/widget-simulator-baseline-coverage-matrix-v1.md"), "README should link the simulator coverage matrix")
assertTrue(readme.contains("bash scripts/run_widget_action_regression_ui_tests.sh"), "README should expose the widget action regression runner")
assertTrue(uiRegressionMatrix.contains("bash scripts/run_widget_action_regression_ui_tests.sh"), "UI regression matrix should list the widget action runner")
assertTrue(uiRegressionMatrix.contains("FR-WIDGET-005"), "UI regression matrix should map dedicated widget cases")
assertTrue(iosPRCheck.contains("widget_action_regression_pack_unit_check.swift"), "ios_pr_check should run the widget action regression pack check")

print("PASS: widget action regression pack unit checks")
