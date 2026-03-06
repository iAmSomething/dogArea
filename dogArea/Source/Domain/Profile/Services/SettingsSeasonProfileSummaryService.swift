import Foundation

/// 설정 화면의 시즌 진행 현황 요약을 로드하는 계약입니다.
protocol SettingsSeasonProfileSummaryProviding {
    /// 현재 저장된 시즌 진행 현황을 읽어 화면용 요약 모델로 변환합니다.
    /// - Returns: 저장된 시즌 상태가 있으면 요약 모델, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary() -> SeasonProfileSummary?
}

final class SettingsSeasonProfileSummaryService: SettingsSeasonProfileSummaryProviding {
    private struct StoredSeasonState: Decodable {
        let weekKey: String
        let score: Double
        let contributionCount: Int
    }

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder

    /// 시즌 진행 현황 서비스 의존성을 구성합니다.
    /// - Parameters:
    ///   - userDefaults: 시즌 상태 원본을 읽어올 `UserDefaults` 인스턴스입니다.
    ///   - decoder: 저장된 JSON을 역직렬화할 디코더입니다.
    init(
        userDefaults: UserDefaults = .standard,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.decoder = decoder
    }

    /// 현재 저장된 시즌 진행 현황을 읽어 화면용 요약 모델로 변환합니다.
    /// - Returns: 저장된 시즌 상태가 있으면 요약 모델, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary() -> SeasonProfileSummary? {
        guard let data = userDefaults.data(forKey: "season.motion.current.v1"),
              let decoded = try? decoder.decode(StoredSeasonState.self, from: data) else {
            return nil
        }

        return SeasonProfileSummary(
            weekKey: decoded.weekKey,
            score: Int(decoded.score.rounded()),
            rankTier: resolveRankTier(for: decoded.score),
            contributionCount: decoded.contributionCount
        )
    }

    /// 누적 점수에 대응하는 시즌 등급을 계산합니다.
    /// - Parameter score: 현재 누적 시즌 점수입니다.
    /// - Returns: 점수 정책에 맞는 시즌 등급입니다.
    private func resolveRankTier(for score: Double) -> SeasonRankTier {
        if score >= SeasonRankTier.platinum.minimumScore {
            return .platinum
        }
        if score >= SeasonRankTier.gold.minimumScore {
            return .gold
        }
        if score >= SeasonRankTier.silver.minimumScore {
            return .silver
        }
        if score >= SeasonRankTier.bronze.minimumScore {
            return .bronze
        }
        return .rookie
    }
}
