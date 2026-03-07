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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let areaProgress = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift")
let doc = load("docs/home-refresh-entrypoint-v1.md")
let readme = load("README.md")

assertTrue(homeLifecycle.contains("private enum HomeRefreshTrigger"), "home lifecycle should define a refresh trigger model")
assertTrue(homeLifecycle.contains("func performInitialRefresh"), "home lifecycle should expose an initial refresh entrypoint")
assertTrue(homeLifecycle.contains("func refreshForVisibleReentry"), "home lifecycle should expose a visible reentry refresh entrypoint")
assertTrue(homeLifecycle.contains("func refreshForAppResumeIfNeeded"), "home lifecycle should expose an app resume refresh entrypoint")
assertTrue(homeLifecycle.contains("func refreshForSelectedPetChange"), "home lifecycle should expose a pet selection refresh entrypoint")
assertTrue(homeLifecycle.contains("applySelectedPetStatistics(\n            shouldUpdateMeter: trigger.shouldUpdateMeter,\n            refreshDerivedContent: false,"), "refresh coordinator should disable duplicate derived refresh during aggregation")
assertTrue(homeLifecycle.contains("guard source != \"home\" else { return }"), "home-selected pet notifications should ignore self-originated events")
assertTrue(homeLifecycle.contains("executeRefresh(trigger: .timeBoundaryChange"), "time boundary changes should reuse the shared refresh coordinator")

assertTrue(areaProgress.contains("refreshDerivedContent: Bool = true"), "area progress aggregation should support opt-out of derived refresh")
assertTrue(areaProgress.contains("if refreshDerivedContent {"), "area progress aggregation should guard derived refresh execution")

assertTrue(homeView.contains("@Environment(\\.scenePhase) private var scenePhase"), "home view should observe scene phase for app resume refresh")
assertTrue(homeView.contains("viewModel.refreshForVisibleReentry()"), "home view should refresh through visible reentry entrypoint")
assertTrue(homeView.contains("viewModel.refreshForAppResumeIfNeeded()"), "home view should refresh through app resume entrypoint")
assertTrue(homeView.contains(".onDisappear {"), "home view should track visibility around appearance changes")
assertTrue(homeViewModel.contains("performInitialRefresh()"), "home view model init should use the dedicated initial refresh entrypoint")

[
    "홈 최초 진입",
    "홈 재노출(탭 복귀)",
    "앱 복귀(홈 visible)",
    "당겨서 새로고침",
    "pet 전환(home source)",
    "각 4회",
    "각 2회",
    "각 1회"
].forEach { needle in
    assertTrue(doc.contains(needle), "home refresh doc should include \(needle)")
}

assertTrue(readme.contains("docs/home-refresh-entrypoint-v1.md"), "README should index the home refresh entrypoint doc")

print("PASS: home refresh entrypoint unit checks")
