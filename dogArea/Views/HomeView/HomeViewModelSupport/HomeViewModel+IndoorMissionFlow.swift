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
        if applyIndoorMissionUITestScenarioIfNeeded(now: now) {
            return
        }
        refreshWeatherSnapshot(now: now)
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
        updateWeatherDetailPresentation(now: now)
        updateIndoorMissionPresentation()
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
        updateIndoorMissionPresentation()
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
        updateIndoorMissionPresentation()

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
        let selectedPetId = normalizedIndoorMissionPetContextPetId()
        let polygonFingerprint = indoorMissionPetContextPolygonFingerprint
            ?? indoorMissionPetContextSnapshotService.makePolygonFingerprint(from: polygonList)
        indoorMissionPetContextPolygonFingerprint = polygonFingerprint

        if indoorMissionPetContextSnapshotService.canReuseSnapshot(
            indoorMissionPetContextAggregationSnapshot,
            polygonFingerprint: polygonFingerprint,
            selectedPetId: selectedPetId,
            reference: reference
        ) {
            return makeIndoorMissionPetContext(
                from: indoorMissionPetContextAggregationSnapshot,
                selectedPetId: selectedPetId
            )
        }

        let snapshot = indoorMissionPetContextSnapshotService.makeAggregationSnapshot(
            polygons: polygonList,
            polygonFingerprint: polygonFingerprint,
            selectedPetId: selectedPetId,
            reference: reference
        )
        indoorMissionPetContextAggregationSnapshot = snapshot
        return makeIndoorMissionPetContext(from: snapshot, selectedPetId: selectedPetId)
    }

    /// 현재 선택 반려견 식별자를 실내 미션 pet context 입력 형식으로 정규화합니다.
    /// - Returns: 비어 있지 않은 선택 반려견 식별자이며, 선택되지 않았으면 `nil`입니다.
    func normalizedIndoorMissionPetContextPetId() -> String? {
        guard let selectedPetId = selectedPet?.petId, selectedPetId.isEmpty == false else {
            return nil
        }
        return selectedPetId
    }

    /// 집계 snapshot과 현재 선택 반려견 표시 정보를 조합해 최종 pet context를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최근 14일/28일 집계가 들어 있는 재사용 snapshot입니다.
    ///   - selectedPetId: 현재 선택 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    /// - Returns: 홈 실내 미션 난이도 계산에 전달할 최종 반려견 컨텍스트입니다.
    func makeIndoorMissionPetContext(
        from snapshot: HomeIndoorMissionPetContextAggregationSnapshot?,
        selectedPetId: String?
    ) -> IndoorMissionPetContext {
        IndoorMissionPetContext(
            petId: selectedPetId,
            petName: selectedPet?.petName ?? "강아지",
            ageYears: selectedPet?.ageYears,
            recentDailyMinutes: snapshot?.recentDailyMinutes ?? 0.0,
            averageWeeklyWalkCount: snapshot?.averageWeeklyWalkCount ?? 0.0
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

    /// 현재 실내 미션 보드와 날씨 요약을 바탕으로 홈 카드 프레젠테이션 상태를 갱신합니다.
    func updateIndoorMissionPresentation() {
        indoorMissionPresentation = indoorMissionPresentationService.makePresentation(
            board: indoorMissionBoard,
            weatherSummary: weatherMissionStatusSummary,
            localizedCopy: localizedCopy(ko:en:)
        )
    }

    /// UI 테스트용 홈 미션 시나리오가 지정되어 있으면 보드와 요약 상태를 강제로 주입합니다.
    /// - Parameter now: 시나리오의 기준 시각입니다.
    /// - Returns: UI 테스트 시나리오를 적용했으면 `true`를 반환합니다.
    func applyIndoorMissionUITestScenarioIfNeeded(now: Date) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("-UITest.HomeMissionLifecycleStub") else {
            return false
        }

        let dayKey = indoorMissionStore.dayStampForPreview(now: now)
        indoorMissionBoard = makeIndoorMissionUITestBoard(dayKey: dayKey)
        latestWeatherSnapshot = makeIndoorMissionUITestWeatherSnapshot(now: now)
        weatherFeedbackRemainingCount = indoorMissionStore.weeklyFeedbackLimit
        weatherShieldDailySummary = .init(dayKey: dayKey, applyCount: 1, lastAppliedAtText: "09:30")
        weatherMissionStatusSummary = .init(
            badgeText: "치환",
            title: "오늘 미션 영향 요약",
            reasonText: "강풍과 강수 위험 때문에 오늘은 실내 대체 미션을 우선 진행합니다.",
            appliedAtText: "적용 시점 09:30",
            shieldUsageText: "보호 사용 1회",
            policyTitle: "오늘 미션 기준",
            policyText: "실외 목표 대신 실내 대체 미션 3개가 열렸고, 행동 +1은 실제로 끝낸 루틴만 기록하는 체크입니다.",
            lifecycleGuideText: "기준 횟수를 채운 뒤 완료 확인을 눌러야 보상이 확정되고, 완료된 미션은 아래 아카이브로 이동합니다.",
            fallbackNotice: nil,
            accessibilityText: "오늘 미션 영향 요약. 강풍과 강수 위험 때문에 실내 대체 미션이 열렸습니다.",
            isFallback: false,
            riskLevel: .bad
        )
        questAlternativeActionSuggestion = "오늘은 실내 루틴을 실제로 수행한 횟수만 기록하고, 완료된 미션은 아래 완료 영역에서 확인하세요."
        updateWeatherDetailPresentation(now: now)
        updateIndoorMissionPresentation()
        return true
    }

    /// 홈 미션 UI 테스트에서 사용할 원시 날씨 스냅샷을 생성합니다.
    /// - Parameter now: 테스트 관측 시각의 기준이 되는 현재 시각입니다.
    /// - Returns: 상세 카드가 안정적으로 렌더링할 수 있는 테스트용 날씨 스냅샷입니다.
    func makeIndoorMissionUITestWeatherSnapshot(now: Date) -> WeatherSnapshot {
        WeatherSnapshot(
            level: .bad,
            observedAt: now.addingTimeInterval(-15 * 60).timeIntervalSince1970,
            weatherSource: .live,
            airQualitySource: .live,
            location: .init(latitude: 37.4979, longitude: 127.0276),
            temperatureC: 14.2,
            apparentTemperatureC: 12.9,
            relativeHumidityPercent: 78.0,
            isPrecipitating: true,
            precipitationMMPerHour: 3.6,
            windMps: 5.1,
            pm2_5: 18.0,
            pm10: 31.0
        )
    }

    /// UI 테스트에서 사용할 홈 미션 보드를 생성합니다.
    /// - Parameter dayKey: 테스트용 미션 보드에 사용할 날짜 키입니다.
    /// - Returns: 활성/확정 가능/완료 미션을 모두 포함한 테스트용 실내 미션 보드입니다.
    func makeIndoorMissionUITestBoard(dayKey: String) -> IndoorMissionBoard {
        let activeMission = IndoorMissionCardModel(
            id: "uitest.home.quest.active",
            category: .petCareCheck,
            title: "펫 케어 루틴 체크",
            description: "물/브러싱/컨디션 체크를 2회 진행해요.",
            minimumActionCount: 2,
            rewardPoint: 32,
            streakEligible: true,
            trackingMissionId: "uitest.home.quest.active",
            dayKey: dayKey,
            isExtension: false,
            extensionSourceDayKey: nil,
            extensionRewardScale: 1.0,
            progress: .init(actionCount: 1, minimumActionCount: 2, isCompleted: false)
        )
        let readyMission = IndoorMissionCardModel(
            id: "uitest.home.quest.ready",
            category: .trainingCheck,
            title: "실내 훈련 체크",
            description: "기다려/손/하우스 훈련을 4회 수행해요.",
            minimumActionCount: 4,
            rewardPoint: 48,
            streakEligible: true,
            trackingMissionId: "uitest.home.quest.ready",
            dayKey: dayKey,
            isExtension: false,
            extensionSourceDayKey: nil,
            extensionRewardScale: 1.0,
            progress: .init(actionCount: 4, minimumActionCount: 4, isCompleted: false)
        )
        let completedMission = IndoorMissionCardModel(
            id: "uitest.home.quest.completed",
            category: .recordCleanup,
            title: "기록 정리 체크",
            description: "산책 기록/사진/메모 정리를 3회 진행해요.",
            minimumActionCount: 3,
            rewardPoint: 40,
            streakEligible: true,
            trackingMissionId: "uitest.home.quest.completed",
            dayKey: dayKey,
            isExtension: true,
            extensionSourceDayKey: "2026-03-06",
            extensionRewardScale: indoorMissionStore.extensionRewardScale,
            progress: .init(actionCount: 3, minimumActionCount: 3, isCompleted: true)
        )

        return .init(
            riskLevel: .bad,
            dayKey: dayKey,
            missions: [activeMission, readyMission, completedMission],
            extensionState: .consumed,
            extensionMessage: "전일 미션 1개가 연장되었고, 완료 후에는 완료 아카이브로 이동합니다.",
            difficultySummary: nil
        )
    }
}
