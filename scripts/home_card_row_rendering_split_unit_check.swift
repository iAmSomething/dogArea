import Foundation

/// 검증 실패 시 즉시 종료합니다.
/// - Parameters:
///   - condition: 통과 여부입니다.
///   - message: 실패 시 출력할 설명입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로 파일을 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 경로입니다.
/// - Returns: UTF-8 문자열로 디코딩된 파일 내용입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let project = load("dogArea.xcodeproj/project.pbxproj")

let expectedReferences: [(String, String)] = [
    ("HomeScrollToTopFloatingButtonView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeScrollToTopFloatingButtonView.swift"),
    ("HomeGuestDataUpgradeCardView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeGuestDataUpgradeCardView.swift"),
    ("HomeWeatherMissionStatusCardView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherMissionStatusCardView.swift"),
    ("HomeWeatherShieldSummaryCardView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherShieldSummaryCardView.swift"),
    ("HomeQuestWidgetTabSelectorView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeQuestWidgetTabSelectorView.swift"),
    ("HomeQuestReminderToggleRowView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeQuestReminderToggleRowView.swift"),
    ("HomeWeeklyQuestSummaryView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeWeeklyQuestSummaryView.swift"),
    ("HomeQuestAlternativeSuggestionCardView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeQuestAlternativeSuggestionCardView.swift"),
    ("HomeMissionDifficultySummaryView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeMissionDifficultySummaryView.swift"),
    ("HomeSeasonMotionCardView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift"),
    ("HomeAnimatedSeasonGaugeView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeAnimatedSeasonGaugeView.swift"),
    ("HomeAnimatedQuestProgressBarView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeAnimatedQuestProgressBarView.swift"),
    ("HomeIndoorMissionRowView", "dogArea/Views/HomeView/HomeSubView/Cards/HomeIndoorMissionRowView.swift")
]

for (reference, path) in expectedReferences {
    assertTrue(homeView.contains(reference), "HomeView should reference \(reference)")
    let fileContents = load(path)
    assertTrue(fileContents.contains("struct "), "\(path) should declare a view struct")
    assertTrue(project.contains((path as NSString).lastPathComponent), "project should include \((path as NSString).lastPathComponent)")
}

let removedInlineSnippets = [
    "private func seasonMetricPill(title: String, value: String, color: Color)",
    "private func seasonShieldBadge(active: Bool)",
    "private func multiplierDescription(_ multiplier: Double)"
]

for snippet in removedInlineSnippets {
    assertTrue(homeView.contains(snippet) == false, "HomeView should not keep inline helper \(snippet)")
}

print("PASS: home card row rendering split unit checks")
