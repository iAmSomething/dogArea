//
//  IndoorMissionStore.swift
//  dogArea
//

import Foundation

enum IndoorMissionCompletionResult {
    case completed
    case insufficientAction(actionCount: Int, required: Int)
    case alreadyCompleted
}

final class IndoorMissionStore {
    private struct IndoorMissionExtensionEntry: Codable, Equatable {
        let dayKey: String
        let sourceDayKey: String?
        let missionId: String?
        let rewardScale: Double
        var state: IndoorMissionExtensionState

        var hasAllocation: Bool {
            guard let sourceDayKey, sourceDayKey.isEmpty == false,
                  let missionId, missionId.isEmpty == false else {
                return false
            }
            return true
        }
    }

    private struct IndoorMissionDifficultyLedgerEntry: Codable, Equatable {
        let dayKey: String
        let petId: String
        let petName: String
        let ageBand: IndoorMissionPetAgeBand
        let activityLevel: IndoorMissionActivityLevel
        let walkFrequency: IndoorMissionWalkFrequencyBand
        let multiplier: Double
        let reasons: [String]
        let easyDayApplied: Bool
        let updatedAt: TimeInterval
    }

    enum EasyDayActivationOutcome {
        case activated
        case alreadyUsed
        case missingPet
    }

    private enum DefaultsKey {
        static let weatherRiskOverride = "weather.risk.level.v1"
        static let weatherRiskObservedAt = "weather.risk.observed_at.v1"
        static let actionCounts = "indoor.mission.actionCounts.v1"
        static let completionFlags = "indoor.mission.completed.v1"
        static let exposureHistory = "indoor.mission.exposureHistory.v1"
        static let weatherFeedbackTimestamps = "weather.feedback.timestamps.v1"
        static let weatherFeedbackDailyAdjustment = "weather.feedback.dailyAdjustment.v1"
        static let weatherShieldUsage = "weather.shield.usage.v1"
        static let extensionLedger = "indoor.mission.extensionLedger.v1"
        static let easyDayUsage = "indoor.mission.easyDayUsage.v1"
        static let difficultyLedger = "indoor.mission.difficultyLedger.v1"
    }

    let weeklyFeedbackLimit = 2
    let extensionRewardScale = 0.70
    let easyDayRewardScale = 0.80
    let maxDailyDifficultyDelta = 0.15

    private let calendar: Calendar = {
        var value = Calendar.autoupdatingCurrent
        value.timeZone = TimeZone.autoupdatingCurrent
        return value
    }()
    private let weatherSnapshotStore: WeatherSnapshotStoreProtocol

    private let templates: [IndoorMissionTemplate] = [
        .init(
            id: "indoor.record.cleanup",
            category: .recordCleanup,
            title: "기록 정리 체크",
            description: "산책 기록/사진/메모 정리를 3회 진행해요.",
            minimumActionCount: 3,
            baseRewardPoint: 40,
            streakEligible: true
        ),
        .init(
            id: "indoor.petcare.check",
            category: .petCareCheck,
            title: "펫 케어 루틴 체크",
            description: "물/브러싱/컨디션 체크를 2회 진행해요.",
            minimumActionCount: 2,
            baseRewardPoint: 32,
            streakEligible: true
        ),
        .init(
            id: "indoor.training.check",
            category: .trainingCheck,
            title: "실내 훈련 체크",
            description: "기다려/손/하우스 훈련을 4회 수행해요.",
            minimumActionCount: 4,
            baseRewardPoint: 48,
            streakEligible: true
        ),
        .init(
            id: "indoor.record.photo_sort",
            category: .recordCleanup,
            title: "사진 정리 체크",
            description: "최근 산책 사진 분류/삭제/보관을 2회 진행해요.",
            minimumActionCount: 2,
            baseRewardPoint: 28,
            streakEligible: true
        ),
        .init(
            id: "indoor.training.focus",
            category: .trainingCheck,
            title: "집중 훈련 체크",
            description: "10초 집중 유지 훈련을 3회 진행해요.",
            minimumActionCount: 3,
            baseRewardPoint: 36,
            streakEligible: true
        )
    ]

    /// 실내 미션 저장소를 생성합니다.
    /// - Parameter weatherSnapshotStore: 홈/맵과 공유하는 최신 날씨 스냅샷 저장소입니다.
    init(weatherSnapshotStore: WeatherSnapshotStoreProtocol = WeatherSnapshotStore.shared) {
        self.weatherSnapshotStore = weatherSnapshotStore
    }

    func buildBoard(now: Date) -> IndoorMissionBoard {
        buildBoard(now: now, context: nil, weatherStatus: nil, serverSummary: nil)
    }

    func buildBoard(now: Date, context: IndoorMissionPetContext?) -> IndoorMissionBoard {
        buildBoard(now: now, context: context, weatherStatus: nil, serverSummary: nil)
    }

    /// 서버 canonical summary snapshot을 홈 카드용 보드 모델로 변환합니다.
    /// - Parameter summary: 서버가 최종 확정한 실내 미션 summary snapshot입니다.
    /// - Returns: 홈 UI가 그대로 소비할 수 있는 실내 미션 보드입니다.
    func buildBoard(from summary: IndoorMissionCanonicalSummarySnapshot) -> IndoorMissionBoard {
        let missions = summary.missions.map { mission in
            let minimumActionCount = max(1, mission.minimumActionCount)
            return IndoorMissionCardModel(
                id: mission.missionInstanceId,
                category: resolvedMissionCategory(from: mission.categoryRawValue),
                title: mission.title,
                description: mission.description,
                minimumActionCount: minimumActionCount,
                rewardPoint: max(0, mission.rewardPoint),
                streakEligible: mission.streakEligible,
                trackingMissionId: mission.templateId,
                dayKey: mission.trackingDayKey,
                isExtension: mission.isExtension,
                extensionSourceDayKey: mission.extensionSourceDayKey,
                extensionRewardScale: mission.extensionRewardScale,
                progress: .init(
                    actionCount: max(0, mission.actionCount),
                    minimumActionCount: minimumActionCount,
                    isCompleted: mission.claimedAt != nil || mission.statusRawValue == "claimed"
                ),
                canonicalMissionInstanceId: mission.missionInstanceId,
                claimable: mission.claimable,
                rewardEligible: mission.rewardEligible,
                source: .serverCanonical
            )
        }

        return .init(
            riskLevel: summary.effectiveRiskLevel,
            dayKey: summary.dayKey,
            missions: missions,
            extensionState: resolvedExtensionState(from: summary.extensionStateRawValue),
            extensionMessage: summary.extensionMessage,
            difficultySummary: makeDifficultySummary(from: summary.difficultySummary),
            source: .serverCanonical
        )
    }

