import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@inline(__always)
func load(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fputs("FAIL: cannot load \(path)\n", stderr)
        exit(1)
    }
    return text
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/home-goal-tracker-ui-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeGoalTrackerCard = load("dogArea/Views/HomeView/HomeSubView/HomeGoalTrackerCardView.swift")
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let areaDetail = load("dogArea/Views/HomeView/AreaDetailView.swift")

assertTrue(doc.contains("비활성 `inline Picker`"), "doc should define picker removal policy")
assertTrue(doc.contains("현재 영역"), "doc should include current-area metric")
assertTrue(doc.contains("다음 목표"), "doc should include next-goal metric")
assertTrue(doc.contains("남은 면적"), "doc should include remaining-area metric")
assertTrue(doc.contains("TerritoryGoalView"), "doc should route home CTA into TerritoryGoalView")

assertTrue(checklist.contains("비활성 Picker가 제거"), "release checklist must include picker-removal scenario")
assertTrue(checklist.contains("목표 카드 접근성 라벨"), "release checklist must include accessibility label scenario")
assertTrue(checklist.contains("iPhone SE 홈 스크린샷"), "release checklist must include iPhone SE screenshot evidence")
assertTrue(checklist.contains("iPhone Pro Max 홈 스크린샷"), "release checklist must include Pro Max screenshot evidence")

assertTrue(homeView.contains("goalTrackerCard"), "home view should render goal tracker card")
assertTrue(!homeView.contains("Picker(\"도시들\""), "home view should remove inactive area picker")
assertTrue(homeGoalTrackerCard.contains("목표 상세 보기 >"), "home goal card should provide goal-detail CTA copy")
assertTrue(homeGoalTrackerCard.contains("accessibilityLabel"), "home goal card should include accessibility labels")
assertTrue(homeGoalTrackerCard.contains("ProgressView(value: progressRatio)"), "home goal card should expose progress")

assertTrue(homeViewModel.contains("var nextGoalArea"), "home view model should expose next-goal helper")
assertTrue(homeViewModel.contains("var remainingAreaToGoal"), "home view model should expose remaining-area helper")
assertTrue(homeViewModel.contains("var goalProgressRatio"), "home view model should expose progress ratio helper")

assertTrue(homeView.contains(".navigationDestination(isPresented: $isTerritoryGoalPresented)"), "home view should present territory goal detail destination")
assertTrue(homeView.contains("TerritoryGoalView("), "home view should render territory goal detail destination")
assertTrue(homeView.contains("TerritoryGoalViewModel("), "home view should build territory goal view model")
assertTrue(homeView.contains("homeViewModel: viewModel"), "home view should pass home view model into territory goal detail")
assertTrue(homeView.contains("entryContext: territoryGoalEntryContext"), "home view should forward widget entry context into territory goal detail")
assertTrue(areaDetail.contains("AreaDetailReferenceCatalogSectionView"), "comparison detail should render catalog section view")

print("PASS: home goal tracker UI unit checks")
