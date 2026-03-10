import Foundation

extension HomeViewModel {
    private enum WeatherCanonicalSummaryConstants {
        static let maxCacheAge: TimeInterval = 30 * 60
    }

    private enum IndoorMissionCanonicalSummaryConstants {
        static let maxCacheAge: TimeInterval = 30 * 60
    }

    /// 현재 홈에 표시할 시즌 요약을 로컬 fallback 기준으로 먼저 갱신합니다.
    /// - Parameter now: 시즌 남은 시간과 fallback 요약을 계산할 기준 시각입니다.
    func refreshSeasonMotion(now: Date) {
        let localRefresh = seasonMotionStore.refresh(
            now: now,
            riskLevel: indoorMissionBoard.riskLevel
        )
        applyLocalSeasonRefresh(localRefresh, now: now)
    }

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

    /// 홈 실내 미션/날씨 상태를 현재 로컬 snapshot과 서버 canonical summary를 조합해 새로고침합니다.
    /// - Parameters:
    ///   - now: 집계 기준 시각입니다.
    ///   - shouldFetchServerSummary: 새로고침 후 서버 canonical summary를 비동기로 다시 조회할지 여부입니다.
    func refreshIndoorMissions(now: Date = Date(), shouldFetchServerSummary: Bool = true) {
        if applyIndoorMissionUITestScenarioIfNeeded(now: now) {
            return
        }
        refreshWeatherSnapshot(now: now)
        let baseWeatherStatus = indoorMissionStore.baseWeatherStatus(now: now)
        let missionContext = makeIndoorMissionPetContext(reference: now)
        let indoorMissionDayKey = indoorMissionStore.dayStampForPreview(now: now)
        let cachedIndoorMissionSummary = indoorMissionCanonicalSummaryStore.loadFreshSummary(
            maxAge: IndoorMissionCanonicalSummaryConstants.maxCacheAge,
            for: userInfo?.id,
            dayKey: indoorMissionDayKey,
            petContextId: missionContext.petId
        ) ?? indoorMissionCanonicalSummaryStore.loadSummary(
            for: userInfo?.id,
            dayKey: indoorMissionDayKey,
            petContextId: missionContext.petId
        )
        latestIndoorMissionCanonicalSummary = cachedIndoorMissionSummary
        let cachedServerSummary = weatherReplacementSummaryStore.loadFreshSummary(
            maxAge: WeatherCanonicalSummaryConstants.maxCacheAge,
            for: userInfo?.id
        )
        applyIndoorWeatherPresentation(
            now: now,
            missionContext: missionContext,
            baseWeatherStatus: baseWeatherStatus,
            serverSummary: cachedServerSummary,
            indoorMissionSummary: cachedIndoorMissionSummary
        )

        syncSeasonScoreWithWalkSessions(now: now)
        refreshSeasonMotion(now: now)

        if shouldFetchServerSummary {
            refreshWeatherCanonicalSummaryIfNeeded(
                baseWeatherStatus: baseWeatherStatus,
                now: now
            )
            refreshIndoorMissionCanonicalSummaryIfNeeded(
                missionContext: missionContext,
                baseWeatherStatus: baseWeatherStatus,
                now: now
            )
            refreshSeasonCanonicalSummaryIfNeeded(now: now)
        }
    }

