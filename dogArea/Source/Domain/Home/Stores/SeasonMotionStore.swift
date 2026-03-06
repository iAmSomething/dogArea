//
//  SeasonMotionStore.swift
//  dogArea
//

import Foundation

enum SeasonRankTier: String, Codable, CaseIterable, Equatable {
    case rookie
    case bronze
    case silver
    case gold
    case platinum

    var title: String {
        switch self {
        case .rookie: return "Rookie"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var minimumScore: Double {
        switch self {
        case .rookie: return 0
        case .bronze: return 80
        case .silver: return 180
        case .gold: return 320
        case .platinum: return 520
        }
    }
}

struct SeasonMotionRefreshResult {
    let summary: SeasonMotionSummary
    let completedSeason: SeasonResultPresentation?
}

struct SeasonMotionRecordResult {
    let summary: SeasonMotionSummary
    let scoreDelta: Double
    let rankUp: Bool
    let shieldApplied: Bool
    let completedSeason: SeasonResultPresentation?
}

struct SeasonWalkContributionInput: Equatable {
    let sessionId: String
    let areaM2: Double
    let durationSec: Double
    let eventAt: TimeInterval
}

final class SeasonMotionStore {
    private struct State: Codable, Equatable {
        let weekKey: String
        var score: Double
        var contributionCount: Int
        var weatherShieldApplyCount: Int
        var updatedAt: TimeInterval
    }

    private struct LastCompletedSeasonState: Codable, Equatable {
        let weekKey: String
        let rankTierRawValue: String
        let totalScore: Int
        let contributionCount: Int
        let shieldApplyCount: Int
        let completedAt: TimeInterval
    }

    private struct RewardClaimState: Codable, Equatable {
        let weekKey: String
        let status: SeasonRewardClaimStatus
        let reason: String?
        let updatedAt: TimeInterval
    }

    private enum DefaultsKey {
        static let currentState = "season.motion.current.v1"
        static let lastCompletedSeason = "season.motion.lastCompletedSeason.v1"
        static let rewardClaimLedger = "season.motion.rewardClaimLedger.v1"
        static let dailyScoreLedger = "season.motion.dailyScoreLedger.v1"
        static let walkContributionLedger = "season.motion.walkContributionLedger.v1"
    }

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "YYYY-'W'ww"
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let targetScore: Double = 520
    private let defaults = UserDefaults.standard

    func refresh(now: Date, riskLevel: IndoorWeatherRiskLevel) -> SeasonMotionRefreshResult {
        let (state, completedSeason) = ensureCurrentState(now: now)
        return SeasonMotionRefreshResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            completedSeason: completedSeason
        )
    }

    func remainingTimeText(now: Date = Date()) -> String {
        let calendar = Calendar(identifier: .iso8601)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return "-"
        }
        let remaining = max(0, Int(weekInterval.end.timeIntervalSince(now)))
        if remaining <= 0 {
            return "시즌 종료"
        }
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        return "\(days)일 \(hours)시간 남음"
    }

    func loadLastCompletedSeason() -> SeasonResultPresentation? {
        guard let data = defaults.data(forKey: DefaultsKey.lastCompletedSeason),
              let decoded = try? JSONDecoder().decode(LastCompletedSeasonState.self, from: data),
              let rankTier = SeasonRankTier(rawValue: decoded.rankTierRawValue) else {
            return nil
        }

        return SeasonResultPresentation(
            weekKey: decoded.weekKey,
            rankTier: rankTier,
            totalScore: decoded.totalScore,
            contributionCount: decoded.contributionCount,
            shieldApplyCount: decoded.shieldApplyCount
        )
    }

    func rewardClaimStatus(for weekKey: String) -> SeasonRewardClaimStatus {
        rewardClaimLedger()[weekKey]?.status ?? .pending
    }

    @discardableResult
    func claimReward(for weekKey: String, cloudSyncAllowed: Bool, now: Date = Date()) -> (status: SeasonRewardClaimStatus, message: String) {
        if rewardClaimStatus(for: weekKey) == .claimed {
            return (.claimed, "이미 시즌 보상을 수령했어요.")
        }

        if cloudSyncAllowed == false {
            updateRewardClaimState(
                weekKey: weekKey,
                status: .failed,
                reason: "cloud_sync_disabled",
                now: now
            )
            return (.failed, "보상 수령 실패: 로그인/동기화 활성화 후 재수령해주세요.")
        }

        updateRewardClaimState(
            weekKey: weekKey,
            status: .claimed,
            reason: nil,
            now: now
        )
        return (.claimed, "시즌 보상 수령 완료")
    }

