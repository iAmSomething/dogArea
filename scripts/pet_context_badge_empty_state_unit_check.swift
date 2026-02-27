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

let homeVM = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let walkListVM = load("dogArea/Views/WalkListView/WalkListViewModel.swift")
let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let uxDoc = load("docs/pet-context-badge-empty-state-v1.md")
let readme = load("README.md")

assertTrue(homeVM.contains("@Published private(set) var isShowingAllRecordsOverride"), "HomeViewModel should expose all-records override state")
assertTrue(homeVM.contains("var shouldShowSelectedPetEmptyState"), "HomeViewModel should compute selected-pet empty state")
assertTrue(homeVM.contains("func showAllRecordsTemporarily()"), "HomeViewModel should support temporary all-records mode")
assertTrue(homeVM.contains("func showSelectedPetRecords()"), "HomeViewModel should support returning to selected-pet mode")

assertTrue(walkListVM.contains("@Published private(set) var isShowingAllRecordsOverride"), "WalkListViewModel should expose all-records override state")
assertTrue(walkListVM.contains("var shouldShowSelectedPetEmptyState"), "WalkListViewModel should compute selected-pet empty state")
assertTrue(walkListVM.contains("func showAllRecordsTemporarily()"), "WalkListViewModel should support temporary all-records mode")
assertTrue(walkListVM.contains("func showSelectedPetRecords()"), "WalkListViewModel should support returning to selected-pet mode")

assertTrue(homeView.contains("selectedPetContextBanner"), "HomeView should render selected pet context banner")
assertTrue(homeView.contains("selectedPetEmptyStateCard"), "HomeView should render empty state card for selected pet")
assertTrue(homeView.contains("전체 기록 보기"), "HomeView should expose all-records CTA")

assertTrue(walkListView.contains("filteredEmptyStateCard"), "WalkListView should render filtered empty state card")
assertTrue(walkListView.contains("emptyHistoryCard"), "WalkListView should render default empty history card")
assertTrue(walkListView.contains("기준으로 돌아가기"), "WalkListView should expose restore-to-selected context action")

assertTrue(uxDoc.contains("선택 반려견 기준"), "UX doc should describe selected pet context badge")
assertTrue(uxDoc.contains("전체 기록 보기"), "UX doc should describe all-records CTA")
assertTrue(readme.contains("docs/pet-context-badge-empty-state-v1.md"), "README should reference context badge UX doc")

print("PASS: pet context badge/empty-state unit checks")
