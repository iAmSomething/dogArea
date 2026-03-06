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

let homeVM = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let metrics = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let spec = load("docs/indoor-weather-mission-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(homeVM.contains("IndoorWeatherRiskLevel"), "home vm should define weather risk level")
assertTrue(homeVM.contains("IndoorMissionTemplate"), "home vm should define indoor mission catalog template")
assertTrue(homeVM.contains("minimumActionCount"), "home vm should enforce minimum action count field")
assertTrue(homeVM.contains("confirmCompletion("), "home vm should validate completion against minimum action")
assertTrue(homeVM.contains("recentPresentedMissionIds"), "home vm should apply repeat exposure limit")
assertTrue(homeVM.contains("resolveRiskLevel"), "home vm should resolve risk level for replacement")
assertTrue(homeVM.contains("return .caution"), "home vm should fallback to caution level when weather provider value is missing")

assertTrue(homeView.contains("악천후 실내 대체 미션"), "home view should render indoor replacement mission card")
assertTrue(homeView.contains("행동 +1"), "home view should provide action logging button")
assertTrue(homeView.contains("완료 확인"), "home view should provide completion confirmation button")

assertTrue(metrics.contains("indoor_mission_replacement_applied"), "metric enum should include indoor replacement event")
assertTrue(metrics.contains("indoor_mission_completed"), "metric enum should include indoor completion event")
assertTrue(metrics.contains("indoor_mission_completion_rejected"), "metric enum should include indoor rejection event")

assertTrue(spec.contains("악천후 단계별 치환 규칙"), "spec should define weather severity replacement rules")
assertTrue(spec.contains("반복 노출 제한"), "spec should define repeat exposure limit policy")
assertTrue(checklist.contains("실내 대체 미션"), "release checklist should include indoor replacement regression scenario")

print("PASS: indoor weather mission unit checks")
