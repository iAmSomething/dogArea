import Foundation

struct SupabaseSyncOutboxTransport: WalkSyncServiceProtocol {
    private struct BackfillSummaryResponseDTO: Decodable {
        let summary: SummaryDTO?

        struct SummaryDTO: Decodable {
            let sessionCount: Int
            let pointCount: Int
            let totalAreaM2: Double
            let totalDurationSec: Double

            enum CodingKeys: String, CodingKey {
                case sessionCount = "session_count"
                case pointCount = "point_count"
                case totalAreaM2 = "total_area_m2"
                case totalDurationSec = "total_duration_sec"
            }
        }
    }

    private struct SyncStageResponseDTO: Decodable {
        let seasonScoreSummary: SeasonScoreSummaryDTO?
        let seasonCanonicalSummary: SeasonCanonicalSummaryDTO?
        let indoorMissionCanonicalSummary: IndoorMissionCanonicalSummaryDTO?
        let weatherReplacementSummary: WeatherReplacementSummaryDTO?

        enum CodingKeys: String, CodingKey {
            case seasonScoreSummary = "season_score_summary"
            case seasonCanonicalSummary = "season_canonical_summary"
            case indoorMissionCanonicalSummary = "indoor_mission_canonical_summary"
            case weatherReplacementSummary = "weather_replacement_summary"
        }
    }

