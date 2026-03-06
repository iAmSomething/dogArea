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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift"
])
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSettingView = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let profileView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let seasonDetailSheetView = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonDetailSheetView.swift")
let seasonResultOverlayView = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonResultOverlayView.swift")
let spec = load("docs/season-stage3-ui-integration-v1.md")
let report = load("docs/cycle-156-season-stage3-ui-integration-report-2026-03-01.md")

assertTrue(homeView.contains("HomeSeasonDetailSheetView"), "HomeView should provide season detail sheet")
assertTrue(homeView.contains("todayScoreDelta"), "HomeView should show today's season score delta")
assertTrue(homeView.contains("retrySeasonRewardClaim"), "HomeView should expose reward retry action")
assertTrue(seasonDetailSheetView.contains("seasonDetailLine"), "Season detail sheet view should render season detail rows")
assertTrue(seasonResultOverlayView.contains("seasonRewardStatusText"), "Season result overlay view should render reward claim status text")

assertTrue(homeViewModel.contains("todayScoreDelta"), "SeasonMotionSummary should include today score delta")
assertTrue(homeViewModel.contains("dailyScoreLedger"), "SeasonMotionStore should persist daily score ledger")
assertTrue(homeViewModel.contains("seasonRemainingTimeText"), "HomeViewModel should expose remaining time text")
assertTrue(homeViewModel.contains("lastSeasonResultPresentation"), "HomeViewModel should expose last season result")

assertTrue(mapViewModel.contains("seasonTileIntensityLevel"), "MapViewModel should expose 4-step season tile intensity")
assertTrue(mapViewModel.contains("seasonTileStatusText"), "MapViewModel should expose occupied/maintained status")
assertTrue(mapViewModel.contains("seasonTileStatusSummaryText"), "MapViewModel should expose season tile summary")
assertTrue(mapSettingView.contains("seasonTileLegendItems"), "Map settings should expose season tile legend")
assertTrue(mapView.contains("seasonTileStatusSummaryText"), "MapView should show season tile summary text")

assertTrue(profileView.contains("SeasonProfileFrameStyle"), "Profile view should define season frame style")
assertTrue(profileView.contains("Season "), "Profile view should show season badge text")

assertTrue(spec.contains("4단계 강도"), "Spec should define 4-level season tile intensity")
assertTrue(spec.contains("보상 수령 실패"), "Spec should define reward retry behavior")
assertTrue(report.contains("#126"), "Cycle report should reference issue #126")

print("PASS: season stage3 ui integration unit checks")