    /// 서버 canonical summary를 우선 반영해 실내 미션 보드를 생성합니다.
    /// - Parameters:
    ///   - now: 보드 집계 기준 시각입니다.
    ///   - context: 선택 반려견 기반 난이도 컨텍스트입니다.
    ///   - weatherStatus: 이미 계산된 날씨 상태가 있으면 재사용합니다.
    ///   - serverSummary: 서버가 확정한 날씨 canonical summary입니다. 없으면 로컬 fallback 상태를 사용합니다.
    /// - Returns: 홈 실내 미션 카드 렌더링에 사용할 실내 미션 보드입니다.
    func buildBoard(
        now: Date,
        context: IndoorMissionPetContext?,
        weatherStatus: IndoorWeatherStatus?,
        serverSummary: WeatherReplacementSummarySnapshot?
    ) -> IndoorMissionBoard {
        let resolvedWeatherStatus = weatherStatus ?? self.weatherStatus(now: now, serverSummary: serverSummary)
        let riskLevel = resolvedWeatherStatus.adjustedRisk
        let dayKey = dayStamp(for: now)
        let difficultySummary = resolveDifficultySummary(
            context: context,
            dayKey: dayKey,
            now: now
        )
        let easyDayRewardMultiplier = difficultySummary?.easyDayState == .active ? easyDayRewardScale : 1.0
        let selectedTemplates: [IndoorMissionTemplate]
        if riskLevel.replacementMissionCount > 0 {
            selectedTemplates = selectedTemplatesForToday(riskLevel: riskLevel, dayKey: dayKey)
        } else {
            selectedTemplates = []
        }
        let missions = selectedTemplates.map { template in
            makeCardModel(
                template: template,
                riskLevel: riskLevel,
                dayKey: dayKey,
                difficultyMultiplier: difficultySummary?.appliedMultiplier ?? 1.0,
                rewardScale: easyDayRewardMultiplier
            )
        }
        let extensionEntry = resolveExtensionEntry(dayKey: dayKey)
        var combinedMissions = missions
        if let extensionMission = makeExtensionCardModel(
            entry: extensionEntry,
            riskLevel: riskLevel,
            difficultyMultiplier: difficultySummary?.appliedMultiplier ?? 1.0,
            easyDayRewardScale: easyDayRewardMultiplier
        ) {
            combinedMissions.insert(extensionMission, at: 0)
        }

        if combinedMissions.isEmpty,
           extensionEntry.state == .none,
           difficultySummary == nil {
            return .init(
                riskLevel: riskLevel,
                dayKey: dayKey,
                missions: [],
                extensionState: .none,
                extensionMessage: nil,
                difficultySummary: nil
            )
        }

        return .init(
            riskLevel: riskLevel,
            dayKey: dayKey,
            missions: combinedMissions,
            extensionState: extensionEntry.state,
            extensionMessage: extensionMessage(for: extensionEntry),
            difficultySummary: difficultySummary
        )
    }

    /// 로컬 snapshot 기반의 기본 위험도 상태를 조회합니다.
    /// - Parameter now: 관측 신선도와 fallback 여부를 판단할 기준 시각입니다.
    /// - Returns: 로컬 snapshot 기준 기본 위험도 상태이며, 클라이언트 로컬 보정은 포함하지 않습니다.
    func baseWeatherStatus(now: Date = Date()) -> IndoorWeatherStatus {
        let base = resolveCanonicalBaseRiskProfile()
        return IndoorWeatherStatus(
            source: base.source,
            baseRisk: base.risk,
            adjustedRisk: base.risk,
            lastUpdatedAt: resolveBaseObservedAt(source: base.source, now: now)
        )
    }

    func activateEasyDayMode(petId: String?, now: Date = Date()) -> EasyDayActivationOutcome {
        guard let petId, petId.isEmpty == false else { return .missingPet }
        let dayKey = dayStamp(for: now)
        let key = easyDayKey(dayKey: dayKey, petId: petId)
        var map = easyDayUsageMap()
        if map[key] != nil {
            return .alreadyUsed
        }
        map[key] = now.timeIntervalSince1970
        persistEasyDayUsageMap(map, currentDayKey: dayKey)
        return .activated
    }

