import Foundation

/// Aborts the script when a required condition is not satisfied.
/// - Parameters:
///   - condition: Boolean result that must evaluate to `true`.
///   - message: Failure message printed to stderr when the condition fails.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a UTF-8 text file from the repository root.
/// - Parameter relativePath: Repository-relative path to read.
/// - Returns: File contents decoded as UTF-8 text.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapAlertHost = load("dogArea/Views/MapView/MapSubViews/MapAlertSubView.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    mapView.contains("private var rootContent: some View"),
    "MapView should introduce a root-level content host for critical map modals"
)
assertTrue(
    mapView.contains(".allowsHitTesting(!isCriticalModalPresented)"),
    "MapView should block background interaction while the stop alert is presented"
)
assertTrue(
    mapView.contains(".accessibilityHidden(isCriticalModalPresented)"),
    "MapView should hide the background accessibility tree while the stop alert is presented"
)
assertTrue(
    mapView.contains("MapAlertSubView(viewModel: viewModel, myAlert: myAlert)") &&
    mapView.contains(".appTabBarVisibility(resolvedTabBarVisibility)"),
    "MapView should own the critical alert host and declaratively control tab bar visibility"
)
assertTrue(
    mapView.contains("if shouldShowBottomControls {") &&
    mapView.contains("!isCriticalModalPresented && !endWalkingViewPresented"),
    "MapView should suppress bottom controls while alert/sheet transitions are active"
)
assertTrue(
    mapAlertHost.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)") &&
    mapAlertHost.contains(".ignoresSafeArea()"),
    "Map alert host should occupy the full screen modal layer"
)
assertTrue(
    featureRegression.contains("waitUntilGone(activeTabBarButton, timeout: 2)") &&
    featureRegression.contains("waitUntilGone(bottomControls, timeout: 2)"),
    "feature regression should verify that tab bar and bottom controls disappear during the stop alert"
)
assertTrue(
    iosPRCheck.contains("swift scripts/map_stop_alert_modal_layering_unit_check.swift"),
    "ios_pr_check should run the map stop alert modal layering unit check"
)

print("PASS: map stop alert modal layering unit checks")
