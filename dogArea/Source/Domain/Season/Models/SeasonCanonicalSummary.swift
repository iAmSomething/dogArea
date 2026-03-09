import Foundation

/// 서버가 최종 확정한 시즌 요약 snapshot입니다.
struct SeasonCanonicalSummarySnapshot: Codable, Equatable {
    let ownerUserId: String?
    let seasonId: String?
    let seasonKey: String?
    let weekKey: String
    let seasonCompletionStateRawValue: String
    let score: Double
    let targetScore: Double
    let progress: Double
    let rankTier: SeasonRankTier
    let todayScoreDelta: Int
    let contributionCount: Int
    let weatherShieldApplyCount: Int
    let scoreUpdatedAt: TimeInterval?
    let lastContributionAt: TimeInterval?
    let refreshedAt: TimeInterval
    let latestCompletedSeason: SeasonCanonicalCompletedSnapshot?
}

/// 서버가 확정한 최근 완료 시즌 snapshot입니다.
struct SeasonCanonicalCompletedSnapshot: Codable, Equatable {
    let seasonId: String
    let weekKey: String
    let rankTier: SeasonRankTier
    let totalScore: Int
    let contributionCount: Int
    let weatherShieldApplyCount: Int
    let rewardCode: String?
    let rewardStatusRawValue: String
    let rewardClaimedAt: TimeInterval?
    let completedAt: TimeInterval?
}

/// 서버가 반환한 시즌 보상 수령 결과입니다.
struct SeasonRewardClaimServerResult: Equatable {
    let seasonId: String?
    let weekKey: String
    let rewardCode: String?
    let claimStatusRawValue: String
    let alreadyClaimed: Bool
    let claimedAt: TimeInterval?
    let requestId: String
    let refreshedAt: TimeInterval
}

/// 시즌 canonical summary와 보상 수령을 조회하는 서비스 계약입니다.
protocol SeasonCanonicalSummaryServicing {
    /// 현재 사용자 기준 시즌 canonical summary를 조회합니다.
    /// - Parameter now: 서버가 summary를 계산할 기준 시각입니다.
    /// - Returns: 서버가 최종 확정한 시즌 summary snapshot입니다.
    func fetchSummary(now: Date) async throws -> SeasonCanonicalSummarySnapshot

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
    ) async throws -> SeasonRewardClaimServerResult
}
