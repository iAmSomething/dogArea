import Foundation

struct SupabaseSeasonCanonicalSummaryService: SeasonCanonicalSummaryServicing {
    private struct SummaryRowDTO: Decodable {
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

    private struct ClaimRowDTO: Decodable {
        let seasonId: String?
        let weekKey: String?
        let rewardCode: String?
        let claimStatus: String?
        let alreadyClaimed: Bool?
        let claimedAt: String?
        let requestId: String?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case seasonId = "season_id"
            case weekKey = "week_key"
            case rewardCode = "reward_code"
            case claimStatus = "claim_status"
            case alreadyClaimed = "already_claimed"
            case claimedAt = "claimed_at"
            case requestId = "request_id"
            case refreshedAt = "refreshed_at"
        }
    }

    private let client: SupabaseHTTPClient

    /// Supabase RPC 기반 시즌 canonical summary 서비스를 생성합니다.
    /// - Parameter client: RPC 호출에 사용할 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 현재 사용자 기준 시즌 canonical summary를 조회합니다.
    /// - Parameter now: 서버가 summary를 계산할 기준 시각입니다.
    /// - Returns: 서버가 최종 확정한 시즌 summary snapshot입니다.
    func fetchSummary(now: Date) async throws -> SeasonCanonicalSummarySnapshot {
        let payload: [String: Any] = [
            "payload": [
                "in_now_ts": ISO8601DateFormatter().string(from: now)
            ]
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_owner_season_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let row = try decodeRow(SummaryRowDTO.self, from: data)
        return makeSummary(from: row, now: now)
    }

    /// 최근 완료 시즌 보상을 서버에서 검증하고 멱등 처리로 수령합니다.
    /// - Parameters:
    ///   - seasonId: 보상을 수령할 시즌 식별자입니다. 알 수 없으면 `nil`을 전달합니다.
    ///   - weekKey: 사용자가 보고 있는 시즌 주차 키입니다.
    ///   - requestId: 중복 요청을 안전하게 처리하기 위한 요청 식별자입니다.
    ///   - now: 서버가 claim을 처리할 기준 시각입니다.
    /// - Returns: 서버가 확정한 보상 수령 결과입니다.
    func claimReward(
        seasonId: String?,
        weekKey: String,
        requestId: String,
        now: Date
    ) async throws -> SeasonRewardClaimServerResult {
        var innerPayload: [String: Any] = [
            "in_week_key": weekKey,
            "in_request_id": normalizedRequestId(requestId),
            "in_now_ts": ISO8601DateFormatter().string(from: now),
            "in_source": "ios"
        ]
        if let seasonId, seasonId.isEmpty == false {
            innerPayload["in_season_id"] = seasonId
        }
        let payload: [String: Any] = ["payload": innerPayload]
        let data = try await client.request(
            .rest(path: "rpc/rpc_claim_season_reward"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let row = try decodeRow(ClaimRowDTO.self, from: data)
        return SeasonRewardClaimServerResult(
            seasonId: row.seasonId,
            weekKey: row.weekKey ?? weekKey,
            rewardCode: row.rewardCode,
            claimStatusRawValue: row.claimStatus ?? "failed",
            alreadyClaimed: row.alreadyClaimed ?? false,
            claimedAt: SupabaseISO8601.parseEpoch(row.claimedAt),
            requestId: row.requestId ?? normalizedRequestId(requestId),
            refreshedAt: SupabaseISO8601.parseEpoch(row.refreshedAt) ?? now.timeIntervalSince1970
        )
    }

    /// RPC 응답 데이터에서 단일 row를 정규화해 디코딩합니다.
    /// - Parameters:
    ///   - type: 디코딩할 row 타입입니다.
    ///   - data: RPC 원시 응답 데이터입니다.
    /// - Returns: 정규화된 단일 row입니다.
    private func decodeRow<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        if let row = try? decoder.decode(T.self, from: data) {
            return row
        }
        if let rows = try? decoder.decode([T].self, from: data), let first = rows.first {
            return first
        }
        throw SupabaseHTTPError.invalidResponse
    }

    /// 서버 DTO를 앱 공용 시즌 snapshot으로 정규화합니다.
    /// - Parameters:
    ///   - row: 서버가 반환한 summary row입니다.
    ///   - now: summary fallback 시 사용할 기준 시각입니다.
    /// - Returns: 앱이 재사용할 canonical summary snapshot입니다.
    private func makeSummary(from row: SummaryRowDTO, now: Date) -> SeasonCanonicalSummarySnapshot {
        let completedSeason: SeasonCanonicalCompletedSnapshot?
        if let completedSeasonId = normalizedId(row.latestCompletedSeasonId),
           let completedWeekKey = row.latestCompletedWeekKey, completedWeekKey.isEmpty == false {
            completedSeason = SeasonCanonicalCompletedSnapshot(
                seasonId: completedSeasonId,
                weekKey: completedWeekKey,
                rankTier: resolvedRankTier(row.latestCompletedRankTier),
                totalScore: max(0, row.latestCompletedTotalScore ?? 0),
                contributionCount: max(0, row.latestCompletedContributionCount ?? 0),
                weatherShieldApplyCount: max(0, row.latestCompletedWeatherShieldApplyCount ?? 0),
                rewardCode: row.latestCompletedRewardCode,
                rewardStatusRawValue: row.latestCompletedRewardStatus ?? "unavailable",
                rewardClaimedAt: SupabaseISO8601.parseEpoch(row.latestCompletedRewardClaimedAt),
                completedAt: SupabaseISO8601.parseEpoch(row.latestCompletedCompletedAt)
            )
        } else {
            completedSeason = nil
        }

        return SeasonCanonicalSummarySnapshot(
            ownerUserId: currentOwnerUserId(),
            seasonId: normalizedId(row.currentSeasonId),
            seasonKey: row.currentSeasonKey,
            weekKey: row.currentWeekKey ?? "",
            seasonCompletionStateRawValue: row.currentStatus ?? "inactive",
            score: max(0, row.currentScore ?? 0),
            targetScore: max(1, row.currentTargetScore ?? 520),
            progress: min(1.0, max(0.0, row.currentProgress ?? 0.0)),
            rankTier: resolvedRankTier(row.currentRankTier),
            todayScoreDelta: max(0, row.currentTodayScoreDelta ?? 0),
            contributionCount: max(0, row.currentContributionCount ?? 0),
            weatherShieldApplyCount: max(0, row.currentWeatherShieldApplyCount ?? 0),
            scoreUpdatedAt: SupabaseISO8601.parseEpoch(row.currentScoreUpdatedAt),
            lastContributionAt: SupabaseISO8601.parseEpoch(row.currentLastContributionAt),
            refreshedAt: SupabaseISO8601.parseEpoch(row.refreshedAt) ?? now.timeIntervalSince1970,
            latestCompletedSeason: completedSeason
        )
    }

    /// 서버 랭크 문자열을 앱 공용 시즌 랭크 타입으로 정규화합니다.
    /// - Parameter rawValue: 서버가 내려준 랭크 문자열입니다.
    /// - Returns: 앱에서 사용할 시즌 랭크입니다.
    private func resolvedRankTier(_ rawValue: String?) -> SeasonRankTier {
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

    /// request id를 RPC 멱등 처리용 canonical 형식으로 정규화합니다.
    /// - Parameter requestId: 정규화할 원시 request id입니다.
    /// - Returns: 비어 있지 않은 lowercased request id입니다.
    private func normalizedRequestId(_ requestId: String) -> String {
        let trimmed = requestId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? UUID().uuidString.lowercased() : trimmed
    }

    /// 문자열 식별자를 lowercased canonical UUID 텍스트로 정규화합니다.
    /// - Parameter value: 정규화할 원시 식별자 문자열입니다.
    /// - Returns: 비어 있지 않은 lowercased 식별자이며, 없으면 `nil`입니다.
    private func normalizedId(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }
        return value.lowercased()
    }

    /// 현재 인증 세션의 사용자 식별자를 canonical summary owner로 반환합니다.
    /// - Returns: 로그인 세션이 있으면 사용자 식별자, 없으면 `nil`입니다.
    private func currentOwnerUserId() -> String? {
        switch AppFeatureGate.currentSession() {
        case .guest:
            return nil
        case .member(let userId):
            return userId
        }
    }
}
