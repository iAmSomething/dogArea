import Foundation

protocol WeatherReplacementSummaryStoreProtocol {
    /// 최신 서버 canonical summary를 저장합니다.
    /// - Parameter summary: 날씨 치환/보호/피드백 canonical summary snapshot입니다.
    func save(_ summary: WeatherReplacementSummarySnapshot)

    /// 저장된 canonical summary를 조회합니다.
    /// - Parameter userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 저장된 snapshot이며, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary(for userId: String?) -> WeatherReplacementSummarySnapshot?

    /// 최대 허용 나이 안에 있는 canonical summary를 조회합니다.
    /// - Parameters:
    ///   - maxAge: 허용할 최대 snapshot 나이(초)입니다.
    ///   - userId: 현재 사용자 식별자입니다. 다른 사용자 snapshot이면 무시합니다.
    /// - Returns: 유효한 snapshot이며, 없거나 만료되면 `nil`입니다.
    func loadFreshSummary(maxAge: TimeInterval, for userId: String?) -> WeatherReplacementSummarySnapshot?

    /// 저장된 canonical summary를 삭제합니다.
    func clear()
}

final class WeatherReplacementSummaryStore: WeatherReplacementSummaryStoreProtocol {
    static let shared = WeatherReplacementSummaryStore()

    private enum Key {
        static let latestSummary = "weather.replacement.summary.latest.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.weather-replacement-summary-store.state")

    /// UserDefaults 기반 canonical summary 저장소를 생성합니다.
    /// - Parameter defaults: snapshot을 저장할 UserDefaults 인스턴스입니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 최신 서버 canonical summary를 저장합니다.
    /// - Parameter summary: 날씨 치환/보호/피드백 canonical summary snapshot입니다.
    func save(_ summary: WeatherReplacementSummarySnapshot) {
        stateQueue.sync {
            guard let data = try? encoder.encode(summary) else { return }
            defaults.set(data, forKey: Key.latestSummary)
        }
    }

    /// 저장된 canonical summary를 조회합니다.
    /// - Returns: 저장된 snapshot이며, 없거나 디코딩에 실패하면 `nil`입니다.
    func loadSummary(for userId: String?) -> WeatherReplacementSummarySnapshot? {
        stateQueue.sync {
            let normalizedUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let normalizedUserId, normalizedUserId.isEmpty == false else {
                return nil
            }
            guard let data = defaults.data(forKey: Key.latestSummary) else { return nil }
            guard let snapshot = try? decoder.decode(WeatherReplacementSummarySnapshot.self, from: data) else {
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
    func loadFreshSummary(maxAge: TimeInterval, for userId: String?) -> WeatherReplacementSummarySnapshot? {
        guard let snapshot = loadSummary(for: userId) else { return nil }
        let age = Date().timeIntervalSince1970 - snapshot.refreshedAt
        guard age <= maxAge else { return nil }
        return snapshot
    }

    /// 저장된 canonical summary를 삭제합니다.
    func clear() {
        stateQueue.sync {
            defaults.removeObject(forKey: Key.latestSummary)
        }
    }
}
