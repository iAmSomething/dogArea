import Foundation

@inline(__always)
/// Asserts that a condition is true and terminates the script when it is false.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to `true`.
///   - message: Failure message printed to stderr when the assertion fails.
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a UTF-8 text file from the repository root.
/// - Parameter relativePath: Repository-relative file path to load.
/// - Returns: Decoded UTF-8 text contents for the file.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let alertConfigure = load("dogArea/Views/GlobalViews/AlertView/CustomAlertConfigure.swift")
let alertView = load("dogArea/Views/GlobalViews/AlertView/CustomAlertView.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionRunner = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")

assertTrue(
    alertConfigure.contains("enum AlertActionSemanticRole") &&
    alertConfigure.contains("enum AlertSurfaceTone") &&
    alertConfigure.contains("var buttonDescriptors: [AlertButtonDescriptor]"),
    "alert configure should expose semantic button hierarchy and surface tone metadata"
)
assertTrue(
    alertView.contains("customAlert.surface") &&
    alertView.contains("customAlert.action.primary") &&
    alertView.contains("customAlert.action.secondary") &&
    alertView.contains("customAlert.action.destructive"),
    "custom alert view should expose stable accessibility identifiers for the redesigned actions"
)
assertTrue(
    alertView.contains("dynamicTypeSize") &&
    alertView.contains("ScrollView(showsIndicators: false)") &&
    alertView.contains("minHeight: CustomAlertLayoutMetrics.actionMinHeight"),
    "custom alert view should support dynamic type, long copy, and 44pt+ tap targets"
)
assertTrue(
    startButton.contains("title: \"산책을 마칠까요?\"") &&
    startButton.contains("first: \"저장 후 종료\"") &&
    startButton.contains("second: \"계속 걷기\"") &&
    startButton.contains("third: \"기록 폐기\""),
    "map stop flow should use the redesigned stop alert copy and action hierarchy"
)
assertTrue(
    featureRegression.contains("testFeatureRegression_MapStopAlertPresentsClearActionHierarchy"),
    "feature regression suite should cover the redesigned map stop alert hierarchy"
)
assertTrue(
    featureRegressionRunner.contains("testFeatureRegression_MapStopAlertPresentsClearActionHierarchy"),
    "feature regression runner should execute the map stop alert hierarchy test"
)
assertTrue(
    regressionMatrix.contains("FR-MAP-003"),
    "ui regression matrix should document the map stop alert hierarchy regression case"
)

print("PASS: map custom alert redesign unit checks")
