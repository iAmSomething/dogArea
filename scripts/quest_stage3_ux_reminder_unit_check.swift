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

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Services/HomeQuestReminderSupport.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let spec = load("docs/quest-stage3-ux-reminder-v1.md")
let report = load("docs/cycle-170-quest-stage3-ux-reminder-report-2026-03-01.md")

assertTrue(homeView.contains("QuestWidgetTab"), "HomeView should define daily/weekly quest widget tabs")
assertTrue(homeView.contains("questWidgetTabSelector"), "HomeView should render quest tab selector")
assertTrue(homeView.contains("questReminderToggleRow"), "HomeView should render quest reminder toggle row")
assertTrue(homeView.contains("weeklyQuestSummary"), "HomeView should render weekly quest summary view")
assertTrue(homeView.contains("questAlternativeSuggestionCard"), "HomeView should render alternative action suggestion card")

assertTrue(homeViewModel.contains("setQuestReminderEnabled"), "HomeViewModel should expose reminder preference toggle")
assertTrue(homeViewModel.contains("LocalQuestReminderScheduler"), "HomeViewModel should include local reminder scheduler")
assertTrue(homeViewModel.contains("UNUserNotificationCenter"), "Reminder scheduler should use UNUserNotificationCenter")
assertTrue(homeViewModel.contains("questAlternativeActionSuggestion"), "HomeViewModel should publish alternative suggestion")
assertTrue(homeViewModel.contains("makeQuestAlternativeActionSuggestion"), "HomeViewModel should build fallback guidance")

assertTrue(spec.contains("일일/주간"), "Spec should describe daily/weekly tabs")
assertTrue(spec.contains("하루 1회"), "Spec should enforce once-per-day reminder")
assertTrue(report.contains("Issue #129"), "Cycle report should reference issue #129")

print("PASS: quest stage3 ux reminder unit checks")
