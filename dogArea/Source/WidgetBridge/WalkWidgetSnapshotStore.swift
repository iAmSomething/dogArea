import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

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

enum TerritoryWidgetSnapshotStatus: String, Codable {
    case memberReady = "member_ready"
    case guestLocked = "guest_locked"
    case emptyData = "empty_data"
    case offlineCached = "offline_cached"
    case syncDelayed = "sync_delayed"
}

struct TerritoryWidgetSummarySnapshot: Codable, Equatable {
    let todayTileCount: Int
    let weeklyTileCount: Int
    let defenseScheduledTileCount: Int
    let scoreUpdatedAt: TimeInterval?
    let refreshedAt: TimeInterval

    static let zero = TerritoryWidgetSummarySnapshot(
        todayTileCount: 0,
        weeklyTileCount: 0,
        defenseScheduledTileCount: 0,
        scoreUpdatedAt: nil,
        refreshedAt: Date().timeIntervalSince1970
    )
}

struct TerritoryWidgetSnapshot: Codable, Equatable {
    let status: TerritoryWidgetSnapshotStatus
    let message: String
    let summary: TerritoryWidgetSummarySnapshot?
    let updatedAt: TimeInterval

    static let initial = TerritoryWidgetSnapshot(
        status: .guestLocked,
        message: "로그인 후 내 영역 현황을 위젯에서 빠르게 확인해보세요.",
        summary: nil,
        updatedAt: Date().timeIntervalSince1970
    )
}

enum HotspotWidgetSignalLevel: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    case none = "none"
}

enum HotspotWidgetSnapshotStatus: String, Codable {
    case memberReady = "member_ready"
    case guestLocked = "guest_locked"
    case privacyGuarded = "privacy_guarded"
    case emptyData = "empty_data"
    case offlineCached = "offline_cached"
    case syncDelayed = "sync_delayed"
}

struct HotspotWidgetSummarySnapshot: Codable, Equatable {
    let signalLevel: HotspotWidgetSignalLevel
    let highCellCount: Int
    let mediumCellCount: Int
    let lowCellCount: Int
    let delayMinutes: Int
    let privacyMode: String
    let suppressionReason: String?
    let guideCopy: String
    let refreshedAt: TimeInterval

    static let zero = HotspotWidgetSummarySnapshot(
        signalLevel: .none,
        highCellCount: 0,
        mediumCellCount: 0,
        lowCellCount: 0,
        delayMinutes: 0,
        privacyMode: "none",
        suppressionReason: nil,
        guideCopy: "현재 주변 익명 핫스팟 신호가 충분하지 않습니다.",
        refreshedAt: Date().timeIntervalSince1970
    )
}

struct HotspotWidgetSnapshot: Codable, Equatable {
    let status: HotspotWidgetSnapshotStatus
    let message: String
    let summary: HotspotWidgetSummarySnapshot?
    let updatedAt: TimeInterval

    static let initial = HotspotWidgetSnapshot(
        status: .guestLocked,
        message: "로그인 후 익명 핫스팟 활성도 단계를 확인할 수 있어요.",
        summary: nil,
        updatedAt: Date().timeIntervalSince1970
    )
}

enum WalkLiveActivityAutoEndStage: String, Codable, Equatable, Hashable {
    case active = "active"
    case restCandidate = "rest_candidate"
    case warning = "warning"
    case autoEnding = "auto_ending"
    case ended = "ended"

    var title: String {
        switch self {
        case .active:
            return "정상 기록 중"
        case .restCandidate:
            return "휴식 후보 (5분)"
        case .warning:
            return "자동 종료 경고 (12분)"
        case .autoEnding:
            return "자동 종료 단계 (15분)"
        case .ended:
            return "산책 종료"
        }
    }

    var fallbackNotificationBody: String {
        switch self {
        case .active:
            return "산책 상태가 정상적으로 기록되고 있어요."
        case .restCandidate:
            return "5분 무이동 상태예요. 산책을 이어가면 단계가 해제돼요."
        case .warning:
            return "12분 무이동 상태예요. 3분 뒤 자동 종료될 수 있어요."
        case .autoEnding:
            return "15분 무이동으로 자동 종료 단계가 적용됐어요."
        case .ended:
            return "산책 세션이 종료됐어요."
        }
    }
}

