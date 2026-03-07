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

let userDefaults = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift",
    "dogArea/Source/ProfileStore.swift",
    "dogArea/Source/PetSelectionStore.swift"
])
let homeVM = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let settingVM = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let notificationView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let mapVM = loadMany([
    "dogArea/Views/MapView/MapViewModel.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift"
])
let walkListVM = load("dogArea/Views/WalkListView/WalkListViewModel.swift")
let specDoc = load("docs/multi-dog-selection-ux-v1.md")

assertTrue(userDefaults.contains("var isActive: Bool = true"), "PetInfo should persist activation state")
assertTrue(userDefaults.contains("let activePets = pet.filter(\\.isActive)"), "selected pet resolution should prefer active pets")
assertTrue(userDefaults.contains("current.pet.contains(where: { $0.petId == petId && $0.isActive })"), "pet selection store should block inactive pet selection")

assertTrue(homeVM.contains("userInfo?.pet.filter(\\.isActive)"), "home should expose only active pets for selection")
assertTrue(walkListVM.contains("userInfo?.pet.filter(\\.isActive)"), "walk list should expose only active pets for selection")
assertTrue(mapVM.contains("userInfo?.pet.filter(\\.isActive)"), "map should expose only active pets for walk selection")

assertTrue(settingVM.contains("var activePets: [PetInfo]"), "settings should expose active pet collection")
assertTrue(settingVM.contains("var inactivePets: [PetInfo]"), "settings should expose inactive pet collection")
assertTrue(notificationView.contains("settings.pet.manage"), "settings should expose pet management entry point")
assertTrue(notificationView.contains("비활성 반려견"), "settings should surface inactive pet summary")

assertTrue(specDoc.contains("선택값이 비어있거나 유효하지 않으면 첫 활성 반려견으로 보정"), "spec should require active pet fallback")

print("PASS: multi-dog selection UX unit checks")
