import Foundation

extension HomeViewModel {
    /// 실패/만료 상황에서 사용자가 다음으로 시도할 행동을 안내하는 문구를 생성합니다.
    func makeQuestAlternativeActionSuggestion(for board: IndoorMissionBoard) -> String? {
        switch board.extensionState {
        case .expired:
            return "연장 미션이 만료됐어요. 오늘 기본 미션 1개를 먼저 완료해 내일 자동 연장 조건을 회복하세요."
        case .cooldown:
            return "연장 슬롯은 하루 쿨다운이에요. 기본 미션 행동량을 채워 오늘 점수를 먼저 확보하세요."
        default:
            break
        }

        if board.riskLevel != .clear {
            return "악천후일 때는 실내 대체 미션을 우선 진행하세요. 완료 기준 미달이면 행동 +1을 먼저 채워보세요."
        }
        return nil
    }

    func refreshIndoorMissions(now: Date = Date()) {
        let missionContext = makeIndoorMissionPetContext(reference: now)
        indoorMissionBoard = indoorMissionStore.buildBoard(now: now, context: missionContext)
        questAlternativeActionSuggestion = makeQuestAlternativeActionSuggestion(for: indoorMissionBoard)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(now: now)
        let weatherStatus = indoorMissionStore.weatherStatus(now: now)
        let shieldDailySummary = indoorMissionStore.weatherShieldDailySummary(now: now)
        weatherShieldDailySummary = shieldDailySummary
        weatherMissionStatusSummary = weatherMissionStatusBuilder.makeStatusSummary(
            board: indoorMissionBoard,
            status: weatherStatus,
            now: now,
            shieldApplyCount: shieldDailySummary?.applyCount ?? 0,
            localizedCopy: localizedCopy(ko:en:)
        )
        if indoorMissionBoard.isIndoorReplacementActive {
            let exposureKey = "\(indoorMissionBoard.dayKey)|\(indoorMissionBoard.riskLevel.rawValue)"
            if exposureKey != lastIndoorMissionExposureTrackKey {
                lastIndoorMissionExposureTrackKey = exposureKey
                metricTracker.track(
                    .indoorMissionReplacementApplied,
                    userKey: userInfo?.id,
                    payload: [
                        "risk": indoorMissionBoard.riskLevel.rawValue,
                        "missionCount": "\(indoorMissionBoard.missions.count)"
                    ]
                )
            }
        }

        let extensionTrackKey = "\(indoorMissionBoard.dayKey)|\(indoorMissionBoard.extensionState.rawValue)"
        if extensionTrackKey != lastIndoorMissionExtensionTrackKey {
            lastIndoorMissionExtensionTrackKey = extensionTrackKey

            switch indoorMissionBoard.extensionState {
            case .active:
                metricTracker.track(
                    .indoorMissionExtensionApplied,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey,
                        "rewardScale": String(format: "%.2f", indoorMissionStore.extensionRewardScale)
                    ]
                )
            case .expired:
                indoorMissionStatusMessage = indoorMissionBoard.extensionMessage
                metricTracker.track(
                    .indoorMissionExtensionExpired,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey
                    ]
                )
            case .cooldown:
                indoorMissionStatusMessage = indoorMissionBoard.extensionMessage
                metricTracker.track(
                    .indoorMissionExtensionBlocked,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey,
                        "reason": "consecutive_limit"
                    ]
                )
            case .consumed, .none:
                break
            }
        }

        if let difficulty = indoorMissionBoard.difficultySummary {
            let difficultyKey = "\(indoorMissionBoard.dayKey)|\(difficulty.petId ?? "none")|\(String(format: "%.2f", difficulty.appliedMultiplier))|\(difficulty.easyDayState.rawValue)"
            if difficultyKey != lastIndoorMissionDifficultyTrackKey {
                lastIndoorMissionDifficultyTrackKey = difficultyKey
                metricTracker.track(
                    .indoorMissionDifficultyAdjusted,
                    userKey: userInfo?.id,
                    payload: [
                        "petId": difficulty.petId ?? "",
                        "multiplier": String(format: "%.2f", difficulty.appliedMultiplier),
                        "easyDay": difficulty.easyDayState == .active ? "true" : "false",
                        "ageBand": difficulty.ageBand.rawValue,
                        "activityLevel": difficulty.activityLevel.rawValue,
                        "walkFrequency": difficulty.walkFrequency.rawValue
                    ]
                )
            }
        }

        syncSeasonScoreWithWalkSessions(now: now)
        refreshSeasonMotion(now: now)
    }

    func recordIndoorMissionAction(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        indoorMissionStore.incrementActionCount(
            missionId: mission.trackingMissionId,
            dayKey: mission.dayKey
        )
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)
        questMotionEvent = QuestMotionEvent(
            missionId: mission.id,
            missionTitle: mission.title,
            type: .progress,
            progress: mission.progress.progressRatio
        )
        metricTracker.track(
            .indoorMissionActionLogged,
            userKey: userInfo?.id,
            payload: [
                "missionId": mission.trackingMissionId,
                "actionCount": "\(mission.progress.actionCount)",
                "isExtension": mission.isExtension ? "true" : "false"
            ]
        )
    }

    func finalizeIndoorMission(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        let result = indoorMissionStore.confirmCompletion(
            missionId: mission.trackingMissionId,
            dayKey: mission.dayKey,
            minimumActionCount: mission.minimumActionCount
        )
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)

        switch result {
        case .completed:
            questAlternativeActionSuggestion = nil
            let seasonUpdate = seasonMotionStore.recordMissionCompletion(
                rewardPoint: mission.rewardPoint,
                streakEligible: mission.streakEligible,
                riskLevel: indoorMissionBoard.riskLevel
            )
            if seasonUpdate.shieldApplied {
                indoorMissionStore.recordWeatherShieldUsage()
            }
            seasonMotionSummary = seasonUpdate.summary
            if let completedSeason = seasonUpdate.completedSeason {
                seasonResultPresentation = completedSeason
                seasonResetTransitionToken = UUID()
            }
            if seasonUpdate.scoreDelta > 0 || seasonUpdate.rankUp || seasonUpdate.shieldApplied {
                seasonMotionEvent = SeasonMotionEvent(
                    type: seasonUpdate.rankUp ? .rankUp : .scoreIncreased,
                    scoreDelta: seasonUpdate.scoreDelta,
                    rankTier: seasonUpdate.summary.rankTier,
                    shieldApplied: seasonUpdate.shieldApplied
                )
            } else if seasonUpdate.completedSeason != nil {
                seasonMotionEvent = SeasonMotionEvent(
                    type: .seasonReset,
                    scoreDelta: 0,
                    rankTier: seasonUpdate.summary.rankTier,
                    shieldApplied: false
                )
            }
            if mission.isExtension {
                _ = indoorMissionStore.markExtensionConsumedIfNeeded(mission)
                indoorMissionStatusMessage = "\(mission.title) 연장 미션 완료! 감액 보상 \(mission.rewardPoint)pt"
                metricTracker.track(
                    .indoorMissionExtensionConsumed,
                    userKey: userInfo?.id,
                    payload: [
                        "missionId": mission.trackingMissionId,
                        "reward": "\(mission.rewardPoint)",
                        "rewardScale": String(format: "%.2f", mission.extensionRewardScale)
                    ]
                )
            } else {
                indoorMissionStatusMessage = "\(mission.title) 완료! 보상 \(mission.rewardPoint)pt"
            }
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .completed,
                progress: 1.0
            )
            questCompletionPresentation = QuestCompletionPresentation(
                missionId: mission.id,
                missionTitle: mission.title,
                rewardPoint: mission.rewardPoint
            )
            metricTracker.track(
                .indoorMissionCompleted,
                userKey: userInfo?.id,
                payload: [
                    "missionId": mission.trackingMissionId,
                    "reward": "\(mission.rewardPoint)",
                    "risk": indoorMissionBoard.riskLevel.rawValue,
                    "isExtension": mission.isExtension ? "true" : "false"
                ]
            )
            refreshIndoorMissions()
        case .insufficientAction(let actionCount, let required):
            indoorMissionStatusMessage = "완료 기준 미달: \(actionCount)/\(required) 행동"
            questAlternativeActionSuggestion = "행동 +1을 더 누르거나 지도 탭에서 포인트 수동 기록 후 다시 완료를 눌러보세요."
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .failed,
                progress: mission.progress.progressRatio
            )
            metricTracker.track(
                .indoorMissionCompletionRejected,
                userKey: userInfo?.id,
                payload: [
                    "missionId": mission.trackingMissionId,
                    "actionCount": "\(actionCount)",
                    "required": "\(required)",
                    "isExtension": mission.isExtension ? "true" : "false"
                ]
            )
        case .alreadyCompleted:
            indoorMissionStatusMessage = "이미 완료한 미션입니다."
            questAlternativeActionSuggestion = "다른 미션 카드에서 행동량을 채운 뒤 즉시 수령 버튼으로 완료를 진행해보세요."
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .alreadyCompleted,
                progress: 1.0
            )
        }
    }

    func submitWeatherMismatchFeedback(now: Date = Date()) {
        let outcome = indoorMissionStore.submitWeatherMismatchFeedback(now: now)
        weatherFeedbackRemainingCount = outcome.remainingWeeklyQuota

        if outcome.accepted {
            let hasRiskChanged = outcome.originalRisk != outcome.adjustedRisk
            weatherFeedbackResultMessage = hasRiskChanged
                ? "체감 피드백 반영: \(outcome.originalRisk.displayTitle) → \(outcome.adjustedRisk.displayTitle)"
                : "피드백을 반영했지만 안전 기준상 오늘 판정은 \(outcome.adjustedRisk.displayTitle)로 유지돼요."
            metricTracker.track(
                .weatherFeedbackSubmitted,
                userKey: userInfo?.id,
                payload: [
                    "fromRisk": outcome.originalRisk.rawValue,
                    "toRisk": outcome.adjustedRisk.rawValue,
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)"
                ]
            )
            metricTracker.track(
                .weatherRiskReevaluated,
                userKey: userInfo?.id,
                payload: [
                    "fromRisk": outcome.originalRisk.rawValue,
                    "toRisk": outcome.adjustedRisk.rawValue,
                    "changed": hasRiskChanged ? "true" : "false"
                ]
            )
        } else {
            weatherFeedbackResultMessage = outcome.message
            metricTracker.track(
                .weatherFeedbackRateLimited,
                userKey: userInfo?.id,
                payload: [
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)"
                ]
            )
        }

        indoorMissionStatusMessage = weatherFeedbackResultMessage
        refreshIndoorMissions(now: now)
    }

    func activateEasyDayMode(now: Date = Date()) {
        guard let difficulty = indoorMissionBoard.difficultySummary else {
            indoorMissionStatusMessage = "선택된 반려견 정보가 없어 쉬운 날 모드를 사용할 수 없어요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "no_pet_context"
                ]
            )
            return
        }

        let outcome = indoorMissionStore.activateEasyDayMode(
            petId: difficulty.petId,
            now: now
        )
        switch outcome {
        case .activated:
            indoorMissionStatusMessage = "쉬운 날 모드를 적용했어요. 오늘 보상은 20% 감액돼요."
            metricTracker.track(
                .indoorMissionEasyDayActivated,
                userKey: userInfo?.id,
                payload: [
                    "petId": difficulty.petId ?? "",
                    "dayKey": indoorMissionBoard.dayKey,
                    "rewardScale": "0.80"
                ]
            )
            refreshIndoorMissions(now: now)
        case .alreadyUsed:
            indoorMissionStatusMessage = "쉬운 날 모드는 하루에 한 번만 사용할 수 있어요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "petId": difficulty.petId ?? "",
                    "reason": "daily_limit"
                ]
            )
        case .missingPet:
            indoorMissionStatusMessage = "선택 반려견을 먼저 지정한 뒤 다시 시도해주세요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "missing_pet"
                ]
            )
        }
    }

    func makeIndoorMissionPetContext(reference: Date) -> IndoorMissionPetContext {
        let fourteenDaysAgo = reference.addingTimeInterval(-14 * 24 * 3600)
        let twentyEightDaysAgo = reference.addingTimeInterval(-28 * 24 * 3600)
        let recentPolygons = polygonList.filter { Date(timeIntervalSince1970: $0.createdAt) >= fourteenDaysAgo }
        let monthlyPolygons = polygonList.filter { Date(timeIntervalSince1970: $0.createdAt) >= twentyEightDaysAgo }
        let totalRecentMinutes = recentPolygons.reduce(0.0) { partial, polygon in
            partial + max(0, polygon.walkingTime) / 60.0
        }
        let recentDailyMinutes = totalRecentMinutes / 14.0
        let averageWeeklyWalkCount = Double(monthlyPolygons.count) / 4.0

        return .init(
            petId: selectedPet?.petId,
            petName: selectedPet?.petName ?? "강아지",
            ageYears: selectedPet?.ageYears,
            recentDailyMinutes: recentDailyMinutes,
            averageWeeklyWalkCount: averageWeeklyWalkCount
        )
    }

    /// 이번 주 완료된 산책 세션을 시즌 점수로 1회만 반영합니다.
    func syncSeasonScoreWithWalkSessions(now: Date) {
        let weekInterval = currentWeekInterval(reference: now)
        let inputs: [SeasonWalkContributionInput] = polygonList.compactMap { polygon in
            guard sessionOverlaps(polygon, with: weekInterval) else { return nil }
            let interval = sessionInterval(for: polygon)
            return SeasonWalkContributionInput(
                sessionId: polygon.id.uuidString.lowercased(),
                areaM2: max(0, polygon.walkingArea),
                durationSec: max(0, polygon.walkingTime),
                eventAt: interval.end.timeIntervalSince1970
            )
        }

        guard let update = seasonMotionStore.recordWalkContributions(
            sessions: inputs,
            riskLevel: indoorMissionBoard.riskLevel,
            now: now
        ) else {
            return
        }

        seasonMotionSummary = update.summary
        if let completedSeason = update.completedSeason {
            seasonResultPresentation = completedSeason
            lastSeasonResultPresentation = completedSeason
            seasonResetTransitionToken = UUID()
        }
        if update.scoreDelta > 0 || update.rankUp {
            seasonMotionEvent = SeasonMotionEvent(
                type: update.rankUp ? .rankUp : .scoreIncreased,
                scoreDelta: update.scoreDelta,
                rankTier: update.summary.rankTier,
                shieldApplied: false
            )
        }
    }

    func refreshSeasonMotion(now: Date) {
        let refresh = seasonMotionStore.refresh(
            now: now,
            riskLevel: indoorMissionBoard.riskLevel
        )
        seasonMotionSummary = refresh.summary
        seasonRemainingTimeText = seasonMotionStore.remainingTimeText(now: now)
        lastSeasonResultPresentation = seasonMotionStore.loadLastCompletedSeason()
        if let completedSeason = refresh.completedSeason {
            seasonResultPresentation = completedSeason
            lastSeasonResultPresentation = completedSeason
            seasonResetTransitionToken = UUID()
            seasonMotionEvent = SeasonMotionEvent(
                type: .seasonReset,
                scoreDelta: 0,
                rankTier: refresh.summary.rankTier,
                shieldApplied: false
            )
        }
    }
}
