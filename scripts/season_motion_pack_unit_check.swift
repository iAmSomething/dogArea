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

func rankTier(for score: Double) -> String {
    if score >= 520 { return "platinum" }
    if score >= 320 { return "gold" }
    if score >= 180 { return "silver" }
    if score >= 80 { return "bronze" }
    return "rookie"
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let notificationCenterView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let haptic = load("dogArea/Source/AppHapticFeedback.swift")
let spec = load("docs/season-motion-pack-v1.md")
let report = load("docs/cycle-143-season-motion-pack-report-2026-02-27.md")

assertTrue(homeViewModel.contains("seasonMotionSummary"), "HomeViewModel should expose season summary")
assertTrue(homeViewModel.contains("seasonMotionEvent"), "HomeViewModel should expose season motion events")
assertTrue(homeViewModel.contains("seasonResultPresentation"), "HomeViewModel should expose season result presentation")
assertTrue(homeViewModel.contains("seasonResetTransitionToken"), "HomeViewModel should expose season reset transition token")
assertTrue(homeViewModel.contains("recordMissionCompletion"), "Season motion store should record mission completion")

assertTrue(homeView.contains("seasonMotionCard(summary:"), "HomeView should render season motion card")
assertTrue(homeView.contains("animatedSeasonGauge"), "HomeView should render animated season gauge")
assertTrue(homeView.contains("seasonResultOverlay"), "HomeView should render season result overlay")
assertTrue(homeView.contains("seasonResetTransitionBanner"), "HomeView should render season reset transition banner")

assertTrue(haptic.contains("seasonScoreTick"), "Haptic utility should define season score haptic")
assertTrue(haptic.contains("seasonRankUp"), "Haptic utility should define season rank-up haptic")
assertTrue(haptic.contains("seasonShieldApplied"), "Haptic utility should define season shield haptic")
assertTrue(haptic.contains("seasonReset"), "Haptic utility should define season reset haptic")

assertTrue(settingViewModel.contains("SeasonProfileSummary"), "SettingViewModel should decode season profile summary")
assertTrue(notificationCenterView.contains("시즌 진행 현황"), "Profile view should show season summary card")

assertTrue(spec.contains("시즌 게이지"), "spec should include season gauge motion")
assertTrue(spec.contains("주간 리셋"), "spec should include weekly reset transition")
assertTrue(report.contains("#143"), "cycle report should reference issue #143")

assertTrue(rankTier(for: 79) == "rookie", "79 score should remain rookie")
assertTrue(rankTier(for: 80) == "bronze", "80 score should promote to bronze")
assertTrue(rankTier(for: 180) == "silver", "180 score should promote to silver")
assertTrue(rankTier(for: 320) == "gold", "320 score should promote to gold")
assertTrue(rankTier(for: 520) == "platinum", "520 score should promote to platinum")

print("PASS: season motion pack unit checks")