struct WalkLiveActivityState: Equatable {
    let sessionId: String
    let startedAt: TimeInterval
    let isWalking: Bool
    let elapsedSeconds: Int
    let pointCount: Int
    let petName: String
    let autoEndStage: WalkLiveActivityAutoEndStage
    let statusMessage: String?
    let updatedAt: TimeInterval
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct WalkLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int
        let pointCount: Int
        let petName: String
        let autoEndStage: WalkLiveActivityAutoEndStage
        let statusMessage: String?
        let updatedAt: TimeInterval
    }

    let sessionId: String
    let startedAt: TimeInterval
}

@available(iOS 16.1, *)
extension WalkLiveActivityState {
    /// Live Activity 업데이트에 필요한 ContentState를 생성합니다.
    /// - Returns: 경과 시간/포인트/자동종료 단계를 포함한 상태 payload입니다.
    func makeContentState() -> WalkLiveActivityAttributes.ContentState {
        WalkLiveActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            pointCount: pointCount,
            petName: petName,
            autoEndStage: autoEndStage,
            statusMessage: statusMessage,
            updatedAt: updatedAt
        )
    }
}
#endif

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

protocol TerritoryWidgetSnapshotStoring {
    /// 영역 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> TerritoryWidgetSnapshot

    /// 영역 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 영역 스냅샷입니다.
    func save(_ snapshot: TerritoryWidgetSnapshot)
}

final class DefaultTerritoryWidgetSnapshotStore: TerritoryWidgetSnapshotStoring {
    static let shared = DefaultTerritoryWidgetSnapshotStore()

    private let storage: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// 영역 위젯 스냅샷 저장소를 초기화합니다.
    /// - Parameter storage: 스냅샷 직렬화 데이터를 저장할 UserDefaults입니다.
    init(storage: UserDefaults = DefaultTerritoryWidgetSnapshotStore.resolveStorage()) {
        self.storage = storage
    }

    /// 영역 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> TerritoryWidgetSnapshot {
        guard
            let data = storage.data(forKey: WalkWidgetBridgeContract.territorySnapshotStorageKey),
            let decoded = try? decoder.decode(TerritoryWidgetSnapshot.self, from: data)
        else {
            return .initial
        }
        return decoded
    }

    /// 영역 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 영역 스냅샷입니다.
    func save(_ snapshot: TerritoryWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.territorySnapshotStorageKey)
    }

    /// App Group 저장소를 우선 사용하고, 실패 시 표준 저장소를 반환합니다.
    /// - Returns: 위젯과 앱 간 공유 가능한 UserDefaults 인스턴스입니다.
    private static func resolveStorage() -> UserDefaults {
        UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
    }
}

protocol HotspotWidgetSnapshotStoring {
    /// 핫스팟 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> HotspotWidgetSnapshot

    /// 핫스팟 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 핫스팟 스냅샷입니다.
    func save(_ snapshot: HotspotWidgetSnapshot)
}

final class DefaultHotspotWidgetSnapshotStore: HotspotWidgetSnapshotStoring {
    static let shared = DefaultHotspotWidgetSnapshotStore()

    private let storage: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// 핫스팟 위젯 스냅샷 저장소를 초기화합니다.
    /// - Parameter storage: 스냅샷 직렬화 데이터를 저장할 UserDefaults입니다.
    init(storage: UserDefaults = DefaultHotspotWidgetSnapshotStore.resolveStorage()) {
        self.storage = storage
    }

    /// 핫스팟 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> HotspotWidgetSnapshot {
        guard
            let data = storage.data(forKey: WalkWidgetBridgeContract.hotspotSnapshotStorageKey),
            let decoded = try? decoder.decode(HotspotWidgetSnapshot.self, from: data)
        else {
            return .initial
        }
        return decoded
    }

    /// 핫스팟 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 핫스팟 스냅샷입니다.
    func save(_ snapshot: HotspotWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.hotspotSnapshotStorageKey)
    }

    /// App Group 저장소를 우선 사용하고, 실패 시 표준 저장소를 반환합니다.
    /// - Returns: 위젯과 앱 간 공유 가능한 UserDefaults 인스턴스입니다.
    private static func resolveStorage() -> UserDefaults {
        UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
    }
}
