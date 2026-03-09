import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let activeValueCard = load("dogArea/Views/MapView/MapSubViews/MapWalkActiveValueCardView.swift")
let renderBudgetOverlay = load("dogArea/Views/MapView/MapSubViews/MapRenderBudgetProbeOverlayView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")
let doc = load("docs/map-walking-invalidation-reduction-v1.md")

assertTrue(!mapSubView.contains("motionTicker"), "MapSubView should not keep a 250ms motion ticker at the root.")
assertTrue(!mapSubView.contains("motionNow"), "MapSubView should not store root-level motionNow state.")
assertTrue(mapSubView.contains("MapCaptureRippleAnnotationView"), "MapSubView should isolate ripple animation into a dedicated annotation view.")
assertTrue(mapSubView.contains("MapTrailMarkerAnnotationView"), "MapSubView should isolate trail animation into a dedicated annotation view.")
assertTrue(renderBudgetOverlay.contains("struct MapRenderBudgetProbeOverlayView"), "Render budget diagnostics should live in a dedicated overlay view.")
assertTrue(mapView.contains("MapRenderBudgetProbeOverlayView()"), "MapView should expose the render budget probe overlay for diagnostics.")
assertTrue(mapView.contains("MapRenderBudgetProbe.resetIfNeeded()"), "MapView should reset the render budget probe on appear.")
assertTrue(!mapViewModel.contains("@Published var time"), "MapViewModel.time should no longer be published at the root level.")
assertTrue(mapViewModel.contains("displayedWalkElapsedTime"), "MapViewModel should expose a display-only elapsed time accessor.")
assertTrue(mapViewModel.contains("publishMapLocationIfNeeded"), "MapViewModel should gate location publishes behind a budgeted helper.")
assertTrue(mapViewModel.contains("shouldPublishMapLocation"), "MapViewModel should decide map location invalidation based on meaningful deltas.")
assertTrue(startButton.contains("MapWalkingElapsedTimeValueText") == false, "StartButtonView should not own elapsed time ticker state anymore.")
assertTrue(activeValueCard.contains("MapWalkingElapsedTimeValueText"), "The walking top HUD should localize elapsed time updates to a dedicated timeline view.")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold"), "UI regression test should cover walking render budget.")
assertTrue(featureRunner.contains("testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold"), "Feature regression runner should include the map render budget test.")
assertTrue(doc.contains("#476"), "Performance report should reference issue #476.")
assertTrue(doc.contains("3초"), "Performance report should document the three-second measurement window.")

print("PASS: map walking invalidation reduction checks")
