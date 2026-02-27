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

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let haptic = load("dogArea/Source/AppHapticFeedback.swift")
let spec = load("docs/quest-motion-pack-v1.md")
let report = load("docs/cycle-142-quest-motion-pack-report-2026-02-27.md")

assertTrue(homeView.contains("animatedQuestProgressBar"), "HomeView should render animated quest progress bar")
assertTrue(homeView.contains("questCompletionOverlay"), "HomeView should render quest completion modal")
assertTrue(homeView.contains("questClaimPulseMissionId"), "HomeView should animate claim state transition")
assertTrue(homeView.contains("isQuestMotionReduced"), "HomeView should support reduced motion mode")

assertTrue(homeViewModel.contains("QuestMotionEvent"), "HomeViewModel should define quest motion event model")
assertTrue(homeViewModel.contains("questMotionEvent"), "HomeViewModel should publish quest motion events")
assertTrue(homeViewModel.contains("questCompletionPresentation"), "HomeViewModel should publish quest completion presentation")
assertTrue(homeViewModel.contains("walkPointRecordedForQuest"), "HomeViewModel should define quest progress notification")

assertTrue(mapViewModel.contains("walkPointRecordedForQuest"), "MapViewModel should post quest progress reflection notification")
assertTrue(mapViewModel.contains("AppHapticFeedback.mapCaptureSuccess"), "MapViewModel should use shared haptic utility")
assertTrue(haptic.contains("enum AppHapticFeedback"), "Shared haptic utility should exist")
assertTrue(haptic.contains("questProgress"), "Shared haptic utility should include quest progress haptic")
assertTrue(haptic.contains("questCompleted"), "Shared haptic utility should include quest completion haptic")
assertTrue(haptic.contains("questFailed"), "Shared haptic utility should include quest failure haptic")

assertTrue(spec.contains("퀘스트 카드 스냅"), "Quest motion spec should document snap motion")
assertTrue(report.contains("#142"), "Cycle report should reference issue #142")

print("PASS: quest motion pack unit checks")