    private struct SeasonCanonicalSummaryDTO: Decodable {
        let currentSeasonId: String?
        let currentSeasonKey: String?
        let currentWeekKey: String?
        let currentStatus: String?
        let currentScore: Double?
        let currentTargetScore: Double?
        let currentProgress: Double?
        let currentRankTier: String?
        let currentTodayScoreDelta: Int?
        let currentContributionCount: Int?
        let currentWeatherShieldApplyCount: Int?
        let currentScoreUpdatedAt: String?
        let currentLastContributionAt: String?
        let latestCompletedSeasonId: String?
        let latestCompletedWeekKey: String?
        let latestCompletedRankTier: String?
        let latestCompletedTotalScore: Int?
        let latestCompletedContributionCount: Int?
        let latestCompletedWeatherShieldApplyCount: Int?
        let latestCompletedRewardCode: String?
        let latestCompletedRewardStatus: String?
        let latestCompletedRewardClaimedAt: String?
        let latestCompletedCompletedAt: String?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case currentSeasonId = "current_season_id"
            case currentSeasonKey = "current_season_key"
            case currentWeekKey = "current_week_key"
            case currentStatus = "current_status"
            case currentScore = "current_score"
            case currentTargetScore = "current_target_score"
            case currentProgress = "current_progress"
            case currentRankTier = "current_rank_tier"
            case currentTodayScoreDelta = "current_today_score_delta"
            case currentContributionCount = "current_contribution_count"
            case currentWeatherShieldApplyCount = "current_weather_shield_apply_count"
            case currentScoreUpdatedAt = "current_score_updated_at"
            case currentLastContributionAt = "current_last_contribution_at"
            case latestCompletedSeasonId = "latest_completed_season_id"
            case latestCompletedWeekKey = "latest_completed_week_key"
            case latestCompletedRankTier = "latest_completed_rank_tier"
            case latestCompletedTotalScore = "latest_completed_total_score"
            case latestCompletedContributionCount = "latest_completed_contribution_count"
            case latestCompletedWeatherShieldApplyCount = "latest_completed_weather_shield_apply_count"
            case latestCompletedRewardCode = "latest_completed_reward_code"
            case latestCompletedRewardStatus = "latest_completed_reward_status"
            case latestCompletedRewardClaimedAt = "latest_completed_reward_claimed_at"
            case latestCompletedCompletedAt = "latest_completed_completed_at"
            case refreshedAt = "refreshed_at"
        }
    }

    private struct WeatherReplacementSummaryDTO: Decodable {
        let applied: Bool?
        let blockedReason: String?
        let baseRiskLevel: String?
        let effectiveRiskLevel: String?
        let riskLevel: String?
        let replacementReason: String?
        let replacementCountToday: Int?
        let dailyReplacementLimit: Int?
        let shieldUsedThisWeek: Int?
        let weeklyShieldLimit: Int?
        let shieldApplyCountToday: Int?
        let shieldLastAppliedAt: String?
        let feedbackUsedThisWeek: Int?
        let weeklyFeedbackLimit: Int?
        let feedbackRemainingCount: Int?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case applied
            case blockedReason = "blocked_reason"
            case baseRiskLevel = "base_risk_level"
            case effectiveRiskLevel = "effective_risk_level"
            case riskLevel = "risk_level"
            case replacementReason = "replacement_reason"
            case replacementCountToday = "replacement_count_today"
            case dailyReplacementLimit = "daily_replacement_limit"
            case shieldUsedThisWeek = "shield_used_this_week"
            case weeklyShieldLimit = "weekly_shield_limit"
            case shieldApplyCountToday = "shield_apply_count_today"
            case shieldLastAppliedAt = "shield_last_applied_at"
            case feedbackUsedThisWeek = "feedback_used_this_week"
            case weeklyFeedbackLimit = "weekly_feedback_limit"
            case feedbackRemainingCount = "feedback_remaining_count"
            case refreshedAt = "refreshed_at"
        }
    }

    private struct IndoorMissionCanonicalHistoryDTO: Decodable {
        let dayKey: String?
        let petId: String?
        let petName: String?
        let multiplier: Double?
        let ageBand: String?
        let activityLevel: String?
        let walkFrequency: String?
        let easyDayApplied: Bool?
    }

    private struct IndoorMissionCanonicalMissionDTO: Decodable {
        let missionInstanceId: String?
        let templateId: String?
        let category: String?
        let title: String?
        let description: String?
        let minimumActionCount: Int?
        let rewardPoint: Int?
        let streakEligible: Bool?
        let trackingDayKey: String?
        let isExtension: Bool?
        let extensionSourceDayKey: String?
        let extensionRewardScale: Double?
        let actionCount: Int?
        let claimable: Bool?
        let rewardEligible: Bool?
        let claimedAt: String?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case missionInstanceId = "mission_instance_id"
            case templateId = "template_id"
            case category
            case title
            case description
            case minimumActionCount = "minimum_action_count"
            case rewardPoint = "reward_point"
            case streakEligible = "streak_eligible"
            case trackingDayKey = "tracking_day_key"
            case isExtension = "is_extension"
            case extensionSourceDayKey = "extension_source_day_key"
            case extensionRewardScale = "extension_reward_scale"
            case actionCount = "action_count"
            case claimable
            case rewardEligible = "reward_eligible"
            case claimedAt = "claimed_at"
            case status
        }
    }

    private struct IndoorMissionCanonicalSummaryDTO: Decodable {
        let ownerUserId: String?
        let petContextId: String?
        let dayKey: String?
        let baseRiskLevel: String?
        let effectiveRiskLevel: String?
        let extensionState: String?
        let extensionMessage: String?
        let petName: String?
        let ageBand: String?
        let activityLevel: String?
        let walkFrequency: String?
        let appliedMultiplier: Double?
        let adjustmentDescription: String?
        let adjustmentReasons: [String]?
        let easyDayState: String?
        let easyDayMessage: String?
        let history: [IndoorMissionCanonicalHistoryDTO]?
        let missions: [IndoorMissionCanonicalMissionDTO]?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case ownerUserId = "owner_user_id"
            case petContextId = "pet_context_id"
            case dayKey = "day_key"
            case baseRiskLevel = "base_risk_level"
            case effectiveRiskLevel = "effective_risk_level"
            case extensionState = "extension_state"
            case extensionMessage = "extension_message"
            case petName = "pet_name"
            case ageBand = "age_band"
            case activityLevel = "activity_level"
            case walkFrequency = "walk_frequency"
            case appliedMultiplier = "applied_multiplier"
            case adjustmentDescription = "adjustment_description"
            case adjustmentReasons = "adjustment_reasons"
            case easyDayState = "easy_day_state"
            case easyDayMessage = "easy_day_message"
            case history
            case missions
            case refreshedAt = "refreshed_at"
        }
    }

    private struct SeasonScoreSummaryDTO: Decodable {
        let catchupBonus: Double?
        let catchupBuffActive: Bool?
        let catchupBuffGrantedAt: String?
        let catchupBuffExpiresAt: String?
        let explain: ExplainDTO?

        enum CodingKeys: String, CodingKey {
            case catchupBonus = "catchup_bonus"
            case catchupBuffActive = "catchup_buff_active"
            case catchupBuffGrantedAt = "catchup_buff_granted_at"
            case catchupBuffExpiresAt = "catchup_buff_expires_at"
            case explain
        }
    }

    private struct ExplainDTO: Decodable {
        let uiReason: String?
        let catchupBuff: CatchupBuffDTO?

        enum CodingKeys: String, CodingKey {
            case uiReason = "ui_reason"
            case catchupBuff = "catchup_buff"
        }
    }

    private struct CatchupBuffDTO: Decodable {
        let status: String?
        let blockReason: String?
        let grantedAt: String?
        let expiresAt: String?
        let bonusScore: Double?

        enum CodingKeys: String, CodingKey {
            case status
            case blockReason = "block_reason"
            case grantedAt = "granted_at"
            case expiresAt = "expires_at"
            case bonusScore = "bonus_score"
        }
    }

    private enum SyncWalkFunctionRoute {
        static let primary = "sync-walk"
        static let legacy = "sync_walk"
    }

    private static let syncWalkFunctionUnavailableUntilKey = "sync.walk.function.unavailable.until.v1"
    private static let syncWalkFunctionUnavailableCooldownSeconds: TimeInterval = 10 * 60

    private let client: SupabaseHTTPClient
    private let availabilityStore: UserDefaults

    init(
        client: SupabaseHTTPClient = .live,
        availabilityStore: UserDefaults = .standard
    ) {
        self.client = client
        self.availabilityStore = availabilityStore
    }

    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            #if DEBUG
            print("[SyncTransport] blocked: cloudSync unavailable stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .retryable(.unauthorized)
        }
        guard isSyncWalkFunctionTemporarilyUnavailable() == false else {
            #if DEBUG
            print("[SyncTransport] blocked: sync-walk cooldown stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .permanent(.notConfigured)
        }

        let body: [String: Any] = [
            "action": "sync_walk_stage",
            "walk_session_id": item.walkSessionId,
            "stage": item.stage.rawValue,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]

        do {
            let data = try await requestSyncWalkFunction(
                bodyData: try JSONSerialization.data(withJSONObject: body)
            )
            clearSyncWalkFunctionUnavailableMarker()
            persistSeasonCatchupBuffSnapshotIfNeeded(item: item, data: data)
            #if DEBUG
            print("[SyncTransport] success stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .success
        } catch let error as SupabaseHTTPError {
            #if DEBUG
            print("[SyncTransport] http-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            switch error {
            case .notConfigured:
                markSyncWalkFunctionTemporarilyUnavailable()
                return .permanent(.notConfigured)
            case .unexpectedStatusCode(let statusCode):
                switch statusCode {
                case 401, 403:
                    return .retryable(.tokenExpired)
                case 409:
                    return .permanent(.conflict)
                case 429, 500..<600:
                    return .retryable(.serverError)
                case 404:
                    markSyncWalkFunctionTemporarilyUnavailable()
                    return .permanent(.notConfigured)
                case 400, 422:
                    return .permanent(.schemaMismatch)
                case 507:
                    return .permanent(.storageQuota)
                default:
                    return .retryable(.unknown)
                }
            default:
                return .retryable(.unknown)
            }
        } catch let error as URLError {
            #if DEBUG
            print("[SyncTransport] url-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .retryable(.offline)
            case .userAuthenticationRequired:
                return .retryable(.tokenExpired)
            default:
                return .retryable(.unknown)
            }
        } catch {
            #if DEBUG
            print("[SyncTransport] unknown-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            return .retryable(.unknown)
        }
    }

    func fetchBackfillValidationSummary(sessionIds: [String]) async -> SyncBackfillValidationSummary? {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            #if DEBUG
            print("[SyncTransport] validate-backfill blocked: cloudSync unavailable")
            #endif
            return nil
        }
        guard isSyncWalkFunctionTemporarilyUnavailable() == false else {
            #if DEBUG
            print("[SyncTransport] validate-backfill blocked: sync-walk cooldown")
            #endif
            return nil
        }
        let normalized = sessionIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.isEmpty == false }
        guard normalized.isEmpty == false else {
            return SyncBackfillValidationSummary(sessionCount: 0, pointCount: 0, totalAreaM2: 0, totalDurationSec: 0)
        }
        #if DEBUG
        print("[SyncTransport] validate-backfill request sessions=\(normalized.count)")
        #endif

        let body: [String: Any] = [
            "action": "validate_backfill",
            "session_ids": normalized
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        let data: Data
        do {
            data = try await requestSyncWalkFunction(bodyData: bodyData)
            clearSyncWalkFunctionUnavailableMarker()
        } catch let error as SupabaseHTTPError {
            #if DEBUG
            print("[SyncTransport] validate-backfill http-error=\(error.localizedDescription)")
            #endif
            if case .notConfigured = error {
                markSyncWalkFunctionTemporarilyUnavailable()
            } else if case .unexpectedStatusCode(404) = error {
                markSyncWalkFunctionTemporarilyUnavailable()
            }
            return nil
        } catch {
            #if DEBUG
            print("[SyncTransport] validate-backfill unknown-error=\(error.localizedDescription)")
            #endif
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(BackfillSummaryResponseDTO.self, from: data),
              let summary = decoded.summary else {
            #if DEBUG
            print("[SyncTransport] validate-backfill decode-failed")
            #endif
            return nil
        }
        #if DEBUG
        print(
            "[SyncTransport] validate-backfill success sessions=\(summary.sessionCount) points=\(summary.pointCount)"
        )
        #endif

        return SyncBackfillValidationSummary(
            sessionCount: summary.sessionCount,
            pointCount: summary.pointCount,
            totalAreaM2: summary.totalAreaM2,
            totalDurationSec: summary.totalDurationSec
        )
    }

    /// `sync-walk` 함수 호출을 수행하고 404 발생 시 legacy 라우트(`sync_walk`)로 한 번 더 시도합니다.
    /// - Parameter bodyData: 함수 요청 본문(JSON) 데이터입니다.
    /// - Returns: 함수 응답 데이터입니다.
    private func requestSyncWalkFunction(bodyData: Data) async throws -> Data {
        do {
            return try await client.request(
                .function(name: SyncWalkFunctionRoute.primary),
                method: .post,
                bodyData: bodyData
            )
        } catch let error as SupabaseHTTPError {
            guard case .unexpectedStatusCode(404) = error else {
                throw error
            }
            return try await client.request(
                .function(name: SyncWalkFunctionRoute.legacy),
                method: .post,
                bodyData: bodyData
            )
        }
    }

    /// `sync-walk` 함수 404 감지 이후 쿨다운 중인지 확인합니다.
    /// - Parameter now: 쿨다운 만료 판정 기준 시각입니다.
    /// - Returns: 쿨다운이 남아 있으면 `true`입니다.
    private func isSyncWalkFunctionTemporarilyUnavailable(now: Date = Date()) -> Bool {
        let until = availabilityStore.double(forKey: Self.syncWalkFunctionUnavailableUntilKey)
        return until > now.timeIntervalSince1970
    }

    /// `sync-walk` 함수 404 발생 시 재시도 폭주를 방지하기 위해 쿨다운 마커를 기록합니다.
    /// - Parameter now: 쿨다운 만료시각 계산 기준 시각입니다.
    private func markSyncWalkFunctionTemporarilyUnavailable(now: Date = Date()) {
        let until = now.timeIntervalSince1970 + Self.syncWalkFunctionUnavailableCooldownSeconds
        availabilityStore.set(until, forKey: Self.syncWalkFunctionUnavailableUntilKey)
    }

    /// `sync-walk` 호출 성공 시 비가용 쿨다운 마커를 제거합니다.
    private func clearSyncWalkFunctionUnavailableMarker() {
        availabilityStore.removeObject(forKey: Self.syncWalkFunctionUnavailableUntilKey)
    }

    private func persistSeasonCatchupBuffSnapshotIfNeeded(item: SyncOutboxItem, data: Data) {
        guard item.stage == .points else { return }
        let decoded = try? JSONDecoder().decode(SyncStageResponseDTO.self, from: data)
        guard let season = decoded?.seasonScoreSummary else {
            persistSeasonCanonicalSummaryIfNeeded(item: item, response: decoded)
            persistIndoorMissionCanonicalSummaryIfNeeded(item: item, response: decoded)
            persistWeatherReplacementSummaryIfNeeded(item: item, response: decoded)
            return
        }

        let catchup = season.explain?.catchupBuff
        let status = SeasonCatchupBuffDisplayStatus(rawValue: catchup?.status ?? "")
            ?? (season.catchupBuffActive == true ? .active : .inactive)
        let snapshot = SeasonCatchupBuffSnapshot(
            walkSessionId: item.walkSessionId,
            status: status,
            isActive: season.catchupBuffActive ?? false,
            bonusScore: season.catchupBonus ?? catchup?.bonusScore ?? 0,
            uiReason: season.explain?.uiReason,
            blockReason: catchup?.blockReason,
            grantedAt: SupabaseISO8601.parseEpoch(season.catchupBuffGrantedAt ?? catchup?.grantedAt),
            expiresAt: SupabaseISO8601.parseEpoch(season.catchupBuffExpiresAt ?? catchup?.expiresAt),
            syncedAt: Date().timeIntervalSince1970
        )
        UserdefaultSetting.shared.updateSeasonCatchupBuffSnapshot(snapshot)
        persistSeasonCanonicalSummaryIfNeeded(item: item, response: decoded)
        persistIndoorMissionCanonicalSummaryIfNeeded(item: item, response: decoded)
        persistWeatherReplacementSummaryIfNeeded(item: item, response: decoded)
    }

    /// `sync-walk` points stage 응답에 포함된 시즌 canonical summary를 member cache로 저장합니다.
    /// - Parameters:
    ///   - item: 처리 중인 sync outbox 항목입니다.
    ///   - response: 디코딩된 sync points stage 응답입니다.
    private func persistSeasonCanonicalSummaryIfNeeded(
        item: SyncOutboxItem,
        response: SyncStageResponseDTO?
    ) {
        guard item.stage == .points,
              let summary = response?.seasonCanonicalSummary else {
            return
        }
        guard case .member(let userId) = AppFeatureGate.currentSession() else {
            return
        }

        let latestCompletedSeason: SeasonCanonicalCompletedSnapshot?
        if let seasonId = normalizedSeasonIdentifier(summary.latestCompletedSeasonId),
           let weekKey = normalizedWeekKey(summary.latestCompletedWeekKey) {
            latestCompletedSeason = SeasonCanonicalCompletedSnapshot(
                seasonId: seasonId,
                weekKey: weekKey,
                rankTier: resolvedSeasonRankTier(summary.latestCompletedRankTier),
                totalScore: max(0, summary.latestCompletedTotalScore ?? 0),
                contributionCount: max(0, summary.latestCompletedContributionCount ?? 0),
                weatherShieldApplyCount: max(0, summary.latestCompletedWeatherShieldApplyCount ?? 0),
                rewardCode: summary.latestCompletedRewardCode,
                rewardStatusRawValue: summary.latestCompletedRewardStatus ?? "unavailable",
                rewardClaimedAt: SupabaseISO8601.parseEpoch(summary.latestCompletedRewardClaimedAt),
                completedAt: SupabaseISO8601.parseEpoch(summary.latestCompletedCompletedAt)
            )
        } else {
            latestCompletedSeason = nil
        }

        let snapshot = SeasonCanonicalSummarySnapshot(
            ownerUserId: userId,
            seasonId: normalizedSeasonIdentifier(summary.currentSeasonId),
            seasonKey: summary.currentSeasonKey,
            weekKey: normalizedWeekKey(summary.currentWeekKey) ?? "",
            seasonCompletionStateRawValue: summary.currentStatus ?? "inactive",
            score: max(0, summary.currentScore ?? 0),
            targetScore: max(1, summary.currentTargetScore ?? 520),
            progress: min(1.0, max(0.0, summary.currentProgress ?? 0)),
            rankTier: resolvedSeasonRankTier(summary.currentRankTier),
            todayScoreDelta: max(0, summary.currentTodayScoreDelta ?? 0),
            contributionCount: max(0, summary.currentContributionCount ?? 0),
            weatherShieldApplyCount: max(0, summary.currentWeatherShieldApplyCount ?? 0),
            scoreUpdatedAt: SupabaseISO8601.parseEpoch(summary.currentScoreUpdatedAt),
            lastContributionAt: SupabaseISO8601.parseEpoch(summary.currentLastContributionAt),
            refreshedAt: SupabaseISO8601.parseEpoch(summary.refreshedAt) ?? Date().timeIntervalSince1970,
            latestCompletedSeason: latestCompletedSeason
        )
        SeasonCanonicalSummaryStore.shared.save(snapshot)
    }

    /// `sync-walk` points stage 응답에 포함된 날씨 canonical summary를 로컬 cache로 저장합니다.
    /// - Parameters:
    ///   - item: 처리 중인 sync outbox 항목입니다.
    ///   - response: 디코딩된 sync points stage 응답입니다.
    private func persistWeatherReplacementSummaryIfNeeded(
        item: SyncOutboxItem,
        response: SyncStageResponseDTO?
    ) {
        guard item.stage == .points,
              let summary = response?.weatherReplacementSummary else {
            return
        }
        guard case .member(let userId) = AppFeatureGate.currentSession() else {
            return
        }
        let baseRisk = IndoorWeatherRiskLevel(rawValue: summary.baseRiskLevel ?? "")
            ?? IndoorWeatherRiskLevel(rawValue: summary.riskLevel ?? "")
            ?? .clear
        let effectiveRisk = IndoorWeatherRiskLevel(rawValue: summary.effectiveRiskLevel ?? "")
            ?? IndoorWeatherRiskLevel(rawValue: summary.riskLevel ?? "")
            ?? baseRisk
        let snapshot = WeatherReplacementSummarySnapshot(
            ownerUserId: userId,
            baseRiskLevel: baseRisk,
            effectiveRiskLevel: effectiveRisk,
            replacementApplied: summary.applied ?? (effectiveRisk != .clear),
            blockedReason: summary.blockedReason,
            replacementReason: summary.replacementReason,
            replacementCountToday: max(0, summary.replacementCountToday ?? 0),
            dailyReplacementLimit: max(0, summary.dailyReplacementLimit ?? 0),
            shieldUsedThisWeek: max(0, summary.shieldUsedThisWeek ?? 0),
            weeklyShieldLimit: max(0, summary.weeklyShieldLimit ?? 0),
            shieldApplyCountToday: max(0, summary.shieldApplyCountToday ?? 0),
            shieldLastAppliedAt: SupabaseISO8601.parseEpoch(summary.shieldLastAppliedAt),
            feedbackUsedThisWeek: max(0, summary.feedbackUsedThisWeek ?? 0),
            weeklyFeedbackLimit: max(0, summary.weeklyFeedbackLimit ?? 0),
            feedbackRemainingCount: max(0, summary.feedbackRemainingCount ?? 0),
            refreshedAt: SupabaseISO8601.parseEpoch(summary.refreshedAt) ?? Date().timeIntervalSince1970
        )
        WeatherReplacementSummaryStore.shared.save(snapshot)
    }

    /// `sync-walk` points stage 응답에 포함된 실내 미션 canonical summary를 member cache로 저장합니다.
    /// - Parameters:
    ///   - item: 처리 중인 sync outbox 항목입니다.
    ///   - response: 디코딩된 sync points stage 응답입니다.
    private func persistIndoorMissionCanonicalSummaryIfNeeded(
        item: SyncOutboxItem,
        response: SyncStageResponseDTO?
    ) {
        guard item.stage == .points,
              let summary = response?.indoorMissionCanonicalSummary else {
            return
        }
        guard case .member(let userId) = AppFeatureGate.currentSession() else {
            return
        }

        let normalizedOwnerUserId = normalizedSeasonIdentifier(summary.ownerUserId) ?? normalizedSeasonIdentifier(userId)
        let resolvedPetContextId = normalizedSeasonIdentifier(summary.petContextId)
        let difficultySummary = IndoorMissionCanonicalDifficultySummarySnapshot(
            petId: resolvedPetContextId,
            petName: normalizedIndoorMissionPetName(summary.petName),
            ageBandRawValue: summary.ageBand ?? IndoorMissionPetAgeBand.unknown.rawValue,
            activityLevelRawValue: summary.activityLevel ?? IndoorMissionActivityLevel.moderate.rawValue,
            walkFrequencyRawValue: summary.walkFrequency ?? IndoorMissionWalkFrequencyBand.steady.rawValue,
            appliedMultiplier: max(0.75, min(1.25, summary.appliedMultiplier ?? 1.0)),
            adjustmentDescription: summary.adjustmentDescription ?? "기본 난이도 유지",
            adjustmentReasons: summary.adjustmentReasons ?? [],
            easyDayStateRawValue: summary.easyDayState ?? IndoorMissionEasyDayState.unavailable.rawValue,
            easyDayMessage: summary.easyDayMessage ?? "",
            history: (summary.history ?? []).map { entry in
                IndoorMissionCanonicalDifficultyHistorySnapshot(
                    dayKey: entry.dayKey ?? "",
                    petId: normalizedSeasonIdentifier(entry.petId),
                    petName: normalizedIndoorMissionPetName(entry.petName),
                    multiplier: max(0.75, min(1.25, entry.multiplier ?? 1.0)),
                    ageBandRawValue: entry.ageBand ?? IndoorMissionPetAgeBand.unknown.rawValue,
                    activityLevelRawValue: entry.activityLevel ?? IndoorMissionActivityLevel.moderate.rawValue,
                    walkFrequencyRawValue: entry.walkFrequency ?? IndoorMissionWalkFrequencyBand.steady.rawValue,
                    easyDayApplied: entry.easyDayApplied ?? false
                )
            }
        )

        let missions = (summary.missions ?? []).compactMap { mission -> IndoorMissionCanonicalMissionSnapshot? in
            guard let missionInstanceId = mission.missionInstanceId?.canonicalUUIDString,
                  let templateId = mission.templateId,
                  templateId.isEmpty == false else {
                return nil
            }
            return IndoorMissionCanonicalMissionSnapshot(
                missionInstanceId: missionInstanceId,
                templateId: templateId,
                categoryRawValue: mission.category ?? IndoorMissionCategory.recordCleanup.rawValue,
                title: mission.title ?? "",
                description: mission.description ?? "",
                minimumActionCount: max(1, mission.minimumActionCount ?? 1),
                rewardPoint: max(0, mission.rewardPoint ?? 0),
                streakEligible: mission.streakEligible ?? false,
                trackingDayKey: mission.trackingDayKey ?? summary.dayKey ?? "",
                isExtension: mission.isExtension ?? false,
                extensionSourceDayKey: mission.extensionSourceDayKey,
                extensionRewardScale: max(0, mission.extensionRewardScale ?? 1.0),
                actionCount: max(0, mission.actionCount ?? 0),
                claimable: mission.claimable ?? false,
                rewardEligible: mission.rewardEligible ?? false,
                claimedAt: SupabaseISO8601.parseEpoch(mission.claimedAt),
                statusRawValue: mission.status ?? "active"
            )
        }

        let snapshot = IndoorMissionCanonicalSummarySnapshot(
            ownerUserId: normalizedOwnerUserId,
            petContextId: resolvedPetContextId,
            dayKey: summary.dayKey ?? "",
            baseRiskLevel: IndoorWeatherRiskLevel(rawValue: summary.baseRiskLevel ?? "") ?? .clear,
            effectiveRiskLevel: IndoorWeatherRiskLevel(rawValue: summary.effectiveRiskLevel ?? "")
                ?? IndoorWeatherRiskLevel(rawValue: summary.baseRiskLevel ?? "")
                ?? .clear,
            extensionStateRawValue: summary.extensionState ?? IndoorMissionExtensionState.none.rawValue,
            extensionMessage: summary.extensionMessage,
            difficultySummary: difficultySummary,
            missions: missions,
            refreshedAt: SupabaseISO8601.parseEpoch(summary.refreshedAt) ?? Date().timeIntervalSince1970
        )
        IndoorMissionCanonicalSummaryStore.shared.save(snapshot)
    }

    /// 서버가 반환한 시즌 랭크 문자열을 앱 공용 시즌 랭크로 정규화합니다.
    /// - Parameter rawValue: 서버 응답의 시즌 랭크 문자열입니다.
    /// - Returns: 앱에서 사용할 시즌 랭크 값입니다.
    private func resolvedSeasonRankTier(_ rawValue: String?) -> SeasonRankTier {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case SeasonRankTier.bronze.rawValue:
            return .bronze
        case SeasonRankTier.silver.rawValue:
            return .silver
        case SeasonRankTier.gold.rawValue:
            return .gold
        case SeasonRankTier.platinum.rawValue:
            return .platinum
        default:
            return .rookie
        }
    }

    /// 시즌/주차 식별자를 캐시 키와 비교하기 쉬운 canonical 문자열로 정규화합니다.
    /// - Parameter value: 정규화할 원시 식별자 문자열입니다.
    /// - Returns: 비어 있지 않은 정규화 식별자이며, 없으면 `nil`입니다.
    private func normalizedSeasonIdentifier(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }
        return value.lowercased()
    }

    /// 서버가 내려준 시즌 주차 키를 비어 있지 않은 canonical 문자열로 정규화합니다.
    /// - Parameter value: 서버 응답의 원시 주차 키입니다.
    /// - Returns: 비어 있지 않은 주차 키이며, 없으면 `nil`입니다.
    private func normalizedWeekKey(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }
        return value
    }

    /// 서버가 내려준 반려견 이름을 UI 기본값과 호환되는 비어 있지 않은 문자열로 정규화합니다.
    /// - Parameter value: 서버 응답의 원시 반려견 이름입니다.
    /// - Returns: 비어 있지 않은 반려견 이름이며, 없으면 `강아지`입니다.
    private func normalizedIndoorMissionPetName(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return "강아지"
        }
        return value
    }
}