    func recordMissionCompletion(
        rewardPoint: Int,
        streakEligible: Bool,
        riskLevel: IndoorWeatherRiskLevel,
        now: Date = Date()
    ) -> SeasonMotionRecordResult {
        let ensured = ensureCurrentState(now: now)
        var state = ensured.0
        let completedSeason = ensured.1
        let beforeRank = rankTier(for: state.score)
        var scoreDelta = 0.0

        if streakEligible {
            scoreDelta = Double(max(1, rewardPoint))
            state.score += scoreDelta
            state.contributionCount += 1
            addDailyScore(scoreDelta, weekKey: state.weekKey, now: now)
        }

        let shieldApplied = riskLevel != .clear && streakEligible
        if shieldApplied {
            state.weatherShieldApplyCount += 1
        }

        state.updatedAt = now.timeIntervalSince1970
        persist(state)

        let afterRank = rankTier(for: state.score)
        return SeasonMotionRecordResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            scoreDelta: scoreDelta,
            rankUp: afterRank != beforeRank,
            shieldApplied: shieldApplied,
            completedSeason: completedSeason
        )
    }

    /// 이번 주 산책 세션 중 아직 반영되지 않은 항목을 시즌 점수로 누적합니다.
    func recordWalkContributions(
        sessions: [SeasonWalkContributionInput],
        riskLevel: IndoorWeatherRiskLevel,
        now: Date = Date()
    ) -> SeasonMotionRecordResult? {
        let ensured = ensureCurrentState(now: now)
        var state = ensured.0
        let completedSeason = ensured.1
        let beforeRank = rankTier(for: state.score)
        let weekKey = state.weekKey

        let sortedSessions = sessions.sorted { $0.eventAt < $1.eventAt }
        var ledger = walkContributionLedger()
        var processedIds = Set(ledger[weekKey] ?? [])
        var scoreDelta = 0.0
        var contributionDelta = 0

        for session in sortedSessions {
            let sessionId = session.sessionId.lowercased()
            guard sessionId.isEmpty == false else { continue }
            guard processedIds.contains(sessionId) == false else { continue }

            let reward = walkRewardPoint(
                areaM2: session.areaM2,
                durationSec: session.durationSec
            )
            processedIds.insert(sessionId)
            guard reward > 0 else { continue }

            let rewardAsDouble = Double(reward)
            scoreDelta += rewardAsDouble
            contributionDelta += 1
            state.score += rewardAsDouble
            state.contributionCount += 1
            addDailyScore(
                rewardAsDouble,
                weekKey: weekKey,
                now: Date(timeIntervalSince1970: session.eventAt)
            )
        }

        guard contributionDelta > 0 || completedSeason != nil else {
            return nil
        }

        state.updatedAt = now.timeIntervalSince1970
        persist(state)

        ledger[weekKey] = Array(processedIds).sorted()
        persistWalkContributionLedger(ledger)

        let afterRank = rankTier(for: state.score)
        return SeasonMotionRecordResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            scoreDelta: scoreDelta,
            rankUp: afterRank != beforeRank,
            shieldApplied: false,
            completedSeason: completedSeason
        )
    }

    private func summary(from state: State, riskLevel: IndoorWeatherRiskLevel, now: Date) -> SeasonMotionSummary {
        let score = max(0, state.score)
        let progress = min(1, max(0, score / targetScore))
        return SeasonMotionSummary(
            weekKey: state.weekKey,
            score: score,
            targetScore: targetScore,
            progress: progress,
            rankTier: rankTier(for: score),
            todayScoreDelta: dailyScore(for: state.weekKey, now: now),
            contributionCount: state.contributionCount,
            weatherShieldActive: riskLevel != .clear,
            weatherShieldApplyCount: state.weatherShieldApplyCount
        )
    }

    private func rankTier(for score: Double) -> SeasonRankTier {
        if score >= SeasonRankTier.platinum.minimumScore {
            return .platinum
        }
        if score >= SeasonRankTier.gold.minimumScore {
            return .gold
        }
        if score >= SeasonRankTier.silver.minimumScore {
            return .silver
        }
        if score >= SeasonRankTier.bronze.minimumScore {
            return .bronze
        }
        return .rookie
    }

    private func ensureCurrentState(now: Date) -> (State, SeasonResultPresentation?) {
        let weekKey = currentWeekKey(for: now)
        guard var current = loadCurrentState() else {
            let newState = State(
                weekKey: weekKey,
                score: 0,
                contributionCount: 0,
                weatherShieldApplyCount: 0,
                updatedAt: now.timeIntervalSince1970
            )
            persist(newState)
            return (newState, nil)
        }

        if current.weekKey == weekKey {
            return (current, nil)
        }

        let completedSeason = SeasonResultPresentation(
            weekKey: current.weekKey,
            rankTier: rankTier(for: current.score),
            totalScore: Int(current.score.rounded()),
            contributionCount: current.contributionCount,
            shieldApplyCount: current.weatherShieldApplyCount
        )
        if completedSeason.totalScore > 0 || completedSeason.contributionCount > 0 {
            persistLastCompletedSeason(completedSeason, completedAt: now)
            ensureRewardPending(weekKey: completedSeason.weekKey, now: now)
        }

        current = State(
            weekKey: weekKey,
            score: 0,
            contributionCount: 0,
            weatherShieldApplyCount: 0,
            updatedAt: now.timeIntervalSince1970
        )
        persist(current)
        return (current, completedSeason.totalScore > 0 || completedSeason.contributionCount > 0 ? completedSeason : nil)
    }

    private func currentWeekKey(for date: Date) -> String {
        Self.weekFormatter.string(from: date)
    }

    private func loadCurrentState() -> State? {
        guard let data = defaults.data(forKey: DefaultsKey.currentState),
              let decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func persist(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: DefaultsKey.currentState)
    }

    private func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func dailyLedgerEntryKey(weekKey: String, dayKey: String) -> String {
        "\(weekKey)|\(dayKey)"
    }

    private func walkContributionLedger() -> [String: [String]] {
        guard let data = defaults.data(forKey: DefaultsKey.walkContributionLedger),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistWalkContributionLedger(_ ledger: [String: [String]]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(16))
        let trimmed = ledger
            .filter { keysToKeep.contains($0.key) }
            .mapValues { Array(Set($0)).sorted() }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.walkContributionLedger)
    }

    /// 산책 1세션의 면적/시간을 점수로 환산합니다.
    private func walkRewardPoint(areaM2: Double, durationSec: Double) -> Int {
        let safeArea = max(0, areaM2)
        let safeDuration = max(0, durationSec)
        var score = 8
        if safeArea >= 2_000 { score += 4 }
        if safeArea >= 8_000 { score += 4 }
        if safeDuration >= 1_200 { score += 2 }    // 20분
        if safeDuration >= 2_400 { score += 2 }    // 40분
        return min(24, max(4, score))
    }

    private func dailyScoreLedger() -> [String: Double] {
        guard let data = defaults.data(forKey: DefaultsKey.dailyScoreLedger),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistDailyScoreLedger(_ ledger: [String: Double]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(84))
        let trimmed = ledger.filter { keysToKeep.contains($0.key) }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.dailyScoreLedger)
    }

    private func dailyScore(for weekKey: String, now: Date) -> Int {
        let key = dailyLedgerEntryKey(weekKey: weekKey, dayKey: dayKey(for: now))
        return Int((dailyScoreLedger()[key] ?? 0).rounded())
    }

    private func addDailyScore(_ delta: Double, weekKey: String, now: Date) {
        guard delta > 0 else { return }
        let key = dailyLedgerEntryKey(weekKey: weekKey, dayKey: dayKey(for: now))
        var ledger = dailyScoreLedger()
        ledger[key, default: 0] += delta
        persistDailyScoreLedger(ledger)
    }

    private func persistLastCompletedSeason(_ result: SeasonResultPresentation, completedAt: Date) {
        let encodedState = LastCompletedSeasonState(
            weekKey: result.weekKey,
            rankTierRawValue: result.rankTier.rawValue,
            totalScore: result.totalScore,
            contributionCount: result.contributionCount,
            shieldApplyCount: result.shieldApplyCount,
            completedAt: completedAt.timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(encodedState) else { return }
        defaults.set(data, forKey: DefaultsKey.lastCompletedSeason)
    }

    private func rewardClaimLedger() -> [String: RewardClaimState] {
        guard let data = defaults.data(forKey: DefaultsKey.rewardClaimLedger),
              let decoded = try? JSONDecoder().decode([String: RewardClaimState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistRewardClaimLedger(_ ledger: [String: RewardClaimState]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(20))
        let trimmed = ledger.filter { keysToKeep.contains($0.key) }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.rewardClaimLedger)
    }

    private func ensureRewardPending(weekKey: String, now: Date) {
        let current = rewardClaimLedger()[weekKey]
        guard current == nil else { return }
        updateRewardClaimState(
            weekKey: weekKey,
            status: .pending,
            reason: nil,
            now: now
        )
    }

    private func updateRewardClaimState(
        weekKey: String,
        status: SeasonRewardClaimStatus,
        reason: String?,
        now: Date
    ) {
        var ledger = rewardClaimLedger()
        ledger[weekKey] = RewardClaimState(
            weekKey: weekKey,
            status: status,
            reason: reason,
            updatedAt: now.timeIntervalSince1970
        )
        persistRewardClaimLedger(ledger)
    }
}
