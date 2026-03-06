import Foundation

enum RiskLevel: Int, CaseIterable {
    case clear = 0
    case caution = 1
    case bad = 2
    case severe = 3

    var downgradedByFeedback: RiskLevel {
        switch self {
        case .severe: return .bad
        case .bad: return .caution
        case .caution: return .caution
        case .clear: return .clear
        }
    }
}

struct FeedbackEngine {
    let weeklyLimit: Int

    func remainingQuota(timestamps: [Date], now: Date, calendar: Calendar) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return weeklyLimit
        }
        let used = timestamps.filter { interval.contains($0) }.count
        return max(0, weeklyLimit - used)
    }

    func applyFeedback(base: RiskLevel, timestamps: [Date], now: Date, calendar: Calendar) -> (accepted: Bool, adjusted: RiskLevel, remaining: Int) {
        let remaining = remainingQuota(timestamps: timestamps, now: now, calendar: calendar)
        guard remaining > 0 else {
            return (false, base, 0)
        }
        let adjusted = base.downgradedByFeedback
        return (true, adjusted, max(0, remaining - 1))
    }
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
let spec = load("docs/weather-feedback-loop-v1.md")
let indoorSpec = load("docs/indoor-weather-mission-v1.md")
let migration = load("supabase/migrations/20260227203000_weather_feedback_kpis.sql")

assertTrue(homeVM.contains("submitWeatherMismatchFeedback"), "home vm should expose weather mismatch feedback action")
assertTrue(homeVM.contains("weatherFeedbackRemainingCount"), "home vm should track remaining weather feedback quota")
assertTrue(homeVM.contains("weeklyFeedbackLimit = 2"), "home vm store should enforce weekly feedback limit")
assertTrue(homeVM.contains("severe") && homeVM.contains("bad") && homeVM.contains("caution"), "home vm should downgrade severe/bad risks")

assertTrue(homeView.contains("체감 날씨 다름"), "home view should render one-tap weather mismatch action")
assertTrue(homeView.contains("주간 남은 반영"), "home view should show remaining weekly feedback quota")

assertTrue(metrics.contains("weather_feedback_submitted"), "metric enum should include weather feedback submitted event")
assertTrue(metrics.contains("weather_feedback_rate_limited"), "metric enum should include weather feedback rate-limit event")
assertTrue(metrics.contains("weather_risk_reevaluated"), "metric enum should include weather risk reevaluation event")

assertTrue(spec.contains("주간 제한: `2회`"), "weather feedback spec should include weekly limit")
assertTrue(spec.contains("완전 해제"), "weather feedback spec should forbid full clear by feedback")
assertTrue(indoorSpec.contains("weather-feedback-loop-v1.md"), "indoor weather spec should link weather feedback loop doc")
assertTrue(migration.contains("view_weather_feedback_kpis_7d"), "migration should expose weather feedback KPI view")
assertTrue(migration.contains("weather_feedback_submitted"), "migration should aggregate submitted feedback metric")

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let now = Date(timeIntervalSince1970: 1_771_000_000)
let engine = FeedbackEngine(weeklyLimit: 2)

let first = engine.applyFeedback(base: .severe, timestamps: [], now: now, calendar: calendar)
assertTrue(first.accepted, "first feedback this week should be accepted")
assertTrue(first.adjusted == .bad, "severe should downgrade to bad")
assertTrue(first.remaining == 1, "remaining quota should decrease after accepted feedback")

let second = engine.applyFeedback(base: .bad, timestamps: [now], now: now.addingTimeInterval(60), calendar: calendar)
assertTrue(second.accepted, "second feedback this week should be accepted")
assertTrue(second.adjusted == .caution, "bad should downgrade to caution")
assertTrue(second.remaining == 0, "remaining quota should reach zero after second feedback")

let third = engine.applyFeedback(base: .bad, timestamps: [now, now.addingTimeInterval(120)], now: now.addingTimeInterval(180), calendar: calendar)
assertTrue(third.accepted == false, "third feedback in same week should be rate-limited")
assertTrue(third.adjusted == .bad, "rate-limited feedback should not change risk")

let caution = engine.applyFeedback(base: .caution, timestamps: [], now: now, calendar: calendar)
assertTrue(caution.adjusted == .caution, "feedback should not fully clear caution risk")

print("PASS: weather feedback loop unit checks")
