import Foundation

enum ExtensionState: String {
    case none
    case active
    case consumed
    case expired
    case cooldown
}

struct ExtensionDecision {
    let state: ExtensionState
    let missionId: String?
    let rewardScale: Double
}

func decideExtension(
    previousDayHadExtension: Bool,
    previousDayExtensionCompleted: Bool,
    previousDayUnfinishedMissionIds: [String],
    rewardScale: Double = 0.70
) -> ExtensionDecision {
    if previousDayHadExtension {
        return ExtensionDecision(
            state: previousDayExtensionCompleted ? .cooldown : .expired,
            missionId: nil,
            rewardScale: rewardScale
        )
    }

    if let missionId = previousDayUnfinishedMissionIds.first {
        return ExtensionDecision(state: .active, missionId: missionId, rewardScale: rewardScale)
    }

    return ExtensionDecision(state: .none, missionId: nil, rewardScale: rewardScale)
}

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
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/Cards/HomeIndoorMissionRowView.swift"
])
let metrics = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let spec = load("docs/quest-failure-buffer-v1.md")
let indoorSpec = load("docs/indoor-weather-mission-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let readme = load("README.md")
let cycleReport = load("docs/cycle-148-quest-failure-buffer-report-2026-02-27.md")

assertTrue(homeVM.contains("IndoorMissionExtensionState"), "home vm should define extension state enum")
assertTrue(homeVM.contains("extensionRewardScale = 0.70"), "home vm should define extension reward scale 70%")
assertTrue(homeVM.contains("resolveExtensionEntry"), "home vm should resolve extension slot state")
assertTrue(homeVM.contains("markExtensionConsumedIfNeeded"), "home vm should handle extension consumed state")
assertTrue(homeVM.contains("streakEligibleOverride: false"), "extension mission should disable streak eligibility")

assertTrue(homeView.contains("연장 슬롯"), "home view should render extension badge")
assertTrue(homeView.contains("보상 70%"), "home view should explain reduced extension reward")

assertTrue(metrics.contains("indoor_mission_extension_applied"), "metrics should include extension applied event")
assertTrue(metrics.contains("indoor_mission_extension_consumed"), "metrics should include extension consumed event")
assertTrue(metrics.contains("indoor_mission_extension_expired"), "metrics should include extension expired event")
assertTrue(metrics.contains("indoor_mission_extension_blocked"), "metrics should include extension blocked event")

assertTrue(spec.contains("자동 연장 슬롯"), "spec should describe auto extension slot")
assertTrue(spec.contains("70%"), "spec should define reward reduction ratio")
assertTrue(spec.contains("연속 2일"), "spec should define consecutive-day limit")
assertTrue(spec.contains("소멸"), "spec should define expiration behavior")
assertTrue(indoorSpec.contains("실패 완충 연장 슬롯"), "indoor mission spec should link extension policy")
assertTrue(checklist.contains("자동 연장 슬롯"), "release checklist should include extension regression checks")
assertTrue(readme.contains("docs/quest-failure-buffer-v1.md"), "README should reference extension policy doc")
assertTrue(cycleReport.contains("Issue: `#148"), "cycle report should reference issue 148")

let active = decideExtension(
    previousDayHadExtension: false,
    previousDayExtensionCompleted: false,
    previousDayUnfinishedMissionIds: ["indoor.training.check", "indoor.record.cleanup"]
)
assertTrue(active.state == .active, "unfinished mission should allocate extension slot")
assertTrue(active.missionId == "indoor.training.check", "extension should pick first unfinished mission")
assertTrue(abs(active.rewardScale - 0.70) < 0.0001, "extension reward scale should be 70%")

let cooldown = decideExtension(
    previousDayHadExtension: true,
    previousDayExtensionCompleted: true,
    previousDayUnfinishedMissionIds: ["indoor.petcare.check"]
)
assertTrue(cooldown.state == .cooldown, "consecutive extension should enter cooldown when previous extension completed")
assertTrue(cooldown.missionId == nil, "cooldown state should not allocate mission")

let expired = decideExtension(
    previousDayHadExtension: true,
    previousDayExtensionCompleted: false,
    previousDayUnfinishedMissionIds: ["indoor.petcare.check"]
)
assertTrue(expired.state == .expired, "uncompleted previous extension should expire")
assertTrue(expired.missionId == nil, "expired state should not allocate mission")

let none = decideExtension(
    previousDayHadExtension: false,
    previousDayExtensionCompleted: false,
    previousDayUnfinishedMissionIds: []
)
assertTrue(none.state == .none, "no unfinished mission should result in no extension")

print("PASS: quest failure buffer unit checks")
