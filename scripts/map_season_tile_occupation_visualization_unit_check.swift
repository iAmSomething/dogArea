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

let mapModel = load("dogArea/Source/Domain/Map/Models/MapModel.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapSeasonTilePresentationService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapTopChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let mapSettingView = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let summaryCardView = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummaryCardView.swift")
let summarySheetView = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummarySheetView.swift")
let uiTest = load("dogAreaUITests/FeatureRegressionUITests.swift")
let doc = load("docs/map-season-tile-occupation-visualization-v1.md")
let stage3Doc = load("docs/season-stage3-ui-integration-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(mapModel.contains("func seasonTilePolygon() -> MKPolygon?"), "Heatmap cell model should expose a geohash polygon helper")
assertTrue(mapModel.contains("static func decodeBounds(geohash: String) -> GeohashBounds?"), "Geohash bounds decoder should exist")
assertTrue(service.contains("protocol MapSeasonTilePresentationServicing"), "Season tile presentation should be protocol-first")
assertTrue(service.contains("final class MapSeasonTilePresentationService"), "Season tile presentation concrete service should exist")
assertTrue(service.contains("MapSeasonTileChromeSummaryPresentation"), "Season tile presentation should define a compact chrome summary model")
assertTrue(mapViewModel.contains("@Published private(set) var seasonTileMapTiles: [MapSeasonTilePresentation] = []"), "MapViewModel should publish season tile presentation models")
assertTrue(mapViewModel.contains("seasonTileSummaryCardPresentation"), "MapViewModel should expose season tile summary card presentation")
assertTrue(mapViewModel.contains("seasonTileChromeSummaryPresentation"), "MapViewModel should expose a compact chrome summary presentation")
assertTrue(mapSubView.contains("ForEach(viewModel.seasonTileMapTiles) { tile in"), "MapSubView should render season tile presentation models")
assertTrue(mapSubView.contains("MapPolygon(tile.polygon)"), "MapSubView should render season tiles as polygons")
assertTrue(!mapSubView.contains("MapCircle(center: cell.centerCoordinate, radius: 75)"), "MapSubView should not render season tiles as circles anymore")
assertTrue(mapSubView.contains("seasonTileSelectionHaloColor"), "MapSubView should render a selection halo instead of darkening fill")
assertTrue(mapTopChromeView.contains("seasonTileSummaryContent"), "MapTopChromeView should accept season tile summary content")
assertTrue(mapView.contains("MapSeasonTileSummaryCardView"), "MapView should show the season tile summary card")
assertTrue(mapView.contains("MapSeasonTileSummarySheetView"), "MapView should provide a separate season overview sheet")
assertTrue(summaryCardView.contains("map.season.summary.openOverview"), "Compact season summary card should expose an overview entry action")
assertTrue(summarySheetView.contains("map.season.sheet.relation"), "Season overview sheet should host the extended relation explanation")
assertTrue(mapSettingView.contains("시즌 점령 지도 범례"), "Map settings should restate the season occupation legend")
assertTrue(uiTest.contains("testFeatureRegression_MapSeasonOccupationSummarySurfacesMeaningOnCanvas"), "Feature regression UI test should cover season occupation summary")
assertTrue(uiTest.contains("testFeatureRegression_MapSeasonOverviewSheetSurfacesMeaningAndLegend"), "Feature regression UI test should cover the season overview sheet")
assertTrue(uiTest.contains("testFeatureRegression_MapSeasonSummaryCollapsesToPillWhileWalking"), "Feature regression UI test should cover compact walking state chrome")
assertTrue(doc.contains("격자 타일") && doc.contains("polygon"), "Issue doc should record the polygon tile decision")
assertTrue(doc.contains("slim top chrome"), "Issue doc should describe the compact top chrome policy")
assertTrue(stage3Doc.contains("격자 타일") && stage3Doc.contains("polygon"), "Stage3 doc should reflect the polygon tile decision")
assertTrue(readme.contains("docs/map-season-tile-occupation-visualization-v1.md"), "README should index the season occupation visualization doc")
assertTrue(iosCheck.contains("swift scripts/map_season_tile_occupation_visualization_unit_check.swift"), "ios_pr_check should run the season occupation visualization check")

print("PASS: map season tile occupation visualization checks")
