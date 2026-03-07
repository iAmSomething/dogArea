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

let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let startModal = load("dogArea/Views/MapView/StartModalView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapSetting = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let alertConfig = load("dogArea/Views/GlobalViews/AlertView/CustomAlertConfigure.swift")
let userDefaultsSetting = loadMany([
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
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(startButton.contains("walkStartCountdownEnabled"), "start button should branch by countdown setting")
assertTrue(startButton.contains("viewModel.startWalkNow()"), "start flow should support immediate start")
assertTrue(startButton.contains("customThreeButton"), "stop flow should use explicit three-action alert")
assertTrue(startButton.contains("저장 후 종료"), "stop flow should expose save-and-exit as the primary alert action")
assertTrue(startButton.contains("계속 걷기"), "stop flow should keep continue walking as the secondary alert action")
assertTrue(startButton.contains("기록 폐기"), "stop flow should expose discard action")
assertTrue(startButton.contains("discardCurrentWalk"), "stop flow should support discard")
assertTrue(startButton.contains("DispatchQueue.main.asyncAfter") == false, "start flow must not use fixed delayed start")

assertTrue(startModal.contains("Button(\"취소\")"), "countdown modal should provide cancel action")
assertTrue(startModal.contains("onCompleted"), "countdown modal should accept completion callback")

assertTrue(mapView.contains("onCompleted: { viewModel.startWalkNow() }"), "map view should start walk from countdown completion")
assertTrue(mapSetting.contains("시작 카운트다운"), "map settings should expose countdown toggle")

assertTrue(mapViewModel.contains("toggleWalkStartCountdown"), "view model should expose countdown toggle")
assertTrue(mapViewModel.contains("func discardCurrentWalk()"), "view model should support walk discard")
assertTrue(alertConfig.contains("threeButtonChoice"), "alert config should support three-button layout")

assertTrue(userDefaultsSetting.contains("walkStartCountdownEnabled"), "user defaults should persist countdown setting")

assertTrue(checklist.contains("시작 카운트다운 OFF"), "release checklist should include countdown-off scenario")
assertTrue(checklist.contains("종료 3액션"), "release checklist should include stop 3-action scenario")

print("PASS: walk start/stop UX unit checks")
