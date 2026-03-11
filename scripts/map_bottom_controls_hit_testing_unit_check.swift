import Foundation

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 로드합니다.
/// - Parameter relativePath: 저장소 루트에서 시작하는 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let bottomOverlay = load("dogArea/Views/MapView/MapSubViews/MapBottomControlOverlayView.swift")
let floatingControls = load("dogArea/Views/MapView/MapSubViews/MapFloatingControlColumnView.swift")

assertTrue(
    mapView.contains("MapBottomControlOverlayView("),
    "MapView should compose bottom controls through MapBottomControlOverlayView"
)
assertTrue(
    !mapView.contains(".overlay(alignment: .bottomTrailing) {\n                mapFloatingControlOverlay"),
    "MapView should remove the dedicated bottomTrailing floating control overlay"
)
assertTrue(
    bottomOverlay.contains(".zIndex(3)"),
    "bottom control overlay should keep floating controls above the primary action"
)
assertTrue(
    bottomOverlay.contains("floatingControlsBottomPadding"),
    "bottom control overlay should centralize floating control bottom padding"
)
assertTrue(
    bottomOverlay.contains("requiresIdleDeckSeparation"),
    "bottom control overlay should reserve a dedicated idle deck clearance path for the recenter button"
)
assertTrue(
    bottomOverlay.contains("MapWalkControlBarMetrics.idleFootprintBudget"),
    "bottom control overlay should reserve the idle control bar footprint before placing the recenter button"
)
assertTrue(
    floatingControls.contains("@Environment(\\.appTabBarReservedHeight)") == false,
    "MapFloatingControlColumnView should not own tab bar padding rules directly"
)
assertTrue(
    floatingControls.contains("frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)") == false,
    "MapFloatingControlColumnView should not own full-screen overlay layout directly"
)

print("PASS: map bottom controls hit testing unit checks")
