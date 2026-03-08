import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapSettingView = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let clusterMotionState = load("dogArea/Views/MapView/MapViewModelSupport/MapClusterMotionState.swift")
let spec = load("docs/map-motion-pack-v1.md")
let report = load("docs/cycle-141-map-motion-pack-report-2026-02-27.md")

assertTrue(mapView.contains("weatherOverlayTintColor"), "MapView should render weather overlay tint")
assertTrue(mapSubView.contains("activeCaptureRipples"), "MapSubView should render capture ripple overlays")
assertTrue(mapSubView.contains("activeTrailMarkers"), "MapSubView should render walking trail markers")
assertTrue(mapSubView.contains("MapClusterPulseAnnotationView"), "MapSubView should delegate cluster pulse rendering to a dedicated view")

assertTrue(mapViewModel.contains("CaptureRipple"), "MapViewModel should define capture ripple type")
assertTrue(mapViewModel.contains("TrailMarker"), "MapViewModel should define trail marker type")
assertTrue(mapViewModel.contains("let clusterMotionState = MapClusterMotionState()"), "MapViewModel should own dedicated cluster motion state")
assertTrue(clusterMotionState.contains("final class MapClusterMotionState"), "Cluster motion state support type should exist")
assertTrue(mapViewModel.contains("refreshWeatherOverlayRisk"), "MapViewModel should refresh weather overlay risk")
assertTrue(mapViewModel.contains("toggleMapMotionReduced"), "MapViewModel should expose reduced motion toggle")
assertTrue(mapViewModel.contains("triggerCaptureHapticIfNeeded"), "MapViewModel should trigger capture haptics")
assertTrue(mapViewModel.contains("triggerWarningHapticIfNeeded"), "MapViewModel should trigger warning haptics")

assertTrue(mapSettingView.contains("모션 축소"), "MapSettingView should expose reduced motion control")
assertTrue(spec.contains("점령 파동"), "Map motion spec should document capture ripple")
assertTrue(report.contains("#141"), "Cycle report should reference issue #141")

print("PASS: map motion pack unit checks")
