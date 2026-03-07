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

    func buildBoard(now: Date) -> IndoorMissionBoard {
        buildBoard(now: now, context: nil)
    }

    func buildBoard(now: Date, context: IndoorMissionPetContext?) -> IndoorMissionBoard {
        let riskLevel = resolveRiskLevel(now: now)
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
            )
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
        let lastApplied = values.max() ?? now.timeIntervalSince1970
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return WeatherShieldDailySummary(
            dayKey: dayKey,
            applyCount: values.count,
            lastAppliedAtText: formatter.string(from: Date(timeIntervalSince1970: lastApplied))
        )
    }

    func weatherFeedbackRemainingCount(now: Date = Date()) -> Int {
        max(0, weeklyFeedbackLimit - feedbackCountInCurrentWeek(now: now))
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

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
