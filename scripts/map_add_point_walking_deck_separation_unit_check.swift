import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let bottomOverlay = load("dogArea/Views/MapView/MapSubViews/MapBottomControlOverlayView.swift")
let floatingControls = load("dogArea/Views/MapView/MapSubViews/MapFloatingControlColumnView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let doc = load("docs/map-add-point-walking-deck-separation-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    bottomOverlay.contains("struct MapFloatingControlLayoutContext"),
    "bottom overlay should define a dedicated floating control layout context"
)
assertTrue(
    bottomOverlay.contains("MapWalkControlBarMetrics.walkingFootprintBudget"),
    "bottom overlay should reserve the walking control bar footprint when add-point controls are visible"
)
assertTrue(
    mapView.contains("floatingControlLayoutContext: mapFloatingControlLayoutContext"),
    "MapView should pass the floating control layout context into the bottom overlay"
)
assertTrue(
    floatingControls.contains("map.addPoint.stack"),
    "floating control column should expose an add-point stack accessibility identifier"
)
assertTrue(
    floatingControls.contains("map.addPoint.badge.autoRecord"),
    "floating control column should expose an auto-record support badge identifier"
)
assertTrue(
    floatingControls.contains("map.addPoint.badge.longPress"),
    "floating control column should expose a long-press support badge identifier"
)
assertTrue(
    featureTests.contains("testFeatureRegression_MapAddPointSupportStackClearsWalkingDeckFootprint"),
    "feature regression suite should guard against add-point stack overlap with the walking deck"
)
assertTrue(
    featureScript.contains("testFeatureRegression_MapAddPointSupportStackClearsWalkingDeckFootprint"),
    "feature regression script should run the add-point overlap regression"
)
assertTrue(
    doc.contains("MapWalkControlBarMetrics.walkingFootprintBudget + 14pt"),
    "doc should record the walking deck separation formula"
)
assertTrue(
    readme.contains("docs/map-add-point-walking-deck-separation-v1.md"),
    "README should index the add-point walking deck separation doc"
)
assertTrue(
    prCheck.contains("swift scripts/map_add_point_walking_deck_separation_unit_check.swift"),
    "ios_pr_check should run the add-point walking deck separation check"
)

print("PASS: map add-point walking deck separation unit checks")
