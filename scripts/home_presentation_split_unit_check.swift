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

/// 여러 상대 경로 파일을 하나의 문자열로 결합해 읽습니다.
/// - Parameter relativePaths: 저장소 루트 기준 파일 경로 목록입니다.
/// - Returns: 각 파일 내용을 줄바꿈으로 합친 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/Cards/HomeQuestWidgetTabSelectorView.swift"
])
assertTrue(homeView.contains("HomeSeasonDetailSheetView("), "HomeView should present external season detail sheet view")
assertTrue(homeView.contains("HomeQuestCompletionOverlayView("), "HomeView should present external quest completion overlay view")
assertTrue(homeView.contains("HomeSeasonResultOverlayView("), "HomeView should present external season result overlay view")
assertTrue(homeView.contains("HomeSeasonResetTransitionBannerView()"), "HomeView should present external season reset banner view")
assertTrue(homeView.contains("HomeAreaMilestoneBadgeOverlayView("), "HomeView should present external area milestone overlay view")
assertTrue(homeView.contains("ForEach(HomeQuestWidgetTab.allCases)"), "HomeView should use shared HomeQuestWidgetTab type")
assertTrue(homeView.contains("HomeScrollOffsetPreferenceKey.self"), "HomeView should use shared HomeScrollOffsetPreferenceKey type")
assertTrue(homeView.contains("@State private var questWidgetTab: HomeQuestWidgetTab = .daily"), "HomeView should store quest widget tab with shared type")
assertTrue(homeView.contains("private func questCompletionOverlay") == false, "HomeView should not keep inline quest completion overlay")
assertTrue(homeView.contains("private func seasonResultOverlay") == false, "HomeView should not keep inline season result overlay")
assertTrue(homeView.contains("private var seasonDetailSheet") == false, "HomeView should not keep inline season detail sheet")
assertTrue(homeView.contains("private var seasonResetTransitionBanner") == false, "HomeView should not keep inline season reset banner")
assertTrue(homeView.contains("private struct HomeAreaMilestoneBadgeOverlayView") == false, "HomeView should not keep inline area milestone overlay type")
assertTrue(homeView.contains("private enum QuestWidgetTab") == false, "HomeView should not keep inline quest widget tab enum")
assertTrue(homeView.contains("private struct HomeScrollOffsetPreferenceKey") == false, "HomeView should not keep inline scroll offset preference key")

let expectedFiles: [(String, String)] = [
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeQuestWidgetTab.swift", "enum HomeQuestWidgetTab"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeScrollOffsetPreferenceKey.swift", "struct HomeScrollOffsetPreferenceKey: PreferenceKey"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeQuestCompletionOverlayView.swift", "struct HomeQuestCompletionOverlayView: View"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonResultOverlayView.swift", "struct HomeSeasonResultOverlayView: View"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonDetailSheetView.swift", "struct HomeSeasonDetailSheetView: View"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonResetTransitionBannerView.swift", "struct HomeSeasonResetTransitionBannerView: View"),
    ("dogArea/Views/HomeView/HomeSubView/Presentation/HomeAreaMilestoneBadgeOverlayView.swift", "struct HomeAreaMilestoneBadgeOverlayView: View")
]

for (path, snippet) in expectedFiles {
    let contents = load(path)
    assertTrue(contents.contains(snippet), "\(path) should contain \(snippet)")
}

print("PASS: home presentation split unit checks")
