import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let startButtonView = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let bottomOverlay = load("dogArea/Views/MapView/MapSubViews/MapBottomControlOverlayView.swift")
let topChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/map-bottom-controller-anchored-density-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(startButtonView.contains("MapWalkControlBarMetrics"), "start button should define dedicated control bar metrics")
assertTrue(startButtonView.contains("idleFootprintBudget"), "start button should define the idle footprint budget")
assertTrue(startButtonView.contains("walkingFootprintBudget"), "start button should define the walking footprint budget")
assertTrue(startButtonView.contains("map.walk.controlBar"), "start button should expose a dedicated control bar accessibility identifier")
assertTrue(startButtonView.contains("walkingControlContextCard"), "walking layout should keep a dedicated control context card inside the control bar")
assertTrue(startButtonView.contains("MapWalkActiveValueCardView") == false, "walking layout should no longer render the top HUD helper inside the control bar")
assertTrue(topChromeView.contains("walkingHUDContent"), "top chrome should host the walking slim HUD above the map canvas")
assertTrue(bottomOverlay.contains("primaryActionLiftWhenVisible"), "bottom overlay should define a dedicated primary action lift")
assertTrue(bottomOverlay.contains("floatingControlsBottomSpacingWhenPrimaryVisible: CGFloat = 18"), "bottom overlay should tighten floating control spacing while primary action is visible")
assertTrue(bottomOverlay.contains("selectedTrayBottomSpacingWhenPrimaryVisible: CGFloat = 104"), "bottom overlay should tighten selected tray spacing while primary action is visible")
assertTrue(featureTests.contains("testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest"), "feature tests should cover idle bottom controller density")
assertTrue(featureTests.contains("testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactWhileWalking"), "feature tests should cover walking bottom controller density")
assertTrue(featureScript.contains("testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest"), "feature regression script should run the idle control bar density regression")
assertTrue(featureScript.contains("testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactWhileWalking"), "feature regression script should run the walking control bar density regression")
assertTrue(uiMatrix.contains("FR-MAP-006"), "ui regression matrix should include the idle control bar density case")
assertTrue(uiMatrix.contains("FR-MAP-007"), "ui regression matrix should include the walking control bar density case")
assertTrue(doc.contains("idle 컨트롤 바 surface 높이 budget: `<= 124pt`"), "doc should record the idle height budget")
assertTrue(doc.contains("walking 컨트롤 바 surface 높이 budget: `<= 112pt`"), "doc should record the walking height budget")
assertTrue(readme.contains("docs/map-bottom-controller-anchored-density-v1.md"), "README should index the control bar density doc")
assertTrue(prCheck.contains("swift scripts/map_bottom_controller_density_unit_check.swift"), "ios_pr_check should include the control bar density unit check")

print("PASS: map bottom controller density unit checks")
