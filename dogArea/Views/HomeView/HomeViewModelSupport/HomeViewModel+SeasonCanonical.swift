import Foundation

private enum SeasonCanonicalSummaryConstants {
    static let maxCacheAge: TimeInterval = 30 * 60
    static let optimisticWindow: TimeInterval = 8
}

extension HomeViewModel {
    /// member 세션에서 서버 canonical 시즌 summary를 cache 우선 전략으로 동기화합니다.
    /// - Parameter now: 서버 summary를 조회하고 fallback freshness를 판단할 기준 시각입니다.
    func refreshSeasonCanonicalSummaryIfNeeded(now: Date) {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            latestSeasonCanonicalSummary = nil
            seasonCanonicalSummaryTask?.cancel()
            return
        }
        guard let userId = userInfo?.id, userId.isEmpty == false else {
            latestSeasonCanonicalSummary = nil
            seasonCanonicalSummaryTask?.cancel()
            return
        }

        let localRefresh = seasonMotionStore.refresh(
            now: now,
            riskLevel: indoorMissionBoard.riskLevel
        )
        if let cachedSummary = seasonCanonicalSummaryStore.loadFreshSummary(
            maxAge: SeasonCanonicalSummaryConstants.maxCacheAge,
            for: userId
        ) {
            applyServerSeasonSummary(cachedSummary, localRefresh: localRefresh, now: now)
        }