struct SupabaseProfileSyncTransport: ProfileSyncServiceProtocol {
    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func send(item: ProfileSyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return .retryable(.unauthorized)
        }

        var body: [String: Any] = [
            "action": "sync_profile_stage",
            "stage": item.stage.rawValue,
            "user_id": item.userId,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]
        body["pet_id"] = item.petId ?? NSNull()

        do {
            _ = try await client.request(
                .function(name: "sync-profile"),
                method: .post,
                bodyData: try JSONSerialization.data(withJSONObject: body)
            )
            return .success
        } catch let error as SupabaseHTTPError {
            switch error {
            case .notConfigured:
                return .permanent(.notConfigured)
            case .unexpectedStatusCode(let statusCode):
                switch statusCode {
                case 401, 403:
                    return .retryable(.tokenExpired)
                case 429, 500..<600:
                    return .retryable(.serverError)
                case 404:
                    return .permanent(.notConfigured)
                case 400, 422:
                    return .permanent(.schemaMismatch)
                case 507:
                    return .permanent(.storageQuota)
                default:
                    return .retryable(.unknown)
                }
            default:
                return .retryable(.unknown)
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .retryable(.offline)
            case .userAuthenticationRequired:
                return .retryable(.tokenExpired)
            default:
                return .retryable(.unknown)
            }
        } catch {
            return .retryable(.unknown)
        }
    }
}
