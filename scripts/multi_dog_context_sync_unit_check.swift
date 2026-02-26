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

let doc = load("docs/multi-dog-context-sync-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let userDefaultsSource = load("dogArea/Source/UserdefaultSetting.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let walkListViewModel = load("dogArea/Views/WalkListView/WalkListViewModel.swift")
let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")

assertTrue(doc.contains("selectedPetDidChangeNotification"), "doc should define global sync notification")
assertTrue(doc.contains("자동 제안 규칙"), "doc should include suggestion policy")
assertTrue(doc.contains("1탭 스위처"), "doc should include one-tap switcher policy")
assertTrue(doc.contains("선택 반려견 통계 집계 규칙"), "doc should define selected-pet stats aggregation rules")
assertTrue(doc.contains("레거시 데이터 fallback"), "doc should define legacy fallback for untagged sessions")

assertTrue(checklist.contains("1탭 pet switcher"), "checklist must include one-tap switch scenario")
assertTrue(checklist.contains("화면 간 선택 반려견 상태"), "checklist must include cross-screen sync scenario")

assertTrue(userDefaultsSource.contains("selectedPetDidChangeNotification"), "userdefaults should expose selected pet change notification")
assertTrue(userDefaultsSource.contains("func suggestedPetForWalkStart"), "userdefaults should expose walk-start suggestion")
assertTrue(userDefaultsSource.contains("PetSelectionEvent"), "userdefaults should persist pet selection events")
assertTrue(userDefaultsSource.contains("petSelectionChanged"), "metric event for pet selection change should exist")
assertTrue(userDefaultsSource.contains("petSelectionSuggested"), "metric event for suggestion should exist")
assertTrue(userDefaultsSource.contains("let petId: String?"), "walk session metadata should include petId")

assertTrue(mapViewModel.contains("prepareWalkPetSelectionSuggestion"), "map view model should prepare walk-start suggestion")
assertTrue(mapViewModel.contains("cycleSelectedPetForWalkStart"), "map view model should support one-tap cycle switch")
assertTrue(mapViewModel.contains("selectedPetDidChangeNotification"), "map view model should subscribe to selected pet sync notification")
assertTrue(mapViewModel.contains("petId: selectedPetId"), "map view model should save session metadata with selected pet id")

assertTrue(startButton.contains("1탭 변경"), "start button should expose one-tap pet switcher label")
assertTrue(startButton.contains("prepareWalkPetSelectionSuggestion"), "start button should apply suggestion before start")

assertTrue(homeViewModel.contains("selectedPetDidChangeNotification"), "home should sync selected pet changes")
assertTrue(homeViewModel.contains("applySelectedPetStatistics"), "home should recalculate selected-pet statistics")
assertTrue(homeViewModel.contains("filteredPolygons"), "home should filter polygons by selected pet context")
assertTrue(settingViewModel.contains("selectedPetDidChangeNotification"), "setting should sync selected pet changes")
assertTrue(walkListViewModel.contains("selectedPetDidChangeNotification"), "walk list should sync selected pet changes")
assertTrue(walkListViewModel.contains("applySelectedPetFilter"), "walk list should apply selected-pet filtering")
assertTrue(walkListViewModel.contains("sessionMetadataStore.petId"), "walk list should filter by session metadata pet id")
assertTrue(walkListView.contains("현재 반려견 컨텍스트"), "walk list should show shared selected pet context")

print("PASS: multi dog context sync unit checks")
