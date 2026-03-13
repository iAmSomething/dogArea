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
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let clusterMotionState = load("dogArea/Views/MapView/MapViewModelSupport/MapClusterMotionState.swift")
let clusterPulseView = load("dogArea/Views/MapView/MapSubViews/MapClusterPulseAnnotationView.swift")
let trailMarkerView = load("dogArea/Views/MapView/MapSubViews/MapTrailMarkerAnnotationView.swift")
let renderBudgetOverlay = load("dogArea/Views/MapView/MapSubViews/MapRenderBudgetProbeOverlayView.swift")
let doc = load("docs/map-motion-ticker-layer-split-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(!mapSubView.contains("clusterPulseActive"), "MapSubView should not keep local cluster pulse state")
assertTrue(!mapSubView.contains("TimelineView("), "MapSubView should not host ticker-driven subviews directly")
assertTrue(!mapSubView.contains("clusterMotionToken"), "MapSubView should not observe cluster motion token directly")

assertTrue(mapView.contains("MapRenderBudgetProbeOverlayView()"), "MapView should host the debug HUD outside the map body")

assertTrue(mapViewModel.contains("let clusterMotionState = MapClusterMotionState()"), "MapViewModel should own a dedicated cluster motion state store")
assertTrue(mapViewModel.contains("clusterMotionState.trigger(.decompose)"), "MapViewModel should emit decompose through cluster motion state")
assertTrue(mapViewModel.contains("clusterMotionState.trigger(.merge)"), "MapViewModel should emit merge through cluster motion state")
assertTrue(mapViewModel.contains("clusterMotionState.reset()"), "MapViewModel should reset cluster motion state when count is stable")
assertTrue(!mapViewModel.contains("@Published private(set) var clusterMotionTransition"), "clusterMotionTransition should no longer live on MapViewModel as published root state")
assertTrue(!mapViewModel.contains("@Published private(set) var clusterMotionToken"), "clusterMotionToken should no longer live on MapViewModel as published root state")

assertTrue(clusterMotionState.contains("final class MapClusterMotionState"), "cluster motion state type should exist")
assertTrue(clusterMotionState.contains("@Published private(set) var transition"), "cluster motion state should publish transition")
assertTrue(clusterMotionState.contains("@Published private(set) var token"), "cluster motion state should publish token")
assertTrue(clusterMotionState.contains("func trigger(_ transition"), "cluster motion state should expose trigger API")

assertTrue(clusterPulseView.contains("@ObservedObject var motionState: MapClusterMotionState"), "cluster pulse view should observe the dedicated motion state")
assertTrue(clusterPulseView.contains("runPulseAnimationIfNeeded()"), "cluster pulse view should drive its own animation")

assertTrue(!trailMarkerView.contains("TimelineView("), "trail marker view should not depend on TimelineView anymore")
assertTrue(trailMarkerView.contains("startLifecycleAnimation()"), "trail marker view should animate from lifecycle state")

assertTrue(!renderBudgetOverlay.contains("TimelineView("), "render budget overlay should avoid its own ticker-driven invalidation")
assertTrue(renderBudgetOverlay.contains("@State private var sampledCountText"), "render budget overlay should keep a sampled display state")
assertTrue(renderBudgetOverlay.contains("Button(\"sample\")"), "render budget overlay should expose an explicit sample action")
assertTrue(renderBudgetOverlay.contains("accessibilityIdentifier(\"map.debug.renderCount.sample\")"), "render budget overlay sample action should be exposed to UI tests")

assertTrue(doc.contains("#501"), "doc should reference issue #501")
assertTrue(doc.contains("TimelineView` 개수: `2"), "doc should capture the before ticker count")
assertTrue(doc.contains("TimelineView` 개수: `0"), "doc should capture the after ticker count")
assertTrue(doc.contains("mapSubViewBodyCount`는 `1"), "doc should record the latest render budget measurement result")

assertTrue(readme.contains("docs/map-motion-ticker-layer-split-v1.md"), "README should index the ticker layer split doc")
assertTrue(iosCheck.contains("swift scripts/map_motion_ticker_layer_split_unit_check.swift"), "ios_pr_check should run the ticker layer split check")

print("PASS: map motion ticker layer split checks")
