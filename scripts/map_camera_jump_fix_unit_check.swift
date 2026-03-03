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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapAlertSubView = load("dogArea/Views/MapView/MapSubViews/MapAlertSubView.swift")

assertTrue(mapView.contains("viewModel.preparePointAddCameraSnapshot()"), "MapView add-point action should prepare camera snapshot")
assertTrue(!mapView.contains("viewModel.setTrackingMode()\n                myAlert.alertType = .addPoint"), "MapView add-point action should not switch tracking mode directly")
assertTrue(mapView.contains("viewModel.handleLocationButtonTap()"), "MapView current-location button should delegate to tracking handler")
assertTrue(mapView.contains("viewModel.recordCameraChange(context.camera)"), "MapView should forward camera change events for reason logging")

assertTrue(mapAlertSubView.contains("viewModel.addLocationPreservingCamera()"), "MapAlertSubView should preserve camera while adding point")

assertTrue(mapViewModel.contains("enum CameraChangeReason"), "MapViewModel should define camera change reason enum")
assertTrue(mapViewModel.contains("case manualMove = \"manual_move\""), "MapViewModel should log manual move reason")
assertTrue(mapViewModel.contains("case locationButton = \"location_button\""), "MapViewModel should log location button reason")
assertTrue(mapViewModel.contains("case systemFallback = \"system_fallback\""), "MapViewModel should log system fallback reason")
assertTrue(mapViewModel.contains("func handleLocationButtonTap()"), "MapViewModel should expose current-location handler")
assertTrue(mapViewModel.contains("func recordCameraChange(_ camera: MapCamera"), "MapViewModel should expose camera logging entrypoint")
assertTrue(mapViewModel.contains("map camera change: reason="), "MapViewModel should print camera change reason log")
assertTrue(mapViewModel.contains("func addLocationPreservingCamera()"), "MapViewModel should support point-add with camera preservation")
assertTrue(mapViewModel.contains("func setTrackingMode(reason: CameraChangeReason? = nil)"), "MapViewModel setTrackingMode should accept explicit reason")
assertTrue(mapViewModel.contains("func setRegion(_ location : CLLocation?, distance: Double = 2000, reason: CameraChangeReason? = nil)"), "MapViewModel location setRegion should accept reason")

print("PASS: map camera jump fix unit checks")
