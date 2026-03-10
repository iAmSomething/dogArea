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

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let seasonPolicy = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+SeasonTileVisualPolicy.swift")
let summaryCard = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummaryCardView.swift")
let summarySheet = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummarySheetView.swift")
let uiTest = load("dogAreaUITests/FeatureRegressionUITests.swift")

assertTrue(mapView.contains("isSeasonTileSummarySheetPresented"), "MapView should manage a separate season overview sheet state")
assertTrue(mapView.contains("shouldShowExpandedSeasonSummaryChrome"), "MapView should gate expanded season chrome separately from the pill")
assertTrue(mapSubView.contains("seasonTileSelectionHaloStyle"), "MapSubView should render a dedicated season selection halo layer")
assertTrue(mapSubView.contains("if viewModel.isWalking, activeWalkSnapshot.hasRenderableRoute"), "MapSubView should render active route above base polygon layers")
assertTrue(mapViewModel.contains("isHeatmapVisibleInMapUI"), "MapViewModel should expose season tile visibility policy")
assertTrue(!mapViewModel.contains("isHeatmapFeatureAvailable && heatmapEnabled && isWalking == false && showOnlyOne == false"), "Season tile visibility should no longer hard-hide during walking")
assertTrue(seasonPolicy.contains("weatherCompensation"), "Season tile fill opacity should compensate for weather tint")
assertTrue(seasonPolicy.contains("seasonTileSelectionHaloColor"), "Season tile visual policy should expose selection halo color")
assertTrue(summaryCard.contains("map.season.summary.metric.topLevel"), "Compact summary card should expose the top-level metric")
assertTrue(summarySheet.contains("map.season.sheet.openDetail"), "Overview sheet should expose representative detail fallback")
assertTrue(uiTest.contains("testFeatureRegression_MapSeasonSummaryCollapsesToPillWhileWalking"), "UI tests should cover season chrome compaction while walking")

print("PASS: map season render priority and compaction checks")
