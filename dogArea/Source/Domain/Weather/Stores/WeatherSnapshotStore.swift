import Foundation

protocol WeatherSnapshotStoreProtocol {
    /// 최신 날씨 스냅샷을 로컬 캐시에 저장합니다.
    /// - Parameter snapshot: 홈/맵/미션이 공통으로 사용할 최신 날씨 스냅샷입니다.
    func save(_ snapshot: WeatherSnapshot)

    /// 최신 날씨 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이며, 없거나 파싱 실패 시 `nil`입니다.
    func loadSnapshot() -> WeatherSnapshot?

    /// 최대 허용 나이 안에 있는 최신 날씨 스냅샷을 조회합니다.
    /// - Parameter maxAge: 관측 시각 기준 허용 최대 나이(초)입니다.
    /// - Returns: 유효한 최신 스냅샷이며, 없거나 만료됐으면 `nil`입니다.
    func loadFreshSnapshot(maxAge: TimeInterval) -> WeatherSnapshot?

    /// 저장된 날씨 스냅샷을 삭제합니다.
    func clear()
}

final class WeatherSnapshotStore: WeatherSnapshotStoreProtocol {
    static let shared = WeatherSnapshotStore()

    private enum Key {
        static let latestSnapshot = "weather.snapshot.latest.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.weather-snapshot-store.state")

    /// UserDefaults 기반 날씨 스냅샷 저장소를 생성합니다.
    /// - Parameter defaults: 스냅샷을 저장할 UserDefaults 인스턴스입니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 최신 날씨 스냅샷을 로컬 캐시에 저장합니다.
    /// - Parameter snapshot: 홈/맵/미션이 공통으로 사용할 최신 날씨 스냅샷입니다.
    func save(_ snapshot: WeatherSnapshot) {
        stateQueue.sync {
            guard let data = try? encoder.encode(snapshot) else { return }
            defaults.set(data, forKey: Key.latestSnapshot)
        }
    }

    /// 최신 날씨 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이며, 없거나 파싱 실패 시 `nil`입니다.
    func loadSnapshot() -> WeatherSnapshot? {
        stateQueue.sync {
            guard let data = defaults.data(forKey: Key.latestSnapshot) else { return nil }
            return try? decoder.decode(WeatherSnapshot.self, from: data)
        }
    }

    /// 최대 허용 나이 안에 있는 최신 날씨 스냅샷을 조회합니다.
    /// - Parameter maxAge: 관측 시각 기준 허용 최대 나이(초)입니다.
    /// - Returns: 유효한 최신 스냅샷이며, 없거나 만료됐으면 `nil`입니다.
    func loadFreshSnapshot(maxAge: TimeInterval) -> WeatherSnapshot? {
        guard let snapshot = loadSnapshot() else { return nil }
        let age = Date().timeIntervalSince1970 - snapshot.observedAt
        guard age <= maxAge else { return nil }
        return snapshot
    }

    /// 저장된 날씨 스냅샷을 삭제합니다.
    func clear() {
        stateQueue.sync {
            defaults.removeObject(forKey: Key.latestSnapshot)
        }
    }
}
