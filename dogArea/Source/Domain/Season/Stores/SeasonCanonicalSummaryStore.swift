import Foundation

protocol SeasonCanonicalSummaryStoreProtocol {
    /// 최신 서버 canonical summary를 저장합니다.
    /// - Parameter summary: 서버가 최종 확정한 시즌 summary snapshot입니다.
    func save(_ summary: SeasonCanonicalSummarySnapshot)

    /// 저장된 canonical summary를 조회합니다.
    /// - Parameter userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 저장된 snapshot이며, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary(for userId: String?) -> SeasonCanonicalSummarySnapshot?

    /// 최대 허용 나이 안에 있는 canonical summary를 조회합니다.
    /// - Parameters:
    ///   - maxAge: 허용할 최대 snapshot 나이(초)입니다.
    ///   - userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 유효한 snapshot이며, 없거나 만료되면 `nil`입니다.
    func loadFreshSummary(maxAge: TimeInterval, for userId: String?) -> SeasonCanonicalSummarySnapshot?

    /// 서버 claim 결과를 저장된 canonical summary에 반영합니다.
    /// - Parameters:
    ///   - result: 서버가 확정한 보상 수령 결과입니다.
    ///   - userId: 현재 사용자 식별자입니다.
    func applyClaimResult(_ result: SeasonRewardClaimServerResult, for userId: String?)

    /// 저장된 canonical summary를 삭제합니다.
    func clear()
}

final class SeasonCanonicalSummaryStore: SeasonCanonicalSummaryStoreProtocol {
    static let shared = SeasonCanonicalSummaryStore()

    private enum Key {
        static let latestSummary = "season.canonical.summary.latest.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.season-canonical-summary-store.state")

    /// UserDefaults 기반 시즌 canonical summary 저장소를 생성합니다.
    /// - Parameter defaults: snapshot을 저장할 UserDefaults 인스턴스입니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 최신 서버 canonical summary를 저장합니다.
    /// - Parameter summary: 서버가 최종 확정한 시즌 summary snapshot입니다.
    func save(_ summary: SeasonCanonicalSummarySnapshot) {
        stateQueue.sync {
            guard let data = try? encoder.encode(summary) else { return }
            defaults.set(data, forKey: Key.latestSummary)
        }
    }

    /// 저장된 canonical summary를 조회합니다.
    /// - Parameter userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 저장된 snapshot이며, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary(for userId: String?) -> SeasonCanonicalSummarySnapshot? {
        stateQueue.sync {
            let normalizedUserId = normalized(userId)
            guard let normalizedUserId else { return nil }
            guard let data = defaults.data(forKey: Key.latestSummary) else { return nil }
            guard let snapshot = try? decoder.decode(SeasonCanonicalSummarySnapshot.self, from: data) else {
                return nil
            }
            guard snapshot.ownerUserId == normalizedUserId else { return nil }
            return snapshot
        }
    }

    /// 최대 허용 나이 안에 있는 canonical summary를 조회합니다.
    /// - Parameters:
    ///   - maxAge: 허용할 최대 snapshot 나이(초)입니다.
    ///   - userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 유효한 snapshot이며, 없거나 만료되면 `nil`입니다.
    func loadFreshSummary(maxAge: TimeInterval, for userId: String?) -> SeasonCanonicalSummarySnapshot? {
        guard let snapshot = loadSummary(for: userId) else { return nil }
        let age = Date().timeIntervalSince1970 - snapshot.refreshedAt
        guard age <= maxAge else { return nil }
        return snapshot
    }

    /// 서버 claim 결과를 저장된 canonical summary에 반영합니다.
    /// - Parameters:
    ///   - result: 서버가 확정한 보상 수령 결과입니다.
    ///   - userId: 현재 사용자 식별자입니다.
    func applyClaimResult(_ result: SeasonRewardClaimServerResult, for userId: String?) {
        stateQueue.sync {
            guard let normalizedUserId = normalized(userId) else { return }
            guard let data = defaults.data(forKey: Key.latestSummary) else { return }
            guard var snapshot = try? decoder.decode(SeasonCanonicalSummarySnapshot.self, from: data) else { return }
            guard snapshot.ownerUserId == normalizedUserId else { return }
            guard let completed = snapshot.latestCompletedSeason else { return }
            let matchesSeasonId = result.seasonId?.lowercased() == completed.seasonId.lowercased()
            let matchesWeekKey = completed.weekKey == result.weekKey
            guard matchesSeasonId || matchesWeekKey else { return }

            snapshot = SeasonCanonicalSummarySnapshot(
                ownerUserId: snapshot.ownerUserId,
                seasonId: snapshot.seasonId,
                seasonKey: snapshot.seasonKey,
                weekKey: snapshot.weekKey,
                seasonCompletionStateRawValue: snapshot.seasonCompletionStateRawValue,
                score: snapshot.score,
                targetScore: snapshot.targetScore,
                progress: snapshot.progress,
                rankTier: snapshot.rankTier,
                todayScoreDelta: snapshot.todayScoreDelta,
                contributionCount: snapshot.contributionCount,
                weatherShieldApplyCount: snapshot.weatherShieldApplyCount,
                scoreUpdatedAt: snapshot.scoreUpdatedAt,
                lastContributionAt: snapshot.lastContributionAt,
                refreshedAt: result.refreshedAt,
                latestCompletedSeason: SeasonCanonicalCompletedSnapshot(
                    seasonId: completed.seasonId,
                    weekKey: completed.weekKey,
                    rankTier: completed.rankTier,
                    totalScore: completed.totalScore,
                    contributionCount: completed.contributionCount,
                    weatherShieldApplyCount: completed.weatherShieldApplyCount,
                    rewardCode: result.rewardCode ?? completed.rewardCode,
                    rewardStatusRawValue: result.claimStatusRawValue,
                    rewardClaimedAt: result.claimedAt ?? completed.rewardClaimedAt,
                    completedAt: completed.completedAt
                )
            )

            guard let updatedData = try? encoder.encode(snapshot) else { return }
            defaults.set(updatedData, forKey: Key.latestSummary)
        }
    }

    /// 저장된 canonical summary를 삭제합니다.
    func clear() {
        stateQueue.sync {
            defaults.removeObject(forKey: Key.latestSummary)
        }
    }

    /// 사용자 식별자를 cache key 비교용 문자열로 정규화합니다.
    /// - Parameter userId: 정규화할 사용자 식별자입니다.
    /// - Returns: 비어 있지 않은 정규화 사용자 식별자이며, 없으면 `nil`입니다.
    private func normalized(_ userId: String?) -> String? {
        guard let userId = userId?.trimmingCharacters(in: .whitespacesAndNewlines), userId.isEmpty == false else {
            return nil
        }
        return userId.lowercased()
    }
}
