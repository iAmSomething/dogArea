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

let support = load("dogArea/Source/Domain/Home/Services/HomeQuestReminderSupport.swift")
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let homeView = load("dogArea/Views/HomeView/HomeView.swift")

assertTrue(
    support.contains("struct AreaMilestoneEvent: Identifiable, Codable, Equatable"),
    "area milestone event model should be defined"
)
assertTrue(
    support.contains("area.milestone.achieved.v1") && support.contains("area.milestone.seeded.v1"),
    "area milestone dedupe ledger keys should be defined"
)
assertTrue(
    support.contains("home.area.milestone.notification.daily.v1") && support.contains("private let dailyLimit = 3"),
    "area milestone local notification scheduler should enforce daily fallback limit"
)

assertTrue(
    homeViewModel.contains("@Published var areaMilestonePresentation: AreaMilestoneEvent? = nil"),
    "home view model should expose area milestone presentation state"
)
assertTrue(
    homeViewModel.contains("areaMilestoneDetector.detectNewMilestones"),
    "home view model should evaluate area milestone crossing events"
)
assertTrue(
    homeViewModel.contains("func clearAreaMilestonePresentation()"),
    "home view model should clear milestone overlay and continue queue"
)

assertTrue(
    homeView.contains("HomeAreaMilestoneBadgeOverlayView") &&
    homeView.contains("onChange(of: viewModel.areaMilestonePresentation)"),
    "home view should present milestone badge overlay on milestone events"
)
assertTrue(
    homeView.contains("struct HomeAreaMilestoneBadgeOverlayView"),
    "home milestone overlay view should be implemented"
)

print("PASS: home area milestone feedback unit checks")
