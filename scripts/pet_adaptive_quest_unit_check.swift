import Foundation

enum AgeBand {
    case puppy
    case adult
    case senior
    case unknown
}

enum ActivityLevel {
    case low
    case moderate
    case high
}

enum FrequencyBand {
    case sparse
    case steady
    case frequent
}

func ageBand(from ageYears: Int?) -> AgeBand {
    guard let ageYears else { return .unknown }
    if ageYears <= 1 { return .puppy }
    if ageYears >= 10 { return .senior }
    return .adult
}

func activityLevel(from recentDailyMinutes: Double) -> ActivityLevel {
    if recentDailyMinutes < 20 { return .low }
    if recentDailyMinutes > 65 { return .high }
    return .moderate
}

func frequencyBand(from weeklyWalkCount: Double) -> FrequencyBand {
    if weeklyWalkCount < 3 { return .sparse }
    if weeklyWalkCount > 10 { return .frequent }
    return .steady
}

func difficultyMultiplier(
    ageBand: AgeBand,
    activityLevel: ActivityLevel,
    frequencyBand: FrequencyBand,
    previous: Double?,
    maxDailyDelta: Double = 0.15
) -> Double {
    var value = 1.0

    switch ageBand {
    case .puppy: value -= 0.08
    case .senior: value -= 0.12
    case .adult, .unknown: break
    }

    switch activityLevel {
    case .low: value -= 0.12
    case .high: value += 0.10
    case .moderate: break
    }

    switch frequencyBand {
    case .sparse: value -= 0.08
    case .frequent: value += 0.08
    case .steady: break
    }

    value = min(max(0.75, value), 1.25)

    if let previous {
        let lower = previous - maxDailyDelta
        let upper = previous + maxDailyDelta
        value = min(max(lower, value), upper)
    }

    return min(max(0.75, value), 1.25)
}

func easyDayCanActivate(usedToday: Bool) -> Bool {
    !usedToday
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
let spec = load("docs/pet-adaptive-quest-difficulty-v1.md")
let report = load("docs/cycle-147-pet-adaptive-quest-report-2026-02-27.md")
let indoorSpec = load("docs/indoor-weather-mission-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let readme = load("README.md")

assertTrue(homeVM.contains("IndoorMissionPetContext"), "home vm should define pet context")
assertTrue(homeVM.contains("resolveDifficultySummary"), "home vm should resolve adaptive difficulty summary")
assertTrue(homeVM.contains("maxDailyDifficultyDelta = 0.15"), "home vm should define daily difficulty delta cap")
assertTrue(homeVM.contains("activateEasyDayMode"), "home vm should support easy day activation")
assertTrue(homeVM.contains("easyDayRewardScale = 0.80"), "home vm should apply 20% reward reduction for easy day")

assertTrue(homeView.contains("쉬운 날 모드 사용"), "home view should render easy day action")
assertTrue(homeView.contains("최근 난이도 히스토리"), "home view should render difficulty history")
assertTrue(homeView.contains("기준 난이도"), "home view should render difficulty summary text")

assertTrue(metrics.contains("indoor_mission_difficulty_adjusted"), "metrics should include adaptive difficulty event")
assertTrue(metrics.contains("indoor_mission_easy_day_activated"), "metrics should include easy day activation event")
assertTrue(metrics.contains("indoor_mission_easy_day_rejected"), "metrics should include easy day rejection event")

assertTrue(spec.contains("일일 최대 변동폭"), "spec should define max daily difficulty delta")
assertTrue(spec.contains("쉬운 날 모드"), "spec should define easy day mode")
assertTrue(spec.contains("다견"), "spec should describe selected pet context")
assertTrue(indoorSpec.contains("반려견 맞춤 난이도"), "indoor mission spec should include adaptive difficulty section")
assertTrue(checklist.contains("쉬운 날 모드"), "checklist should include easy day regression")
assertTrue(readme.contains("docs/pet-adaptive-quest-difficulty-v1.md"), "README should reference adaptive difficulty spec")
assertTrue(report.contains("Issue: `#147"), "cycle report should reference issue 147")

let lowSenior = difficultyMultiplier(
    ageBand: ageBand(from: 12),
    activityLevel: activityLevel(from: 12),
    frequencyBand: frequencyBand(from: 2),
    previous: nil
)
assertTrue(lowSenior < 1.0, "senior + low activity + sparse walk should reduce difficulty")

let highActive = difficultyMultiplier(
    ageBand: ageBand(from: 4),
    activityLevel: activityLevel(from: 80),
    frequencyBand: frequencyBand(from: 12),
    previous: nil
)
assertTrue(highActive > 1.0, "adult + high activity + frequent walk should increase difficulty")

let clamped = difficultyMultiplier(
    ageBand: .senior,
    activityLevel: .low,
    frequencyBand: .sparse,
    previous: 1.20
)
assertTrue(clamped >= 1.05, "daily delta cap should prevent drop larger than 0.15 from previous day")

assertTrue(easyDayCanActivate(usedToday: false), "easy day should be available once per day")
assertTrue(easyDayCanActivate(usedToday: true) == false, "easy day should be blocked after first use on same day")

print("PASS: pet adaptive quest unit checks")
