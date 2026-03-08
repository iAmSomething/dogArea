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

let service = load("dogArea/Source/Domain/Map/Services/MapSeasonTilePresentationService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapTopChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let detailCard = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileDetailCardView.swift")
let uiTest = load("dogAreaUITests/FeatureRegressionUITests.swift")
let doc = load("docs/map-season-tile-detail-panel-v1.md")
let stage3Doc = load("docs/season-stage3-ui-integration-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(service.contains("struct MapSeasonTileDetailPresentation"), "Season tile detail presentation model should exist")
assertTrue(service.contains("selectionHintLine"), "Season tile summary should expose a selection hint line")
assertTrue(service.contains("func makeDetailPresentation(for tile: MapSeasonTilePresentation) -> MapSeasonTileDetailPresentation"), "Presentation service should expose detail presentation generation")
assertTrue(service.contains("reasonLine(for tile: MapSeasonTilePresentation)"), "Presentation service should define a reason line helper")
assertTrue(service.contains("nextActionLine(for tile: MapSeasonTilePresentation)"), "Presentation service should define a next action helper")

assertTrue(mapViewModel.contains("@Published private(set) var selectedSeasonTileGeohash: String? = nil"), "MapViewModel should keep selected season tile state")
assertTrue(mapViewModel.contains("var seasonTileDetailCardPresentation: MapSeasonTileDetailPresentation?"), "MapViewModel should expose a detail card presentation")
assertTrue(mapViewModel.contains("func toggleSelectedSeasonTile(_ tile: MapSeasonTilePresentation)"), "MapViewModel should toggle season tile selection")
assertTrue(mapViewModel.contains("func isSeasonTileSelected(_ tile: MapSeasonTilePresentation) -> Bool"), "MapViewModel should expose season tile selected-state helper")
assertTrue(mapViewModel.contains("func clearSelectedSeasonTile()"), "MapViewModel should expose detail dismiss helper")
assertTrue(mapViewModel.contains("func openRepresentativeSeasonTileDetail()"), "MapViewModel should expose a representative season tile detail opener for accessibility fallback")

assertTrue(mapSubView.contains("map.season.tile.hitTarget"), "MapSubView should expose a tappable hit target for season tiles")
assertTrue(mapSubView.contains("seasonTileSelectionHitTarget(for tile: MapSeasonTilePresentation)"), "MapSubView should define the season tile selection hit target builder")

assertTrue(mapTopChromeView.contains("let seasonTileDetailContent: AnyView?"), "MapTopChromeView should accept season tile detail content")
assertTrue(mapView.contains("MapSeasonTileDetailCardView"), "MapView should render the season tile detail card")
assertTrue(mapView.contains("openRepresentativeSeasonTileDetail"), "MapView should wire the representative season tile detail opener into the summary card")

assertTrue(detailCard.contains("map.season.detail.card"), "Detail card should expose a root accessibility identifier")
assertTrue(detailCard.contains("map.season.detail.reason"), "Detail card should expose the reason row accessibility identifier")
assertTrue(detailCard.contains("map.season.detail.nextAction"), "Detail card should expose the next action row accessibility identifier")
assertTrue(detailCard.contains("map.season.detail.close"), "Detail card should expose a close action accessibility identifier")
assertTrue(load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummaryCardView.swift").contains("map.season.summary.openDetail"), "Summary card should expose an accessibility fallback action for opening detail")

assertTrue(uiTest.contains("testFeatureRegression_MapSeasonTileTapOpensDetailPanel"), "Feature regression UI test should cover season tile detail drill-down")
assertTrue(uiTest.contains("map.season.summary.openDetail"), "Feature regression UI test should support the summary fallback detail opener")
assertTrue(doc.contains("상단 floating detail card"), "Issue doc should record the top card decision")
assertTrue(doc.contains("selectedSeasonTileGeohash"), "Issue doc should mention the local-only selection state approach")
assertTrue(doc.contains("대표 칸 상세 보기"), "Issue doc should mention the accessibility fallback detail opener")
assertTrue(stage3Doc.contains("타일을 눌렀을 때 상태 이유와 다음 산책 힌트를 보여주는 경량 상세 패널"), "Stage3 season UI doc should mention the detail panel")
assertTrue(readme.contains("docs/map-season-tile-detail-panel-v1.md"), "README should index the season tile detail panel doc")
assertTrue(iosCheck.contains("swift scripts/map_season_tile_detail_panel_unit_check.swift"), "ios_pr_check should run the season tile detail panel check")
assertTrue(project.contains("MapSeasonTileDetailCardView.swift"), "Xcode project should include the new season tile detail card file")

print("PASS: map season tile detail panel checks")
