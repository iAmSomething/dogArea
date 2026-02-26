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

let doc = load("docs/home-goal-tracker-ui-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let areaDetail = load("dogArea/Views/HomeView/AreaDetailView.swift")

assertTrue(doc.contains("비활성 `inline Picker`"), "doc should define picker removal policy")
assertTrue(doc.contains("현재 영역"), "doc should include current-area metric")
assertTrue(doc.contains("다음 목표"), "doc should include next-goal metric")
assertTrue(doc.contains("남은 면적"), "doc should include remaining-area metric")

assertTrue(checklist.contains("비활성 Picker가 제거"), "release checklist must include picker-removal scenario")
assertTrue(checklist.contains("목표 카드 접근성 라벨"), "release checklist must include accessibility label scenario")
assertTrue(checklist.contains("iPhone SE 홈 스크린샷"), "release checklist must include iPhone SE screenshot evidence")
assertTrue(checklist.contains("iPhone Pro Max 홈 스크린샷"), "release checklist must include Pro Max screenshot evidence")

assertTrue(homeView.contains("goalTrackerCard"), "home view should render goal tracker card")
assertTrue(!homeView.contains("Picker(\"도시들\""), "home view should remove inactive area picker")
assertTrue(homeView.contains("비교군 더보기 >"), "home view should provide detail CTA for comparison list")
assertTrue(homeView.contains("accessibilityLabel"), "home goal card should include accessibility labels")
assertTrue(homeView.contains("ProgressView(value: viewModel.goalProgressRatio)"), "home goal card should expose progress")

assertTrue(homeViewModel.contains("var nextGoalArea"), "home view model should expose next-goal helper")
assertTrue(homeViewModel.contains("var remainingAreaToGoal"), "home view model should expose remaining-area helper")
assertTrue(homeViewModel.contains("var goalProgressRatio"), "home view model should expose progress ratio helper")

assertTrue(areaDetail.contains("ForEach(viewModel.myAreaList.reversed()"), "comparison detail list should remain available on detail screen")

print("PASS: home goal tracker UI unit checks")