    /// 홈 실내 미션/날씨 카드가 사용할 파생 상태를 계산해 published 상태에 반영합니다.
    /// - Parameters:
    ///   - now: 집계 기준 시각입니다.
    ///   - missionContext: 선택 반려견 기반 실내 미션 컨텍스트입니다.
    ///   - baseWeatherStatus: 로컬 snapshot 기반 기본 위험도 상태입니다.
    ///   - serverSummary: 서버 canonical summary입니다. 없으면 로컬 fallback을 사용합니다.
    ///   - indoorMissionSummary: 서버가 확정한 실내 미션 보드 canonical summary입니다. 없으면 로컬 fallback 보드를 사용합니다.
    func applyIndoorWeatherPresentation(
        now: Date,
        missionContext: IndoorMissionPetContext,
        baseWeatherStatus: IndoorWeatherStatus,
        serverSummary: WeatherReplacementSummarySnapshot?,
        indoorMissionSummary: IndoorMissionCanonicalSummarySnapshot?
    ) {
        let weatherStatus = indoorMissionStore.weatherStatus(
            now: now,
            serverSummary: serverSummary,
            baseWeatherStatus: baseWeatherStatus
        )
        if let indoorMissionSummary {
            indoorMissionBoard = indoorMissionStore.buildBoard(from: indoorMissionSummary)
        } else {
            indoorMissionBoard = indoorMissionStore.buildBoard(
                now: now,
                context: missionContext,
                weatherStatus: weatherStatus,
                serverSummary: serverSummary
            )
        }
        questAlternativeActionSuggestion = makeQuestAlternativeActionSuggestion(for: indoorMissionBoard)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(
            now: now,
            serverSummary: serverSummary
        )
        let shieldDailySummary = indoorMissionStore.weatherShieldDailySummary(
            now: now,
            serverSummary: serverSummary
        )
        weatherShieldDailySummary = shieldDailySummary
        weatherMissionStatusSummary = weatherMissionStatusBuilder.makeStatusSummary(
            board: indoorMissionBoard,
            status: weatherStatus,
            serverSummary: serverSummary,
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

    }

    /// member 세션에서 현재 홈 컨텍스트에 대응하는 서버 canonical 실내 미션 summary를 동기화합니다.
    /// - Parameters:
    ///   - missionContext: 선택 반려견 기준 실내 미션 컨텍스트입니다.
    ///   - baseWeatherStatus: 조회 시점의 기본 위험도 상태입니다.
    ///   - now: 서버 summary를 계산할 기준 시각입니다.
    func refreshIndoorMissionCanonicalSummaryIfNeeded(
        missionContext: IndoorMissionPetContext,
        baseWeatherStatus: IndoorWeatherStatus,
        now: Date
    ) {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            latestIndoorMissionCanonicalSummary = nil
            indoorMissionCanonicalSummaryTask?.cancel()
            return
        }
        guard let userId = userInfo?.id, userId.isEmpty == false else {
            latestIndoorMissionCanonicalSummary = nil
            indoorMissionCanonicalSummaryTask?.cancel()
            return
        }

        indoorMissionCanonicalSummaryTask?.cancel()
        indoorMissionCanonicalSummaryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await indoorMissionCanonicalSummaryService.fetchSummary(
                    context: missionContext,
                    baseRiskLevel: baseWeatherStatus.baseRisk,
                    now: now
                )
                indoorMissionCanonicalSummaryStore.save(summary)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    guard self.userInfo?.id == userId else { return }
                    self.latestIndoorMissionCanonicalSummary = summary
                    self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                }
            } catch {
                #if DEBUG
                print("[IndoorMissionCanonical] summary fetch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// 현재 홈 상태에 적용할 서버 canonical summary를 비동기로 재조회합니다.
    /// - Parameters:
    ///   - baseWeatherStatus: 조회 시점의 기본 위험도 상태입니다.
    ///   - now: 요청 기준 시각입니다.
    func refreshWeatherCanonicalSummaryIfNeeded(
        baseWeatherStatus: IndoorWeatherStatus,
        now: Date
    ) {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return
        }
        weatherReplacementSummaryTask?.cancel()
        weatherReplacementSummaryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await weatherReplacementSummaryService.fetchSummary(
                    baseRiskLevel: baseWeatherStatus.baseRisk,
                    now: now
                )
                weatherReplacementSummaryStore.save(summary)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                }
            } catch {
                #if DEBUG
                print("[HomeWeatherCanonical] summary fetch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func recordIndoorMissionAction(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        let now = Date()
        let baseWeatherStatus = indoorMissionStore.baseWeatherStatus(now: now)
        let missionContext = makeIndoorMissionPetContext(reference: now)

        if AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) {
            guard let canonicalMissionInstanceId = mission.canonicalMissionInstanceId else {
                indoorMissionStatusMessage = "서버 미션 정보를 다시 불러오는 중이에요."
                refreshIndoorMissionCanonicalSummaryIfNeeded(
                    missionContext: missionContext,
                    baseWeatherStatus: baseWeatherStatus,
                    now: now
                )
                return
            }

            let nextActionCount = mission.progress.actionCount + 1
            mission = .init(
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
                    actionCount: nextActionCount,
                    minimumActionCount: mission.minimumActionCount,
                    isCompleted: mission.progress.isCompleted
                ),
                canonicalMissionInstanceId: mission.canonicalMissionInstanceId,
                claimable: nextActionCount >= mission.minimumActionCount,
                rewardEligible: nextActionCount >= mission.minimumActionCount,
                source: mission.source
            )
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
                    "isExtension": mission.isExtension ? "true" : "false",
                    "mode": "server_canonical"
                ]
            )

            let requestId = "indoor-action-\(canonicalMissionInstanceId)-\(UUID().uuidString.lowercased())"
            Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await indoorMissionCanonicalSummaryService.recordAction(
                        missionInstanceId: canonicalMissionInstanceId,
                        requestId: requestId,
                        now: now
                    )
                    await MainActor.run {
                        if var currentMission = self.indoorMissionBoard.missions.first(where: { $0.id == mission.id }) {
                            currentMission = .init(
                                id: currentMission.id,
                                category: currentMission.category,
                                title: currentMission.title,
                                description: currentMission.description,
                                minimumActionCount: currentMission.minimumActionCount,
                                rewardPoint: currentMission.rewardPoint,
                                streakEligible: currentMission.streakEligible,
                                trackingMissionId: currentMission.trackingMissionId,
                                dayKey: currentMission.dayKey,
                                isExtension: currentMission.isExtension,
                                extensionSourceDayKey: currentMission.extensionSourceDayKey,
                                extensionRewardScale: currentMission.extensionRewardScale,
                                progress: .init(
                                    actionCount: result.actionCount,
                                    minimumActionCount: result.minimumActionCount,
                                    isCompleted: currentMission.progress.isCompleted
                                ),
                                canonicalMissionInstanceId: currentMission.canonicalMissionInstanceId,
                                claimable: result.claimable,
                                rewardEligible: result.claimable,
                                source: currentMission.source
                            )
                            self.indoorMissionBoard = self.indoorMissionBoard.updated(currentMission)
                            self.updateIndoorMissionPresentation()
                        }
                        self.refreshIndoorMissionCanonicalSummaryIfNeeded(
                            missionContext: missionContext,
                            baseWeatherStatus: baseWeatherStatus,
                            now: now
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.indoorMissionStatusMessage = "연결을 확인한 뒤 다시 시도해주세요."
                        self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                    }
                    #if DEBUG
                    print("[IndoorMissionCanonical] action submit failed: \(error.localizedDescription)")
                    #endif
                }
            }
            return
        }

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
                "isExtension": mission.isExtension ? "true" : "false",
                "mode": "guest_fallback"
            ]
        )
    }

    func finalizeIndoorMission(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        let now = Date()
        let baseWeatherStatus = indoorMissionStore.baseWeatherStatus(now: now)
        let missionContext = makeIndoorMissionPetContext(reference: now)

        if AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) {
            guard let canonicalMissionInstanceId = mission.canonicalMissionInstanceId else {
                indoorMissionStatusMessage = "보드 상태를 서버에서 다시 불러오는 중이에요."
                refreshIndoorMissionCanonicalSummaryIfNeeded(
                    missionContext: missionContext,
                    baseWeatherStatus: baseWeatherStatus,
                    now: now
                )
                return
            }

            indoorMissionStatusMessage = "보상 상태를 서버에서 확인 중이에요."
            let requestId = "indoor-claim-\(canonicalMissionInstanceId)-\(UUID().uuidString.lowercased())"
            Task { [weak self] in
                guard let self else { return }
                do {
                    let claimResult = try await indoorMissionCanonicalSummaryService.claimReward(
                        missionInstanceId: canonicalMissionInstanceId,
                        dayKey: indoorMissionBoard.dayKey,
                        petContextId: missionContext.petId,
                        requestId: requestId,
                        now: now
                    )
                    let refreshedSummary = try? await indoorMissionCanonicalSummaryService.fetchSummary(
                        context: missionContext,
                        baseRiskLevel: baseWeatherStatus.baseRisk,
                        now: now
                    )

                    await MainActor.run {
                        if let refreshedSummary {
                            self.indoorMissionCanonicalSummaryStore.save(refreshedSummary)
                            self.latestIndoorMissionCanonicalSummary = refreshedSummary
                        }

                        switch claimResult.claimStatusRawValue {
                        case "claimed":
                            if claimResult.alreadyClaimed == false {
                                self.questAlternativeActionSuggestion = nil
                                let seasonUpdate = self.seasonMotionStore.recordMissionCompletion(
                                    rewardPoint: claimResult.rewardPoints,
                                    streakEligible: mission.streakEligible,
                                    riskLevel: self.indoorMissionBoard.riskLevel
                                )
                                self.markSeasonCanonicalOptimisticWindow(now: now)
                                if seasonUpdate.shieldApplied {
                                    self.indoorMissionStore.recordWeatherShieldUsage()
                                }
                                self.seasonMotionSummary = seasonUpdate.summary
                                if let completedSeason = seasonUpdate.completedSeason {
                                    self.seasonResultPresentation = completedSeason
                                    self.seasonResetTransitionToken = UUID()
                                }
                                if seasonUpdate.scoreDelta > 0 || seasonUpdate.rankUp || seasonUpdate.shieldApplied {
                                    self.seasonMotionEvent = SeasonMotionEvent(
                                        type: seasonUpdate.rankUp ? .rankUp : .scoreIncreased,
                                        scoreDelta: seasonUpdate.scoreDelta,
                                        rankTier: seasonUpdate.summary.rankTier,
                                        shieldApplied: seasonUpdate.shieldApplied
                                    )
                                } else if seasonUpdate.completedSeason != nil {
                                    self.seasonMotionEvent = SeasonMotionEvent(
                                        type: .seasonReset,
                                        scoreDelta: 0,
                                        rankTier: seasonUpdate.summary.rankTier,
                                        shieldApplied: false
                                    )
                                }
                                self.questMotionEvent = QuestMotionEvent(
                                    missionId: mission.id,
                                    missionTitle: mission.title,
                                    type: .completed,
                                    progress: 1.0
                                )
                                self.questCompletionPresentation = QuestCompletionPresentation(
                                    missionId: mission.id,
                                    missionTitle: mission.title,
                                    rewardPoint: claimResult.rewardPoints
                                )
                                if mission.isExtension {
                                    self.indoorMissionStatusMessage = "\(mission.title) 연장 미션 완료! 감액 보상 \(claimResult.rewardPoints)pt"
                                    self.metricTracker.track(
                                        .indoorMissionExtensionConsumed,
                                        userKey: self.userInfo?.id,
                                        payload: [
                                            "missionId": mission.trackingMissionId,
                                            "reward": "\(claimResult.rewardPoints)",
                                            "rewardScale": String(format: "%.2f", mission.extensionRewardScale)
                                        ]
                                    )
                                } else {
                                    self.indoorMissionStatusMessage = "\(mission.title) 완료! 보상 \(claimResult.rewardPoints)pt"
                                }
                            } else {
                                self.indoorMissionStatusMessage = "이미 서버에서 완료 처리된 미션입니다."
                                self.questMotionEvent = QuestMotionEvent(
                                    missionId: mission.id,
                                    missionTitle: mission.title,
                                    type: .alreadyCompleted,
                                    progress: 1.0
                                )
                            }
                            self.metricTracker.track(
                                .indoorMissionCompleted,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "missionId": mission.trackingMissionId,
                                    "reward": "\(claimResult.rewardPoints)",
                                    "risk": self.indoorMissionBoard.riskLevel.rawValue,
                                    "isExtension": mission.isExtension ? "true" : "false",
                                    "alreadyClaimed": claimResult.alreadyClaimed ? "true" : "false",
                                    "mode": "server_canonical"
                                ]
                            )
                            self.refreshSeasonCanonicalSummaryIfNeeded(now: now)
                        case "rejected":
                            self.indoorMissionStatusMessage = "완료 기준을 채운 뒤 다시 시도해주세요."
                            self.questAlternativeActionSuggestion = "행동 +1을 더 기록하거나 실제 루틴 완료 후 다시 보상 받기를 눌러보세요."
                            self.questMotionEvent = QuestMotionEvent(
                                missionId: mission.id,
                                missionTitle: mission.title,
                                type: .failed,
                                progress: mission.progress.progressRatio
                            )
                            self.metricTracker.track(
                                .indoorMissionCompletionRejected,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "missionId": mission.trackingMissionId,
                                    "required": "\(mission.minimumActionCount)",
                                    "isExtension": mission.isExtension ? "true" : "false",
                                    "mode": "server_canonical"
                                ]
                            )
                        default:
                            self.indoorMissionStatusMessage = "보상 상태를 다시 확인해주세요."
                        }

                        self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                    }
                } catch {
                    await MainActor.run {
                        self.indoorMissionStatusMessage = "보상 수령에 실패했어요. 잠시 후 다시 시도해주세요."
                        self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                    }
                    #if DEBUG
                    print("[IndoorMissionCanonical] claim failed: \(error.localizedDescription)")
                    #endif
                }
            }
            return
        }

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
            markSeasonCanonicalOptimisticWindow(now: Date())
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
                    "isExtension": mission.isExtension ? "true" : "false",
                    "mode": "guest_fallback"
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
                    "isExtension": mission.isExtension ? "true" : "false",
                    "mode": "guest_fallback"
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
        let baseWeatherStatus = indoorMissionStore.baseWeatherStatus(now: now)

        if AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let outcome = try await weatherReplacementSummaryService.submitFeedback(
                        baseRiskLevel: baseWeatherStatus.baseRisk,
                        requestId: UUID().uuidString.lowercased(),
                        now: now
                    )
                    weatherReplacementSummaryStore.save(outcome.summary)
                    await MainActor.run {
                        self.weatherFeedbackRemainingCount = outcome.summary.feedbackRemainingCount
                        let hasRiskChanged = outcome.originalRisk != outcome.adjustedRisk
                        self.weatherFeedbackResultMessage = outcome.message
                        self.indoorMissionStatusMessage = outcome.message
                        if outcome.accepted {
                            self.metricTracker.track(
                                .weatherFeedbackSubmitted,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "fromRisk": outcome.originalRisk.rawValue,
                                    "toRisk": outcome.adjustedRisk.rawValue,
                                    "remainingQuota": "\(outcome.summary.feedbackRemainingCount)"
                                ]
                            )
                            self.metricTracker.track(
                                .weatherRiskReevaluated,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "fromRisk": outcome.originalRisk.rawValue,
                                    "toRisk": outcome.adjustedRisk.rawValue,
                                    "changed": hasRiskChanged ? "true" : "false"
                                ]
                            )
                        } else {
                            self.metricTracker.track(
                                .weatherFeedbackRateLimited,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "remainingQuota": "\(outcome.summary.feedbackRemainingCount)"
                                ]
                            )
                        }
                        self.refreshIndoorMissions(now: now, shouldFetchServerSummary: false)
                    }
                } catch {
                    await MainActor.run {
                        self.weatherFeedbackResultMessage = "연결을 확인한 뒤 다시 시도해주세요."
                        self.indoorMissionStatusMessage = self.weatherFeedbackResultMessage
                    }
                    #if DEBUG
                    print("[HomeWeatherCanonical] feedback submit failed: \(error.localizedDescription)")
                    #endif
                }
            }
            return
        }

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
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)",
                    "mode": "guest_fallback"
                ]
            )
            metricTracker.track(
                .weatherRiskReevaluated,
                userKey: userInfo?.id,
                payload: [
                    "fromRisk": outcome.originalRisk.rawValue,
                    "toRisk": outcome.adjustedRisk.rawValue,
                    "changed": hasRiskChanged ? "true" : "false",
                    "mode": "guest_fallback"
                ]
            )
        } else {
            weatherFeedbackResultMessage = outcome.message
            metricTracker.track(
                .weatherFeedbackRateLimited,
                userKey: userInfo?.id,
                payload: [
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)",
                    "mode": "guest_fallback"
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

        if AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) {
            let missionContext = makeIndoorMissionPetContext(reference: now)
            let baseWeatherStatus = indoorMissionStore.baseWeatherStatus(now: now)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await indoorMissionCanonicalSummaryService.activateEasyDay(
                        context: missionContext,
                        baseRiskLevel: baseWeatherStatus.baseRisk,
                        now: now
                    )
                    await MainActor.run {
                        switch result.outcomeRawValue {
                        case "activated":
                            self.indoorMissionStatusMessage = "쉬운 날 모드를 적용했어요. 오늘 보상은 20% 감액돼요."
                            self.metricTracker.track(
                                .indoorMissionEasyDayActivated,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "petId": difficulty.petId ?? "",
                                    "dayKey": self.indoorMissionBoard.dayKey,
                                    "rewardScale": "0.80",
                                    "mode": "server_canonical"
                                ]
                            )
                        case "already_used":
                            self.indoorMissionStatusMessage = "쉬운 날 모드는 하루에 한 번만 사용할 수 있어요."
                            self.metricTracker.track(
                                .indoorMissionEasyDayRejected,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "petId": difficulty.petId ?? "",
                                    "reason": "daily_limit",
                                    "mode": "server_canonical"
                                ]
                            )
                        case "missing_pet":
                            self.indoorMissionStatusMessage = "선택 반려견을 먼저 지정한 뒤 다시 시도해주세요."
                            self.metricTracker.track(
                                .indoorMissionEasyDayRejected,
                                userKey: self.userInfo?.id,
                                payload: [
                                    "reason": "missing_pet",
                                    "mode": "server_canonical"
                                ]
                            )
                        default:
                            self.indoorMissionStatusMessage = "쉬운 날 모드를 다시 확인해주세요."
                        }
                        self.refreshIndoorMissionCanonicalSummaryIfNeeded(
                            missionContext: missionContext,
                            baseWeatherStatus: baseWeatherStatus,
                            now: now
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.indoorMissionStatusMessage = "연결을 확인한 뒤 다시 시도해주세요."
                    }
                    #if DEBUG
                    print("[IndoorMissionCanonical] easy day failed: \(error.localizedDescription)")
                    #endif
                }
            }
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
                    "rewardScale": "0.80",
                    "mode": "guest_fallback"
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
                    "reason": "daily_limit",
                    "mode": "guest_fallback"
                ]
            )
        case .missingPet:
            indoorMissionStatusMessage = "선택 반려견을 먼저 지정한 뒤 다시 시도해주세요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "missing_pet",
                    "mode": "guest_fallback"
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

        markSeasonCanonicalOptimisticWindow(now: now)
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
            title: "실내 미션 전환 요약",
            reasonText: "강풍과 강수 위험 때문에 오늘은 산책 보조용 실내 대체 미션이 열렸습니다.",
            appliedAtText: "적용 시점 09:30",
            shieldUsageText: "보호 사용 1회",
            policyTitle: "실내 미션이 열리는 기준",
            policyText: "오늘은 산책이 어려워 실내 대체 미션 3개가 보조로 열렸고, 행동 +1은 실제로 끝낸 루틴만 기록하는 체크입니다.",
            lifecycleGuideText: "실내 미션을 진행했다면 기준 횟수를 채운 뒤 완료 확인을 눌러야 보상이 확정되고, 완료된 미션은 아래 아카이브로 이동합니다.",
            fallbackNotice: nil,
            accessibilityText: "실내 미션 전환 요약. 강풍과 강수 위험 때문에 실내 대체 미션이 열렸습니다.",
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
