import Foundation

enum WalkWidgetSnapshotStatus: String, Codable {
    case ready = "ready"
    case locationDenied = "location_denied"
    case sessionConflict = "session_conflict"
    case error = "error"
}

struct WalkWidgetSnapshot: Codable, Equatable {
    let isWalking: Bool
    let elapsedSeconds: Int
    let petName: String
    let status: WalkWidgetSnapshotStatus
    let statusMessage: String?
    let updatedAt: TimeInterval

    static let initial = WalkWidgetSnapshot(
        isWalking: false,
        elapsedSeconds: 0,
        petName: "반려견",
        status: .ready,
        statusMessage: nil,
        updatedAt: Date().timeIntervalSince1970
    )
}

protocol WalkWidgetSnapshotStoring {
    /// 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> WalkWidgetSnapshot

    /// 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 스냅샷입니다.
    func save(_ snapshot: WalkWidgetSnapshot)
}

final class DefaultWalkWidgetSnapshotStore: WalkWidgetSnapshotStoring {
    static let shared = DefaultWalkWidgetSnapshotStore()

    private let storage: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// 위젯 스냅샷 저장소를 초기화합니다.
    /// - Parameter storage: 스냅샷 직렬화 데이터를 저장할 UserDefaults입니다.
    init(storage: UserDefaults = DefaultWalkWidgetSnapshotStore.resolveStorage()) {
        self.storage = storage
    }

    /// 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> WalkWidgetSnapshot {
        guard
            let data = storage.data(forKey: WalkWidgetBridgeContract.snapshotStorageKey),
            let decoded = try? decoder.decode(WalkWidgetSnapshot.self, from: data)
        else {
            return .initial
        }
        return decoded
    }

    /// 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 스냅샷입니다.
    func save(_ snapshot: WalkWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.snapshotStorageKey)
    }

    /// App Group 저장소를 우선 사용하고, 실패 시 표준 저장소를 반환합니다.
    /// - Returns: 위젯과 앱 간 공유 가능한 UserDefaults 인스턴스입니다.
    private static func resolveStorage() -> UserDefaults {
        UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
    }
}