    func incrementActionCount(missionId: String, dayKey: String) {
        let key = actionKey(missionId: missionId, dayKey: dayKey)
        var counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: DefaultsKey.actionCounts)
    }

    func confirmCompletion(
        missionId: String,
        dayKey: String,
        minimumActionCount: Int,
        now: Date = Date()
    ) -> IndoorMissionCompletionResult {
        let completedKey = actionKey(missionId: missionId, dayKey: dayKey)
        var completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        if completed[completedKey] != nil {
            return .alreadyCompleted
        }

        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let actionCount = counts[completedKey] ?? 0
        guard actionCount >= minimumActionCount else {
            return .insufficientAction(actionCount: actionCount, required: minimumActionCount)
        }
        completed[completedKey] = now.timeIntervalSince1970
        UserDefaults.standard.set(completed, forKey: DefaultsKey.completionFlags)
        return .completed
    }

    @discardableResult
    func markExtensionConsumedIfNeeded(_ mission: IndoorMissionCardModel, now: Date = Date()) -> Bool {
        guard mission.isExtension else { return false }
        let dayKey = dayStamp(for: now)
        var ledger = extensionLedger()
        guard var entry = ledger[dayKey], entry.hasAllocation else { return false }
        guard entry.missionId == mission.trackingMissionId else { return false }
        guard entry.state == .active else { return false }
        entry.state = .consumed
        ledger[dayKey] = entry
        persistExtensionLedger(ledger)
        return true
    }

    func updatedMissionState(_ mission: IndoorMissionCardModel) -> IndoorMissionCardModel {
        let key = actionKey(missionId: mission.trackingMissionId, dayKey: mission.dayKey)
        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]

        return .init(
            id: mission.id,
            category: mission.category,
            title: mission.title,
            description: mission.description,
            minimumActionCount: mission.minimumActionCount,
            rewardPoint: mission.rewardPoint,
            streakEligible: mission.streakEligible,
            trackingMissionId: mission.trackingMissionId,
            dayKey: mission.dayKey,
            isExtension: mission.isExtension,
            extensionSourceDayKey: mission.extensionSourceDayKey,
            extensionRewardScale: mission.extensionRewardScale,
            progress: .init(
                actionCount: counts[key] ?? 0,
                minimumActionCount: mission.minimumActionCount,
                isCompleted: completed[key] != nil
            ),
            canonicalMissionInstanceId: mission.canonicalMissionInstanceId,
            claimable: mission.claimable,
            rewardEligible: mission.rewardEligible,
            source: mission.source
        )
    }

    func weatherStatus(now: Date = Date()) -> IndoorWeatherStatus {
        let base = resolveBaseRiskProfile()
        let dayKey = dayStamp(for: now)
        let adjustment = dailyAdjustmentMap()[dayKey] ?? 0
        let adjusted = adjustedRisk(from: base.risk, step: adjustment)
        return IndoorWeatherStatus(
            source: base.source,
            baseRisk: base.risk,
            adjustedRisk: adjusted,
            lastUpdatedAt: lastWeatherAdjustmentTimestamp(now: now)
        )
    }

    /// 서버 canonical summary를 우선 적용한 날씨 상태를 조회합니다.
    /// - Parameters:
    ///   - now: 상태 기준 시각입니다.
    ///   - serverSummary: 서버가 확정한 canonical summary입니다.
    ///   - baseWeatherStatus: 이미 계산한 기본 위험도 상태가 있으면 재사용합니다.
    /// - Returns: 홈 날씨 카드와 실내 미션이 사용할 최종 날씨 상태입니다.
    func weatherStatus(
        now: Date = Date(),
        serverSummary: WeatherReplacementSummarySnapshot?,
        baseWeatherStatus: IndoorWeatherStatus? = nil
    ) -> IndoorWeatherStatus {
        guard let serverSummary else {
            return weatherStatus(now: now)
        }
        let baseStatus = baseWeatherStatus ?? self.baseWeatherStatus(now: now)
        let resolvedSource: IndoorWeatherRiskSource
        switch baseStatus.source {
        case .environment:
            resolvedSource = .environment
        case .fallback:
            resolvedSource = .fallback
        case .snapshot, .serverSummary, .userOverride:
            resolvedSource = .serverSummary
        }
        return IndoorWeatherStatus(
            source: resolvedSource,
            baseRisk: baseStatus.baseRisk,
            adjustedRisk: serverSummary.effectiveRiskLevel,
            lastUpdatedAt: serverSummary.refreshedAt
        )
    }

    func recordWeatherShieldUsage(now: Date = Date()) {
        let dayKey = dayStamp(for: now)
        var map = weatherShieldUsageMap()
        var values = map[dayKey] ?? []
        values.append(now.timeIntervalSince1970)
        map[dayKey] = values
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 14) + [dayKey])
        map = map.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(map, forKey: DefaultsKey.weatherShieldUsage)
    }

    func weatherShieldDailySummary(now: Date = Date()) -> WeatherShieldDailySummary? {
        let dayKey = dayStamp(for: now)
        let values = weatherShieldUsageMap()[dayKey] ?? []
        guard values.isEmpty == false else { return nil }
        return WeatherShieldDailySummary(
            dayKey: dayKey,
            applyCount: values.count,
            lastAppliedAtText: Self.timeFormatter.string(from: Date(timeIntervalSince1970: values.max() ?? now.timeIntervalSince1970))
        )
    }

    /// 서버 canonical summary를 우선 적용한 shield 일일 요약을 조회합니다.
    /// - Parameters:
    ///   - now: 일일 summary 기준 시각입니다.
    ///   - serverSummary: 서버가 확정한 canonical summary입니다.
    /// - Returns: 홈 shield 카드에 노출할 요약이며, 서버 값이 없으면 로컬 fallback 요약을 반환합니다.
    func weatherShieldDailySummary(
        now: Date = Date(),
        serverSummary: WeatherReplacementSummarySnapshot?
    ) -> WeatherShieldDailySummary? {
        guard let serverSummary else {
            return weatherShieldDailySummary(now: now)
        }
        guard serverSummary.shieldApplyCountToday > 0 else { return nil }
        let lastAppliedAt = serverSummary.shieldLastAppliedAt ?? now.timeIntervalSince1970
        return WeatherShieldDailySummary(
            dayKey: dayStamp(for: now),
            applyCount: serverSummary.shieldApplyCountToday,
            lastAppliedAtText: Self.timeFormatter.string(from: Date(timeIntervalSince1970: lastAppliedAt))
        )
    }

    func weatherFeedbackRemainingCount(now: Date = Date()) -> Int {
        max(0, weeklyFeedbackLimit - feedbackCountInCurrentWeek(now: now))
    }

    /// 서버 canonical summary를 우선 적용한 체감 피드백 잔여 횟수를 조회합니다.
    /// - Parameters:
    ///   - now: 주간 quota 기준 시각입니다.
    ///   - serverSummary: 서버가 확정한 canonical summary입니다.
    /// - Returns: 서버 값이 있으면 서버 기준 잔여 횟수, 없으면 로컬 fallback 잔여 횟수입니다.
    func weatherFeedbackRemainingCount(
        now: Date = Date(),
        serverSummary: WeatherReplacementSummarySnapshot?
    ) -> Int {
        guard let serverSummary else {
            return weatherFeedbackRemainingCount(now: now)
        }
        return max(0, serverSummary.feedbackRemainingCount)
    }

    /// 주어진 시각을 현재 저장소 기준 날짜 키로 변환합니다.
    /// - Parameter now: 날짜 키로 변환할 기준 시각입니다.
    /// - Returns: 저장소 내부 집계와 동일한 형식의 날짜 키입니다.
    func dayStampForPreview(now: Date) -> String {
        dayStamp(for: now)
    }

    func submitWeatherMismatchFeedback(now: Date = Date()) -> WeatherFeedbackOutcome {
        let originalRisk = resolveRiskLevel(now: now)
        let remainingBefore = weatherFeedbackRemainingCount(now: now)
        guard remainingBefore > 0 else {
            return .init(
                accepted: false,
                message: "체감 피드백은 주간 \(weeklyFeedbackLimit)회까지 반영할 수 있어요.",
                originalRisk: originalRisk,
                adjustedRisk: originalRisk,
                remainingWeeklyQuota: 0
            )
        }

        appendFeedbackTimestamp(now: now)
        let dayKey = dayStamp(for: now)

        let adjustedRisk: IndoorWeatherRiskLevel
        if originalRisk == .severe {
            adjustedRisk = .bad
        } else if originalRisk == .bad {
            adjustedRisk = .caution
        } else {
            adjustedRisk = originalRisk
        }

        let adjustmentStep = adjustmentStep(from: originalRisk, to: adjustedRisk)
        persistDailyAdjustment(dayKey: dayKey, step: adjustmentStep)

        let remainingAfter = weatherFeedbackRemainingCount(now: now)
        let message: String
        if originalRisk != adjustedRisk {
            message = "체감 피드백이 반영되어 오늘 판정을 \(adjustedRisk.displayTitle)로 재평가했어요."
        } else {
            message = "피드백은 반영했지만 안전 기준상 오늘 판정은 \(adjustedRisk.displayTitle)로 유지돼요."
        }

        return .init(
            accepted: true,
            message: message,
            originalRisk: originalRisk,
            adjustedRisk: adjustedRisk,
            remainingWeeklyQuota: remainingAfter
        )
    }

    private func makeCardModel(
        template: IndoorMissionTemplate,
        riskLevel: IndoorWeatherRiskLevel,
        dayKey: String,
        displayId: String? = nil,
        trackingMissionId: String? = nil,
        isExtension: Bool = false,
        extensionSourceDayKey: String? = nil,
        difficultyMultiplier: Double = 1.0,
        rewardScale: Double = 1.0,
        extensionScale: Double = 1.0,
        streakEligibleOverride: Bool? = nil
    ) -> IndoorMissionCardModel {
        let trackingId = trackingMissionId ?? template.id
        let key = actionKey(missionId: trackingId, dayKey: dayKey)
        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        let actionCount = counts[key] ?? 0
        let isCompleted = completed[key] != nil
        let adjustedMinimumAction = max(
            1,
            Int((Double(template.minimumActionCount) * difficultyMultiplier).rounded())
        )
        let reward = Int((Double(template.baseRewardPoint) * riskLevel.rewardScale * rewardScale * extensionScale).rounded())

        return .init(
            id: displayId ?? template.id,
            category: template.category,
            title: template.title,
            description: template.description,
            minimumActionCount: adjustedMinimumAction,
            rewardPoint: max(1, reward),
            streakEligible: streakEligibleOverride ?? template.streakEligible,
            trackingMissionId: trackingId,
            dayKey: dayKey,
            isExtension: isExtension,
            extensionSourceDayKey: extensionSourceDayKey,
            extensionRewardScale: extensionScale,
            progress: .init(
                actionCount: actionCount,
                minimumActionCount: adjustedMinimumAction,
                isCompleted: isCompleted
            )
        )
    }

    private func makeExtensionCardModel(
        entry: IndoorMissionExtensionEntry,
        riskLevel: IndoorWeatherRiskLevel,
        difficultyMultiplier: Double,
        easyDayRewardScale: Double
    ) -> IndoorMissionCardModel? {
        guard entry.state == .active || entry.state == .consumed else { return nil }
        guard let sourceDayKey = entry.sourceDayKey,
              let missionId = entry.missionId,
              let template = template(for: missionId) else {
            return nil
        }

        let displayId = "\(missionId)|extension|\(sourceDayKey)"
        return makeCardModel(
            template: template,
            riskLevel: riskLevel,
            dayKey: sourceDayKey,
            displayId: displayId,
            trackingMissionId: missionId,
            isExtension: true,
            extensionSourceDayKey: sourceDayKey,
            difficultyMultiplier: difficultyMultiplier,
            rewardScale: easyDayRewardScale,
            extensionScale: entry.rewardScale,
            streakEligibleOverride: false
        )
    }

    /// 서버가 내려준 난이도 summary snapshot을 홈 카드용 난이도 모델로 변환합니다.
    /// - Parameter summary: 서버 canonical 난이도 summary snapshot입니다.
    /// - Returns: 홈 카드가 표시할 난이도/쉬운 날 요약 모델입니다.
    private func makeDifficultySummary(
        from summary: IndoorMissionCanonicalDifficultySummarySnapshot?
    ) -> IndoorMissionDifficultySummary? {
        guard let summary else { return nil }
        return .init(
            petId: summary.petId,
            petName: summary.petName,
            ageBand: resolvedPetAgeBand(from: summary.ageBandRawValue),
            activityLevel: resolvedActivityLevel(from: summary.activityLevelRawValue),
            walkFrequency: resolvedWalkFrequency(from: summary.walkFrequencyRawValue),
            appliedMultiplier: summary.appliedMultiplier,
            adjustmentDescription: summary.adjustmentDescription,
            reasons: summary.adjustmentReasons,
            easyDayState: resolvedEasyDayState(from: summary.easyDayStateRawValue),
            easyDayMessage: summary.easyDayMessage,
            history: summary.history.map { entry in
                .init(
                    dayKey: entry.dayKey,
                    petId: entry.petId ?? "__none__",
                    petName: entry.petName,
                    multiplier: entry.multiplier,
                    ageBand: resolvedPetAgeBand(from: entry.ageBandRawValue),
                    activityLevel: resolvedActivityLevel(from: entry.activityLevelRawValue),
                    walkFrequency: resolvedWalkFrequency(from: entry.walkFrequencyRawValue),
                    easyDayApplied: entry.easyDayApplied
                )
            }
        )
    }

    /// 서버 raw category 문자열을 앱 공용 실내 미션 카테고리로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 카테고리 문자열입니다.
    /// - Returns: 홈 카드가 사용할 실내 미션 카테고리입니다.
    private func resolvedMissionCategory(from rawValue: String) -> IndoorMissionCategory {
        IndoorMissionCategory(rawValue: rawValue) ?? .recordCleanup
    }

    /// 서버 raw extension state 문자열을 앱 공용 extension 상태로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 extension state 문자열입니다.
    /// - Returns: 홈 카드가 사용할 extension 상태입니다.
    private func resolvedExtensionState(from rawValue: String) -> IndoorMissionExtensionState {
        IndoorMissionExtensionState(rawValue: rawValue) ?? .none
    }

    /// 서버 raw 연령대 문자열을 앱 공용 실내 미션 연령대 타입으로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 연령대 문자열입니다.
    /// - Returns: 홈 카드가 사용할 연령대 타입입니다.
    private func resolvedPetAgeBand(from rawValue: String) -> IndoorMissionPetAgeBand {
        IndoorMissionPetAgeBand(rawValue: rawValue) ?? .unknown
    }

    /// 서버 raw 활동량 문자열을 앱 공용 실내 미션 활동량 타입으로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 활동량 문자열입니다.
    /// - Returns: 홈 카드가 사용할 활동량 타입입니다.
    private func resolvedActivityLevel(from rawValue: String) -> IndoorMissionActivityLevel {
        IndoorMissionActivityLevel(rawValue: rawValue) ?? .moderate
    }

    /// 서버 raw 산책 빈도 문자열을 앱 공용 실내 미션 빈도 타입으로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 산책 빈도 문자열입니다.
    /// - Returns: 홈 카드가 사용할 산책 빈도 타입입니다.
    private func resolvedWalkFrequency(from rawValue: String) -> IndoorMissionWalkFrequencyBand {
        IndoorMissionWalkFrequencyBand(rawValue: rawValue) ?? .steady
    }

    /// 서버 raw 쉬운 날 상태 문자열을 앱 공용 쉬운 날 상태로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 쉬운 날 상태 문자열입니다.
    /// - Returns: 홈 카드가 사용할 쉬운 날 상태입니다.
    private func resolvedEasyDayState(from rawValue: String) -> IndoorMissionEasyDayState {
        IndoorMissionEasyDayState(rawValue: rawValue) ?? .unavailable
    }

    private func template(for missionId: String) -> IndoorMissionTemplate? {
        templates.first(where: { $0.id == missionId })
    }

    private func extensionMessage(for entry: IndoorMissionExtensionEntry) -> String? {
        switch entry.state {
        case .none:
            return nil
        case .active:
            return "전일 미션 1개를 자동 연장했어요. 완료 시 보상은 기본의 70%만 지급돼요."
        case .consumed:
            return "연장 슬롯 사용 완료. 연장 미션은 시즌 점수/연속 보상에서 제외돼요."
        case .expired:
            return "전일 연장 미션이 미완료로 소멸되어 오늘은 자동 연장이 제공되지 않아요."
        case .cooldown:
            return "연장 슬롯은 연속 2일 이상 자동 적용되지 않아요. 오늘은 쿨다운 상태예요."
        }
    }

    private func resolveExtensionEntry(dayKey: String) -> IndoorMissionExtensionEntry {
        var ledger = extensionLedger()
        if var existing = ledger[dayKey] {
            if existing.state == .active,
               let sourceDayKey = existing.sourceDayKey,
               let missionId = existing.missionId,
               isMissionCompleted(missionId: missionId, dayKey: sourceDayKey) {
                existing.state = .consumed
                ledger[dayKey] = existing
                persistExtensionLedger(ledger)
            }
            return existing
        }

        let previousDayKey = previousDayStamps(from: dayKey, count: 1).first
        guard let previousDayKey, previousDayKey.isEmpty == false else {
            let none = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: nil,
                missionId: nil,
                rewardScale: extensionRewardScale,
                state: .none
            )
            ledger[dayKey] = none
            persistExtensionLedger(ledger)
            return none
        }

        if let previousEntry = ledger[previousDayKey], previousEntry.hasAllocation {
            let wasCompleted: Bool
            if let sourceDayKey = previousEntry.sourceDayKey, let missionId = previousEntry.missionId {
                wasCompleted = isMissionCompleted(missionId: missionId, dayKey: sourceDayKey)
            } else {
                wasCompleted = false
            }
            let state: IndoorMissionExtensionState = wasCompleted ? .cooldown : .expired
            let blocked = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: nil,
                missionId: nil,
                rewardScale: extensionRewardScale,
                state: state
            )
            ledger[dayKey] = blocked
            persistExtensionLedger(ledger)
            return blocked
        }

        if let missionId = unresolvedMissionCandidate(from: previousDayKey) {
            let active = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: previousDayKey,
                missionId: missionId,
                rewardScale: extensionRewardScale,
                state: .active
            )
            ledger[dayKey] = active
            persistExtensionLedger(ledger)
            return active
        }

        let none = IndoorMissionExtensionEntry(
            dayKey: dayKey,
            sourceDayKey: nil,
            missionId: nil,
            rewardScale: extensionRewardScale,
            state: .none
        )
        ledger[dayKey] = none
        persistExtensionLedger(ledger)
        return none
    }

    private func unresolvedMissionCandidate(from dayKey: String) -> String? {
        let history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        let missionIds = history[dayKey] ?? []
        guard missionIds.isEmpty == false else { return nil }
        return missionIds.first(where: { isMissionCompleted(missionId: $0, dayKey: dayKey) == false })
    }

    private func isMissionCompleted(missionId: String, dayKey: String) -> Bool {
        let key = actionKey(missionId: missionId, dayKey: dayKey)
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        return completed[key] != nil
    }

    private func extensionLedger() -> [String: IndoorMissionExtensionEntry] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.extensionLedger) else { return [:] }
        do {
            return try JSONDecoder().decode([String: IndoorMissionExtensionEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistExtensionLedger(_ ledger: [String: IndoorMissionExtensionEntry]) {
        let sortedKeys = ledger.keys.sorted()
        let keysToKeep = Set(sortedKeys.suffix(21))
        let pruned = ledger.filter { keysToKeep.contains($0.key) }
        guard let encoded = try? JSONEncoder().encode(pruned) else { return }
        UserDefaults.standard.set(encoded, forKey: DefaultsKey.extensionLedger)
    }

    private func resolveDifficultySummary(
        context: IndoorMissionPetContext?,
        dayKey: String,
        now: Date
    ) -> IndoorMissionDifficultySummary? {
        guard let context,
              let petId = context.petId,
              petId.isEmpty == false else {
            return nil
        }

        let ageBand = petAgeBand(for: context.ageYears)
        let activityLevel = activityLevel(for: context.recentDailyMinutes)
        let walkFrequency = walkFrequencyBand(for: context.averageWeeklyWalkCount)

        var multiplier = 1.0
        var reasons: [String] = []

        switch ageBand {
        case .puppy:
            multiplier -= 0.08
            reasons.append("유년기 반려견이라 목표를 소폭 완화했어요.")
        case .senior:
            multiplier -= 0.12
            reasons.append("노령기 반려견 컨디션을 고려해 목표를 완화했어요.")
        case .adult, .unknown:
            break
        }

        switch activityLevel {
        case .low:
            multiplier -= 0.12
            reasons.append("최근 활동량이 낮아 완료 경험 안정화를 위해 목표를 낮췄어요.")
        case .high:
            multiplier += 0.10
            reasons.append("최근 활동량이 높아 목표를 조금 높였어요.")
        case .moderate:
            break
        }

        switch walkFrequency {
        case .sparse:
            multiplier -= 0.08
            reasons.append("최근 산책 빈도가 낮아 목표를 완화했어요.")
        case .frequent:
            multiplier += 0.08
            reasons.append("최근 산책 빈도가 높아 목표를 상향했어요.")
        case .steady:
            break
        }

        multiplier = min(max(0.75, multiplier), 1.25)
        if let previous = previousDifficultyMultiplier(petId: petId, beforeDayKey: dayKey) {
            let lowerBound = previous - maxDailyDifficultyDelta
            let upperBound = previous + maxDailyDifficultyDelta
            let clamped = min(max(lowerBound, multiplier), upperBound)
            if abs(clamped - multiplier) > 0.001 {
                reasons.append("급격한 변동을 막기 위해 일일 변동폭 제한을 적용했어요.")
            }
            multiplier = clamped
        }
        multiplier = min(max(0.75, multiplier), 1.25)

        let easyDayApplied = isEasyDayActive(dayKey: dayKey, petId: petId)
        upsertDifficultyLedgerEntry(
            dayKey: dayKey,
            petId: petId,
            petName: context.petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            multiplier: multiplier,
            reasons: reasons,
            easyDayApplied: easyDayApplied,
            now: now
        )

        let adjustmentPercent = Int(((multiplier - 1.0) * 100).rounded())
        let adjustmentDescription: String
        if adjustmentPercent == 0 {
            adjustmentDescription = "기본 난이도 유지"
        } else if adjustmentPercent > 0 {
            adjustmentDescription = "기본 대비 +\(adjustmentPercent)%"
        } else {
            adjustmentDescription = "기본 대비 \(adjustmentPercent)%"
        }

        let easyDayState: IndoorMissionEasyDayState = easyDayApplied ? .active : .available
        let easyDayMessage: String = easyDayApplied
            ? "오늘 쉬운 날 모드가 적용되어 보상이 20% 감액돼요."
            : "쉬운 날 모드(일 1회) 사용 시 오늘 목표를 더 쉽게 진행하고 보상은 20% 감액돼요."

        return .init(
            petId: petId,
            petName: context.petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            appliedMultiplier: multiplier,
            adjustmentDescription: adjustmentDescription,
            reasons: reasons,
            easyDayState: easyDayState,
            easyDayMessage: easyDayMessage,
            history: difficultyHistory(for: petId)
        )
    }

    private func petAgeBand(for ageYears: Int?) -> IndoorMissionPetAgeBand {
        guard let ageYears else { return .unknown }
        if ageYears <= 1 { return .puppy }
        if ageYears >= 10 { return .senior }
        return .adult
    }

    private func activityLevel(for recentDailyMinutes: Double) -> IndoorMissionActivityLevel {
        if recentDailyMinutes < 20 { return .low }
        if recentDailyMinutes > 65 { return .high }
        return .moderate
    }

    private func walkFrequencyBand(for averageWeeklyWalkCount: Double) -> IndoorMissionWalkFrequencyBand {
        if averageWeeklyWalkCount < 3 { return .sparse }
        if averageWeeklyWalkCount > 10 { return .frequent }
        return .steady
    }

    private func difficultyLedger() -> [String: IndoorMissionDifficultyLedgerEntry] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.difficultyLedger) else { return [:] }
        do {
            return try JSONDecoder().decode([String: IndoorMissionDifficultyLedgerEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistDifficultyLedger(_ ledger: [String: IndoorMissionDifficultyLedgerEntry], dayKey: String) {
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 42) + [dayKey])
        let filtered = ledger.filter { keysToKeep.contains($0.value.dayKey) }
        guard let encoded = try? JSONEncoder().encode(filtered) else { return }
        UserDefaults.standard.set(encoded, forKey: DefaultsKey.difficultyLedger)
    }

    private func upsertDifficultyLedgerEntry(
        dayKey: String,
        petId: String,
        petName: String,
        ageBand: IndoorMissionPetAgeBand,
        activityLevel: IndoorMissionActivityLevel,
        walkFrequency: IndoorMissionWalkFrequencyBand,
        multiplier: Double,
        reasons: [String],
        easyDayApplied: Bool,
        now: Date
    ) {
        let key = difficultyKey(dayKey: dayKey, petId: petId)
        var ledger = difficultyLedger()
        ledger[key] = .init(
            dayKey: dayKey,
            petId: petId,
            petName: petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            multiplier: multiplier,
            reasons: reasons,
            easyDayApplied: easyDayApplied,
            updatedAt: now.timeIntervalSince1970
        )
        persistDifficultyLedger(ledger, dayKey: dayKey)
    }

    private func previousDifficultyMultiplier(petId: String, beforeDayKey dayKey: String) -> Double? {
        let ledger = difficultyLedger()
        let previousKeys = previousDayStamps(from: dayKey, count: 7)
        for key in previousKeys {
            let lookup = difficultyKey(dayKey: key, petId: petId)
            if let entry = ledger[lookup] {
                return entry.multiplier
            }
        }
        return nil
    }

    private func difficultyHistory(for petId: String) -> [IndoorMissionDifficultyHistoryEntry] {
        let entries = difficultyLedger().values
            .filter { $0.petId == petId }
            .sorted { lhs, rhs in
                if lhs.dayKey == rhs.dayKey {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.dayKey > rhs.dayKey
            }
            .prefix(5)

        return entries.map { entry in
            .init(
                dayKey: entry.dayKey,
                petId: entry.petId,
                petName: entry.petName,
                multiplier: entry.multiplier,
                ageBand: entry.ageBand,
                activityLevel: entry.activityLevel,
                walkFrequency: entry.walkFrequency,
                easyDayApplied: entry.easyDayApplied
            )
        }
    }

    private func easyDayUsageMap() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.easyDayUsage) as? [String: TimeInterval] ?? [:]
    }

    private func persistEasyDayUsageMap(_ map: [String: TimeInterval], currentDayKey: String) {
        let keysToKeep = Set(previousDayStamps(from: currentDayKey, count: 14) + [currentDayKey])
        let filtered = map.filter { key, _ in
            let dayKey = key.components(separatedBy: "|").first ?? ""
            return keysToKeep.contains(dayKey)
        }
        UserDefaults.standard.set(filtered, forKey: DefaultsKey.easyDayUsage)
    }

    private func easyDayKey(dayKey: String, petId: String) -> String {
        "\(dayKey)|\(petId)"
    }

    private func isEasyDayActive(dayKey: String, petId: String) -> Bool {
        let key = easyDayKey(dayKey: dayKey, petId: petId)
        return easyDayUsageMap()[key] != nil
    }

    private func difficultyKey(dayKey: String, petId: String) -> String {
        "\(dayKey)|\(petId)"
    }

    private func resolveBaseRiskProfile() -> (risk: IndoorWeatherRiskLevel, source: IndoorWeatherRiskSource) {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let level = IndoorWeatherRiskLevel(rawValue: env.lowercased()) {
            return (level, .environment)
        }
        if let snapshot = weatherSnapshotStore.loadSnapshot(),
           let level = IndoorWeatherRiskLevel(rawValue: snapshot.level.rawValue) {
            let now = Date().timeIntervalSince1970
            let age = now - snapshot.observedAt
            if age <= 7200 {
                return (level, .snapshot)
            }
            let conservative = level == .clear ? IndoorWeatherRiskLevel.caution : level
            return (conservative, .fallback)
        }
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.weatherRiskOverride),
           let level = IndoorWeatherRiskLevel(rawValue: raw.lowercased()) {
            let now = Date().timeIntervalSince1970
            let observedAt = Double(UserDefaults.standard.string(forKey: DefaultsKey.weatherRiskObservedAt) ?? "") ?? 0
            if observedAt > 0 {
                let age = now - observedAt
                if age <= 7200 {
                    return (level, .userOverride)
                }
                let conservative = level == .clear ? IndoorWeatherRiskLevel.caution : level
                return (conservative, .fallback)
            }
            return (level, .userOverride)
        }
        return (.clear, .fallback)
    }

    /// 서버 canonical summary 계산에 사용할 로컬 기본 위험도 프로파일을 조회합니다.
    /// - Returns: 로컬 override를 제외한 기본 위험도와 소스입니다.
    private func resolveCanonicalBaseRiskProfile() -> (risk: IndoorWeatherRiskLevel, source: IndoorWeatherRiskSource) {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let level = IndoorWeatherRiskLevel(rawValue: env.lowercased()) {
            return (level, .environment)
        }
        if let snapshot = weatherSnapshotStore.loadSnapshot(),
           let level = IndoorWeatherRiskLevel(rawValue: snapshot.level.rawValue) {
            let now = Date().timeIntervalSince1970
            let age = now - snapshot.observedAt
            if age <= 7200 {
                return (level, .snapshot)
            }
            let conservative = level == .clear ? IndoorWeatherRiskLevel.caution : level
            return (conservative, .fallback)
        }
        return (.clear, .fallback)
    }

    private func resolveRiskLevel(now: Date = Date()) -> IndoorWeatherRiskLevel {
        weatherStatus(now: now).adjustedRisk
    }

    private func selectedTemplatesForToday(
        riskLevel: IndoorWeatherRiskLevel,
        dayKey: String
    ) -> [IndoorMissionTemplate] {
        let recentMissionIds = recentPresentedMissionIds(dayKey: dayKey)
        let ordered = templates.sorted { lhs, rhs in
            missionPriority(of: lhs, for: riskLevel) < missionPriority(of: rhs, for: riskLevel)
        }
        var filtered = ordered.filter { recentMissionIds.contains($0.id) == false }
        if filtered.count < riskLevel.replacementMissionCount {
            filtered = ordered
        }

        let selected = Array(filtered.prefix(riskLevel.replacementMissionCount))
        persistExposure(dayKey: dayKey, missionIds: selected.map(\.id))
        return selected
    }

    private func missionPriority(of template: IndoorMissionTemplate, for riskLevel: IndoorWeatherRiskLevel) -> Int {
        switch riskLevel {
        case .clear:
            return 99
        case .caution:
            switch template.category {
            case .petCareCheck: return 0
            case .recordCleanup: return 1
            case .trainingCheck: return 2
            }
        case .bad:
            switch template.category {
            case .recordCleanup: return 0
            case .petCareCheck: return 1
            case .trainingCheck: return 2
            }
        case .severe:
            switch template.category {
            case .petCareCheck: return 0
            case .trainingCheck: return 1
            case .recordCleanup: return 2
            }
        }
    }

    private func recentPresentedMissionIds(dayKey: String) -> Set<String> {
        let history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        let previousDayKeys = previousDayStamps(from: dayKey, count: 2)
        var ids: Set<String> = []
        for key in previousDayKeys {
            for id in history[key] ?? [] {
                ids.insert(id)
            }
        }
        return ids
    }

    private func persistExposure(dayKey: String, missionIds: [String]) {
        var history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        history[dayKey] = missionIds
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 7) + [dayKey])
        history = history.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(history, forKey: DefaultsKey.exposureHistory)
    }

    private func actionKey(missionId: String, dayKey: String) -> String {
        "\(dayKey)|\(missionId)"
    }

    private func dayStamp(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func previousDayStamps(from dayKey: String, count: Int) -> [String] {
        guard let current = Self.dayFormatter.date(from: dayKey) else { return [] }
        return (1...count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: current) else { return nil }
            return Self.dayFormatter.string(from: date)
        }
    }

    private func adjustedRisk(from risk: IndoorWeatherRiskLevel, step: Int) -> IndoorWeatherRiskLevel {
        guard step != 0 else { return risk }
        let allCases = IndoorWeatherRiskLevel.allCases
        guard let currentIndex = allCases.firstIndex(of: risk) else { return risk }
        let targetIndex = min(max(0, currentIndex + step), allCases.count - 1)
        let targetRisk = allCases[targetIndex]
        if risk != .clear && targetRisk == .clear {
            return .caution
        }
        return targetRisk
    }

    private func adjustmentStep(from originalRisk: IndoorWeatherRiskLevel, to adjustedRisk: IndoorWeatherRiskLevel) -> Int {
        guard let originalIndex = IndoorWeatherRiskLevel.allCases.firstIndex(of: originalRisk),
              let adjustedIndex = IndoorWeatherRiskLevel.allCases.firstIndex(of: adjustedRisk) else {
            return 0
        }
        return adjustedIndex - originalIndex
    }

    private func feedbackCountInCurrentWeek(now: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let events = feedbackTimestamps().filter { timestamp in
            let date = Date(timeIntervalSince1970: timestamp)
            return interval.contains(date)
        }
        return events.count
    }

    private func feedbackTimestamps() -> [TimeInterval] {
        let raw = UserDefaults.standard.array(forKey: DefaultsKey.weatherFeedbackTimestamps) as? [Double] ?? []
        return raw.sorted()
    }

    private func weatherShieldUsageMap() -> [String: [TimeInterval]] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.weatherShieldUsage) as? [String: [TimeInterval]] ?? [:]
    }

    private func lastWeatherAdjustmentTimestamp(now: Date) -> TimeInterval? {
        let dayKey = dayStamp(for: now)
        return feedbackTimestamps().last { timestamp in
            let date = Date(timeIntervalSince1970: timestamp)
            return dayStamp(for: date) == dayKey
        }
    }

    private func appendFeedbackTimestamp(now: Date) {
        let expiration = now.addingTimeInterval(-60 * 24 * 3600).timeIntervalSince1970
        var values = feedbackTimestamps().filter { $0 >= expiration }
        values.append(now.timeIntervalSince1970)
        UserDefaults.standard.set(values, forKey: DefaultsKey.weatherFeedbackTimestamps)
    }

    private func dailyAdjustmentMap() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.weatherFeedbackDailyAdjustment) as? [String: Int] ?? [:]
    }

    private func persistDailyAdjustment(dayKey: String, step: Int) {
        var map = dailyAdjustmentMap()
        if step == 0 {
            map.removeValue(forKey: dayKey)
        } else {
            map[dayKey] = step
        }
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 14) + [dayKey])
        map = map.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(map, forKey: DefaultsKey.weatherFeedbackDailyAdjustment)
    }

    /// 기본 위험도 소스에 맞는 기준 관측 시각을 계산합니다.
    /// - Parameters:
    ///   - source: 기본 위험도 판정에 사용한 소스입니다.
    ///   - now: fallback 시 사용할 현재 시각입니다.
    /// - Returns: 기준 관측 시각이며, 알 수 없으면 `now`를 반환합니다.
    private func resolveBaseObservedAt(source: IndoorWeatherRiskSource, now: Date) -> TimeInterval {
        switch source {
        case .snapshot:
            return weatherSnapshotStore.loadSnapshot()?.observedAt ?? now.timeIntervalSince1970
        case .environment, .serverSummary, .userOverride, .fallback:
            return now.timeIntervalSince1970
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

final class IndoorMissionCanonicalSummaryStore: IndoorMissionCanonicalSummaryStoreProtocol {
    static let shared = IndoorMissionCanonicalSummaryStore()

    private enum Key {
        static let summaries = "indoor.mission.canonical.summary.cache.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.indoor-mission-canonical-summary-store.state")

    /// UserDefaults 기반 실내 미션 canonical summary 저장소를 생성합니다.
    /// - Parameter defaults: snapshot을 저장할 UserDefaults 인스턴스입니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 서버 canonical summary snapshot을 저장합니다.
    /// - Parameter summary: 저장할 실내 미션 canonical summary입니다.
    func save(_ summary: IndoorMissionCanonicalSummarySnapshot) {
        stateQueue.sync {
            guard let ownerUserId = normalizedUserId(summary.ownerUserId) else { return }
            guard let data = try? encoder.encode(summary) else { return }
            var storage = defaults.dictionary(forKey: Key.summaries) as? [String: Data] ?? [:]
            storage[storageKey(ownerUserId: ownerUserId, dayKey: summary.dayKey, petContextId: summary.petContextId)] = data
            storage = prunedStorage(storage)
            defaults.set(storage, forKey: Key.summaries)
        }
    }

    /// 특정 사용자/일자/반려견 문맥에 대응하는 summary snapshot을 조회합니다.
    /// - Parameters:
    ///   - userId: 현재 사용자 식별자입니다.
    ///   - dayKey: 조회 기준 day key입니다.
    ///   - petContextId: 반려견 context 식별자입니다.
    /// - Returns: 저장된 snapshot이며, 없거나 다른 사용자 캐시면 `nil`입니다.
    func loadSummary(
        for userId: String?,
        dayKey: String,
        petContextId: String?
    ) -> IndoorMissionCanonicalSummarySnapshot? {
        stateQueue.sync {
            guard let ownerUserId = normalizedUserId(userId) else { return nil }
            let storage = defaults.dictionary(forKey: Key.summaries) as? [String: Data] ?? [:]
            let key = storageKey(ownerUserId: ownerUserId, dayKey: dayKey, petContextId: petContextId)
            guard let data = storage[key] else { return nil }
            guard let snapshot = try? decoder.decode(IndoorMissionCanonicalSummarySnapshot.self, from: data) else {
                return nil
            }
            guard normalizedUserId(snapshot.ownerUserId) == ownerUserId else { return nil }
            return snapshot
        }
    }

    /// 최대 허용 나이 안에 있는 canonical summary snapshot을 조회합니다.
    /// - Parameters:
    ///   - maxAge: 허용할 최대 snapshot 나이(초)입니다.
    ///   - userId: 현재 사용자 식별자입니다.
    ///   - dayKey: 조회 기준 day key입니다.
    ///   - petContextId: 반려견 context 식별자입니다.
    /// - Returns: 유효한 snapshot이며, 없거나 만료되면 `nil`입니다.
    func loadFreshSummary(
        maxAge: TimeInterval,
        for userId: String?,
        dayKey: String,
        petContextId: String?
    ) -> IndoorMissionCanonicalSummarySnapshot? {
        guard let snapshot = loadSummary(for: userId, dayKey: dayKey, petContextId: petContextId) else {
            return nil
        }
        let age = Date().timeIntervalSince1970 - snapshot.refreshedAt
        guard age <= maxAge else { return nil }
        return snapshot
    }

    /// 특정 사용자에게 속한 실내 미션 canonical snapshot을 모두 삭제합니다.
    /// - Parameter userId: 삭제할 사용자 식별자입니다. `nil`이면 전체 캐시를 비웁니다.
    func clear(for userId: String?) {
        stateQueue.sync {
            guard let ownerUserId = normalizedUserId(userId) else {
                defaults.removeObject(forKey: Key.summaries)
                return
            }
            let storage = defaults.dictionary(forKey: Key.summaries) as? [String: Data] ?? [:]
            let filtered = storage.filter { $0.key.hasPrefix(ownerUserId + "|") == false }
            defaults.set(filtered, forKey: Key.summaries)
        }
    }

    /// 사용자/일자/반려견 문맥 조합으로 canonical cache key를 생성합니다.
    /// - Parameters:
    ///   - ownerUserId: snapshot 소유 사용자 식별자입니다.
    ///   - dayKey: snapshot day key입니다.
    ///   - petContextId: 반려견 context 식별자입니다.
    /// - Returns: UserDefaults 저장에 사용할 안정적인 cache key입니다.
    private func storageKey(ownerUserId: String, dayKey: String, petContextId: String?) -> String {
        "\(ownerUserId)|\(dayKey)|\(normalizedPetContextId(petContextId))"
    }

    /// 반려견 context 식별자를 cache key용 canonical 문자열로 정규화합니다.
    /// - Parameter petContextId: 정규화할 원시 반려견 context 식별자입니다.
    /// - Returns: 비어 있지 않은 canonical context 문자열이며, 없으면 `__none__`입니다.
    private func normalizedPetContextId(_ petContextId: String?) -> String {
        let trimmed = petContextId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty == false {
            return trimmed.lowercased()
        }
        return "__none__"
    }

    /// 사용자 식별자를 cache owner key로 정규화합니다.
    /// - Parameter userId: 정규화할 원시 사용자 식별자입니다.
    /// - Returns: 비어 있지 않은 lowercased 사용자 식별자이며, 없으면 `nil`입니다.
    private func normalizedUserId(_ userId: String?) -> String? {
        guard let userId = userId?.trimmingCharacters(in: .whitespacesAndNewlines), userId.isEmpty == false else {
            return nil
        }
        return userId.lowercased()
    }

    /// 최근 snapshot만 남기도록 저장소를 절제합니다.
    /// - Parameter storage: 현재 저장된 cache 사전입니다.
    /// - Returns: 최신 `12`개 snapshot만 유지한 사전입니다.
    private func prunedStorage(_ storage: [String: Data]) -> [String: Data] {
        guard storage.count > 12 else { return storage }
        let decodedPairs = storage.compactMap { key, data -> (String, IndoorMissionCanonicalSummarySnapshot)? in
            guard let snapshot = try? decoder.decode(IndoorMissionCanonicalSummarySnapshot.self, from: data) else {
                return nil
            }
            return (key, snapshot)
        }
        let keysToKeep = Set(
            decodedPairs
                .sorted { $0.1.refreshedAt > $1.1.refreshedAt }
                .prefix(12)
                .map(\.0)
        )
        return storage.filter { keysToKeep.contains($0.key) }
    }
}