        seasonCanonicalSummaryTask?.cancel()
        seasonCanonicalSummaryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await seasonCanonicalSummaryService.fetchSummary(now: now)
                seasonCanonicalSummaryStore.save(summary)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    guard self.userInfo?.id == userId else { return }
                    self.metricTracker.track(
                        .seasonCanonicalRefreshed,
                        userKey: userId,
                        payload: [
                            "weekKey": summary.weekKey,
                            "rankTier": summary.rankTier.rawValue
                        ]
                    )
                    let currentLocalRefresh = self.seasonMotionStore.refresh(
                        now: now,
                        riskLevel: self.indoorMissionBoard.riskLevel
                    )
                    self.applyServerSeasonSummary(summary, localRefresh: currentLocalRefresh, now: now)
                }
            } catch {
                #if DEBUG
                print("[SeasonCanonical] summary fetch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// 로컬 season fallback 결과를 홈 published 상태에 반영합니다.
    /// - Parameters:
    ///   - refresh: 로컬 `SeasonMotionStore`가 계산한 fallback summary/result입니다.
    ///   - now: 남은 시간과 reset 전환 시점을 계산할 기준 시각입니다.
    func applyLocalSeasonRefresh(_ refresh: SeasonMotionRefreshResult, now: Date) {
        seasonMotionSummary = refresh.summary
        seasonRemainingTimeText = seasonMotionStore.remainingTimeText(now: now)
        latestSeasonCanonicalSummary = seasonCanonicalSummaryStore.loadSummary(for: userInfo?.id)
        lastSeasonResultPresentation = seasonMotionStore.loadLastCompletedSeason()

        guard let completedSeason = refresh.completedSeason else { return }
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

    /// 서버 canonical summary를 홈 표시 상태에 덮어쓰되, 짧은 optimistic window 동안은 로컬 시즌 값을 우선합니다.
    /// - Parameters:
    ///   - summary: 서버가 최종 확정한 시즌 summary입니다.
    ///   - localRefresh: 현재 기기 로컬 fallback summary입니다.
    ///   - now: optimistic window와 잔여 시간 계산에 사용할 기준 시각입니다.
    func applyServerSeasonSummary(
        _ summary: SeasonCanonicalSummarySnapshot,
        localRefresh: SeasonMotionRefreshResult,
        now: Date
    ) {
        latestSeasonCanonicalSummary = summary
        seasonRemainingTimeText = seasonMotionStore.remainingTimeText(now: now)

        if shouldPreferOptimisticLocalSeasonSummary(now: now),
           summary.weekKey == localRefresh.summary.weekKey,
           localRefresh.summary.score >= summary.score {
            seasonMotionSummary = localRefresh.summary
        } else {
            seasonMotionSummary = makeSeasonMotionSummary(from: summary)
        }

        let localLastCompleted = seasonMotionStore.loadLastCompletedSeason()
        let canonicalLastCompleted = makeSeasonResultPresentation(from: summary.latestCompletedSeason)
        lastSeasonResultPresentation = canonicalLastCompleted ?? localLastCompleted

        if seasonResultPresentation == nil,
           let localCompletedSeason = localRefresh.completedSeason,
           canonicalLastCompleted == nil {
            seasonResultPresentation = localCompletedSeason
        }

        reconcileSeasonParityIfNeeded(localSummary: localRefresh.summary, serverSummary: summary)
    }

    /// 서버 canonical summary를 홈 시즌 카드용 프레젠테이션 모델로 변환합니다.
    /// - Parameter summary: 서버가 최종 확정한 시즌 summary입니다.
    /// - Returns: 홈 시즌 카드에서 사용할 요약 프레젠테이션입니다.
    func makeSeasonMotionSummary(from summary: SeasonCanonicalSummarySnapshot) -> SeasonMotionSummary {
        SeasonMotionSummary(
            weekKey: summary.weekKey,
            score: summary.score,
            targetScore: summary.targetScore,
            progress: summary.progress,
            rankTier: summary.rankTier,
            todayScoreDelta: summary.todayScoreDelta,
            contributionCount: summary.contributionCount,
            weatherShieldActive: summary.weatherShieldApplyCount > 0,
            weatherShieldApplyCount: summary.weatherShieldApplyCount
        )
    }

    /// 서버 canonical completed season snapshot을 결과 오버레이 프레젠테이션으로 변환합니다.
    /// - Parameter completedSeason: 서버가 확정한 최근 완료 시즌 snapshot입니다.
    /// - Returns: 시즌 결과 오버레이에 사용할 프레젠테이션이며, 없으면 `nil`입니다.
    func makeSeasonResultPresentation(from completedSeason: SeasonCanonicalCompletedSnapshot?) -> SeasonResultPresentation? {
        guard let completedSeason else { return nil }
        return SeasonResultPresentation(
            weekKey: completedSeason.weekKey,
            rankTier: completedSeason.rankTier,
            totalScore: completedSeason.totalScore,
            contributionCount: completedSeason.contributionCount,
            shieldApplyCount: completedSeason.weatherShieldApplyCount
        )
    }

    /// 서버 canonical completed season 정보에서 보상 상태를 해석합니다.
    /// - Parameter weekKey: 사용자가 보고 있는 시즌 결과의 주차 키입니다.
    /// - Returns: 서버가 확정한 보상 상태이며, 정보가 없으면 `.unavailable`입니다.
    func seasonRewardStatusFromCanonical(for weekKey: String) -> SeasonRewardClaimStatus {
        guard let completedSeason = latestSeasonCanonicalSummary?.latestCompletedSeason,
              completedSeason.weekKey == weekKey else {
            return .unavailable
        }
        return resolvedSeasonRewardStatus(rawValue: completedSeason.rewardStatusRawValue)
    }

    /// 서버 reward status 문자열을 앱 공용 보상 상태로 정규화합니다.
    /// - Parameter rawValue: 서버가 반환한 원시 reward status 문자열입니다.
    /// - Returns: 홈 결과 오버레이에서 사용할 시즌 보상 상태입니다.
    func resolvedSeasonRewardStatus(rawValue: String?) -> SeasonRewardClaimStatus {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case SeasonRewardClaimStatus.pending.rawValue:
            return .pending
        case SeasonRewardClaimStatus.claimed.rawValue:
            return .claimed
        case SeasonRewardClaimStatus.failed.rawValue:
            return .failed
        default:
            return .unavailable
        }
    }

    /// 로컬 fallback 값과 서버 canonical 값이 어긋날 때 디버그 로그와 metric으로 parity 불일치를 남깁니다.
    /// - Parameters:
    ///   - localSummary: 로컬 `SeasonMotionStore`가 계산한 fallback summary입니다.
    ///   - serverSummary: 서버가 최종 확정한 canonical summary입니다.
    func reconcileSeasonParityIfNeeded(
        localSummary: SeasonMotionSummary,
        serverSummary: SeasonCanonicalSummarySnapshot
    ) {
        let mismatchSignature = [
            localSummary.weekKey,
            serverSummary.weekKey,
            String(Int(localSummary.score.rounded())),
            String(Int(serverSummary.score.rounded())),
            localSummary.rankTier.rawValue,
            serverSummary.rankTier.rawValue,
            String(localSummary.contributionCount),
            String(serverSummary.contributionCount),
            String(localSummary.weatherShieldApplyCount),
            String(serverSummary.weatherShieldApplyCount)
        ].joined(separator: "|")

        guard mismatchSignature != lastSeasonCanonicalMismatchSignature else { return }
        guard localSummary.weekKey == serverSummary.weekKey else {
            lastSeasonCanonicalMismatchSignature = mismatchSignature
            metricTracker.track(
                .seasonCanonicalMismatchDetected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "week_key_mismatch",
                    "localWeekKey": localSummary.weekKey,
                    "serverWeekKey": serverSummary.weekKey
                ]
            )
            #if DEBUG
            print("[SeasonCanonical] week mismatch local=\(localSummary.weekKey) server=\(serverSummary.weekKey)")
            #endif
            return
        }

        let scoreMismatch = abs(localSummary.score - serverSummary.score) > 0.001
        let rankMismatch = localSummary.rankTier != serverSummary.rankTier
        let contributionMismatch = localSummary.contributionCount != serverSummary.contributionCount
        let shieldMismatch = localSummary.weatherShieldApplyCount != serverSummary.weatherShieldApplyCount
        guard scoreMismatch || rankMismatch || contributionMismatch || shieldMismatch else { return }

        lastSeasonCanonicalMismatchSignature = mismatchSignature
        metricTracker.track(
            .seasonCanonicalMismatchDetected,
            userKey: userInfo?.id,
            payload: [
                "weekKey": serverSummary.weekKey,
                "localScore": String(Int(localSummary.score.rounded())),
                "serverScore": String(Int(serverSummary.score.rounded())),
                "localRank": localSummary.rankTier.rawValue,
                "serverRank": serverSummary.rankTier.rawValue
            ]
        )
        #if DEBUG
        print(
            "[SeasonCanonical] parity mismatch week=\(serverSummary.weekKey) localScore=\(localSummary.score) serverScore=\(serverSummary.score) localRank=\(localSummary.rankTier.rawValue) serverRank=\(serverSummary.rankTier.rawValue)"
        )
        #endif
    }

    /// 짧은 optimistic 시즌 window를 시작해 서버 응답이 늦을 때도 현재 기기 UX를 안정적으로 유지합니다.
    /// - Parameter now: optimistic window 만료 시각을 계산할 기준 시각입니다.
    func markSeasonCanonicalOptimisticWindow(now: Date) {
        seasonCanonicalOptimisticUntil = now.timeIntervalSince1970 + SeasonCanonicalSummaryConstants.optimisticWindow
    }

    /// 현재 시점에서 로컬 optimistic 시즌 요약을 서버 summary보다 우선해야 하는지 판단합니다.
    /// - Parameter now: optimistic window 만료 여부를 판단할 기준 시각입니다.
    /// - Returns: optimistic local 요약을 우선해야 하면 `true`입니다.
    func shouldPreferOptimisticLocalSeasonSummary(now: Date) -> Bool {
        guard let optimisticUntil = seasonCanonicalOptimisticUntil else { return false }
        return optimisticUntil > now.timeIntervalSince1970
    }
}
