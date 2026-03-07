import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WalkWidgetSnapshotStatus: String, Codable {
    case ready = "ready"
    case locationDenied = "location_denied"
    case sessionConflict = "session_conflict"
    case error = "error"
}

enum WalkWidgetActionPhase: String, Codable {
    case pending = "pending"
    case requiresAppOpen = "requires_app_open"
    case succeeded = "succeeded"
    case failed = "failed"
}

enum WalkWidgetActionFollowUp: String, Codable {
    case none = "none"
    case retry = "retry"
    case openApp = "open_app"
}

enum WalkWidgetStartPolicy: String, Codable {
    case selectedPetImmediate = "selected_pet_immediate"
    case selectedPetCountdown = "selected_pet_countdown"
    case fixedPetReserved = "fixed_pet_reserved"

    var detailText: String {
        switch self {
        case .selectedPetImmediate:
            return "현재 선택 반려견으로 바로 시작해요."
        case .selectedPetCountdown:
            return "현재 선택 반려견으로 카운트다운 시작해요."
        case .fixedPetReserved:
            return "고정 반려견 시작은 준비 중이에요."
        }
    }
}

enum WalkWidgetPetContextSource: String, Codable {
    case selectedPet = "selected_pet"
    case fallbackActivePet = "fallback_active_pet"
    case walkingLocked = "walking_locked"
    case noActivePet = "no_active_pet"

    var badgeTitle: String {
        switch self {
        case .selectedPet:
            return "선택 반려견"
        case .fallbackActivePet:
            return "자동 대체"
        case .walkingLocked:
            return "산책 고정"
        case .noActivePet:
            return "앱 확인"
        }
    }
}

struct WalkWidgetPetContext: Codable, Equatable {
    let petId: String?
    let petName: String
    let source: WalkWidgetPetContextSource
    let startPolicy: WalkWidgetStartPolicy
    let fallbackReason: String?

    var badgeTitle: String {
        source.badgeTitle
    }

    var detailText: String {
        switch source {
        case .selectedPet:
            return startPolicy.detailText
        case .fallbackActivePet:
            return fallbackReason ?? "선택 반려견을 찾지 못해 활성 반려견으로 조정했어요."
        case .walkingLocked:
            return "산책 시작 시 확정된 반려견을 유지해요."
        case .noActivePet:
            return "활성 반려견이 없어 앱에서 먼저 확인이 필요해요."
        }
    }

    var blocksInlineStart: Bool {
        source == .noActivePet
    }

    /// 이전 스냅샷 형식에서 반려견 문맥을 복원합니다.
    /// - Parameters:
    ///   - petName: 레거시 스냅샷에 저장된 반려견 이름입니다.
    ///   - isWalking: 현재 산책 진행 여부입니다.
    /// - Returns: 문맥 정보가 없던 스냅샷을 위한 기본 반려견 문맥입니다.
    static func legacyFallback(petName: String, isWalking: Bool) -> WalkWidgetPetContext {
        .init(
            petId: nil,
            petName: petName,
            source: isWalking ? .walkingLocked : .selectedPet,
            startPolicy: .selectedPetImmediate,
            fallbackReason: nil
        )
    }
}

struct WalkWidgetActionState: Codable, Equatable {
    let kind: WalkWidgetActionKind
    let phase: WalkWidgetActionPhase
    let followUp: WalkWidgetActionFollowUp
    let message: String
    let updatedAt: TimeInterval
    let expiresAt: TimeInterval?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date().timeIntervalSince1970 >= expiresAt
    }

    /// 산책 위젯 액션이 앱으로 전달되는 중인 상태를 생성합니다.
    /// - Parameters:
    ///   - kind: 처리 중인 산책 액션 종류입니다.
    ///   - now: 상태 생성 기준 시각입니다.
    /// - Returns: pending 단계와 기본 만료 시간을 포함한 액션 상태입니다.
    static func pending(kind: WalkWidgetActionKind, now: Date = Date()) -> WalkWidgetActionState {
        let message: String
        switch kind {
        case .startWalk:
            message = "산책 시작 요청을 보냈어요."
        case .endWalk:
            message = "산책 종료 요청을 보냈어요."
        case .openWalkTab, .claimQuestReward, .openQuestDetail, .openQuestRecovery, .openRivalTab:
            message = "앱에서 요청을 준비 중입니다."
        }
        return .init(
            kind: kind,
            phase: .pending,
            followUp: .none,
            message: message,
            updatedAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(20).timeIntervalSince1970
        )
    }

    /// 앱에서 최종 확인이 필요한 위젯 액션 상태를 생성합니다.
    /// - Parameters:
    ///   - kind: 확인이 필요한 산책 액션 종류입니다.
    ///   - message: 사용자에게 노출할 안내 문구입니다.
    ///   - now: 상태 생성 기준 시각입니다.
    /// - Returns: app-open 후속 동작을 포함한 액션 상태입니다.
    static func requiresAppOpen(
        kind: WalkWidgetActionKind,
        message: String,
        now: Date = Date()
    ) -> WalkWidgetActionState {
        .init(
            kind: kind,
            phase: .requiresAppOpen,
            followUp: .openApp,
            message: message,
            updatedAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(30).timeIntervalSince1970
        )
    }

    /// 산책 위젯 액션 성공 상태를 생성합니다.
    /// - Parameters:
    ///   - kind: 성공한 산책 액션 종류입니다.
    ///   - message: 사용자에게 노출할 성공 문구입니다.
    ///   - now: 상태 생성 기준 시각입니다.
    /// - Returns: 성공 단계와 짧은 노출 시간을 가진 액션 상태입니다.
    static func succeeded(
        kind: WalkWidgetActionKind,
        message: String,
        now: Date = Date()
    ) -> WalkWidgetActionState {
        .init(
            kind: kind,
            phase: .succeeded,
            followUp: .none,
            message: message,
            updatedAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(12).timeIntervalSince1970
        )
    }

    /// 산책 위젯 액션 실패 상태를 생성합니다.
    /// - Parameters:
    ///   - kind: 실패한 산책 액션 종류입니다.
    ///   - followUp: 실패 후 추천할 다음 행동입니다.
    ///   - message: 사용자에게 노출할 실패 문구입니다.
    ///   - now: 상태 생성 기준 시각입니다.
    /// - Returns: 실패 단계와 후속 행동을 포함한 액션 상태입니다.
    static func failed(
        kind: WalkWidgetActionKind,
        followUp: WalkWidgetActionFollowUp,
        message: String,
        now: Date = Date()
    ) -> WalkWidgetActionState {
        .init(
            kind: kind,
            phase: .failed,
            followUp: followUp,
            message: message,
            updatedAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(30).timeIntervalSince1970
        )
    }
}

struct WalkWidgetSnapshot: Codable, Equatable {
    let isWalking: Bool
    let elapsedSeconds: Int
    let petName: String
    let petContext: WalkWidgetPetContext?
    let status: WalkWidgetSnapshotStatus
    let statusMessage: String?
    let actionState: WalkWidgetActionState?
    let updatedAt: TimeInterval

    var normalizedPetContext: WalkWidgetPetContext {
        petContext ?? .legacyFallback(petName: petName, isWalking: isWalking)
    }

    var normalizedActionState: WalkWidgetActionState? {
        guard let actionState else { return nil }
        return actionState.isExpired ? nil : actionState
    }

    var timelineReloadSignature: String {
        [
            String(isWalking),
            normalizedPetContext.petName,
            normalizedPetContext.source.rawValue,
            normalizedPetContext.startPolicy.rawValue,
            normalizedPetContext.fallbackReason ?? "",
            status.rawValue,
            statusMessage ?? "",
            normalizedActionState?.kind.rawValue ?? "",
            normalizedActionState?.phase.rawValue ?? "",
            normalizedActionState?.followUp.rawValue ?? "",
            normalizedActionState?.message ?? ""
        ].joined(separator: "|")
    }

    static let initial = WalkWidgetSnapshot(
        isWalking: false,
        elapsedSeconds: 0,
        petName: "반려견",
        petContext: .init(
            petId: nil,
            petName: "반려견",
            source: .noActivePet,
            startPolicy: .selectedPetImmediate,
            fallbackReason: nil
        ),
        status: .ready,
        statusMessage: nil,
        actionState: nil,
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

enum TerritoryWidgetGoalContextStatus: String, Codable {
    case ready = "ready"
    case emptyData = "empty_data"
    case completed = "completed"
    case unavailable = "unavailable"
}

struct TerritoryWidgetGoalContextSnapshot: Codable, Equatable {
    let status: TerritoryWidgetGoalContextStatus
    let contextLabel: String
    let nextGoalName: String?
    let nextGoalAreaM2: Double?
    let remainingAreaM2: Double?
    let progressRatio: Double?
    let message: String

    var hasConfirmedGoal: Bool {
        status == .ready &&
        nextGoalName?.isEmpty == false &&
        nextGoalAreaM2 != nil &&
        remainingAreaM2 != nil &&
        progressRatio != nil
    }
}

struct TerritoryWidgetSummarySnapshot: Codable, Equatable {
    let todayTileCount: Int
    let weeklyTileCount: Int
    let defenseScheduledTileCount: Int
    let scoreUpdatedAt: TimeInterval?
    let refreshedAt: TimeInterval
    let goalContext: TerritoryWidgetGoalContextSnapshot?

    static let zero = TerritoryWidgetSummarySnapshot(
        todayTileCount: 0,
        weeklyTileCount: 0,
        defenseScheduledTileCount: 0,
        scoreUpdatedAt: nil,
        refreshedAt: Date().timeIntervalSince1970,
        goalContext: nil
    )
}

struct TerritoryWidgetSnapshot: Codable, Equatable {
    let status: TerritoryWidgetSnapshotStatus
    let message: String
    let summary: TerritoryWidgetSummarySnapshot?
    let contextKey: String
    let updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case summary
        case contextKey
        case updatedAt
    }

    /// 영역 위젯 스냅샷을 명시적인 컨텍스트 키와 함께 생성합니다.
    /// - Parameters:
    ///   - status: 현재 위젯 상태입니다.
    ///   - message: 상태 설명 문구입니다.
    ///   - summary: 렌더링할 영역 요약 스냅샷입니다.
    ///   - contextKey: 사용자/반려견 컨텍스트 식별 키입니다.
    ///   - updatedAt: 마지막 갱신 시각입니다.
    init(
        status: TerritoryWidgetSnapshotStatus,
        message: String,
        summary: TerritoryWidgetSummarySnapshot?,
        contextKey: String,
        updatedAt: TimeInterval
    ) {
        self.status = status
        self.message = message
        self.summary = summary
        self.contextKey = contextKey
        self.updatedAt = updatedAt
    }

    static let initial = TerritoryWidgetSnapshot(
        status: .guestLocked,
        message: "로그인 후 내 영역 현황을 위젯에서 빠르게 확인해보세요.",
        summary: nil,
        contextKey: "guest",
        updatedAt: Date().timeIntervalSince1970
    )

    /// 레거시 스냅샷까지 호환하도록 영역 위젯 스냅샷을 디코딩합니다.
    /// - Parameter decoder: 공유 저장소의 직렬화 데이터를 해석할 디코더입니다.
    /// - Throws: 지원하지 않는 형식일 때 디코딩 오류를 그대로 전달합니다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(TerritoryWidgetSnapshotStatus.self, forKey: .status)
        self.message = try container.decode(String.self, forKey: .message)
        self.summary = try container.decodeIfPresent(TerritoryWidgetSummarySnapshot.self, forKey: .summary)
        self.contextKey = try container.decodeIfPresent(String.self, forKey: .contextKey) ?? "guest"
        self.updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)
    }
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

enum QuestRivalWidgetSnapshotStatus: String, Codable {
    case memberReady = "member_ready"
    case guestLocked = "guest_locked"
    case emptyData = "empty_data"
    case offlineCached = "offline_cached"
    case syncDelayed = "sync_delayed"
    case claimInFlight = "claim_in_flight"
    case claimFailed = "claim_failed"
    case claimSucceeded = "claim_succeeded"
}

struct QuestRivalWidgetSummarySnapshot: Codable, Equatable {
    let questInstanceId: String?
    let questTitle: String
    let questProgressValue: Double
    let questTargetValue: Double
    let questProgressRatio: Double
    let questClaimable: Bool
    let questRewardPoint: Int
    let rivalRank: Int?
    let rivalRankDelta: Int
    let rivalLeague: String
    let refreshedAt: TimeInterval

    static let zero = QuestRivalWidgetSummarySnapshot(
        questInstanceId: nil,
        questTitle: "오늘의 퀘스트를 준비 중입니다.",
        questProgressValue: 0,
        questTargetValue: 1,
        questProgressRatio: 0,
        questClaimable: false,
        questRewardPoint: 0,
        rivalRank: nil,
        rivalRankDelta: 0,
        rivalLeague: "onboarding",
        refreshedAt: Date().timeIntervalSince1970
    )
}

struct QuestRivalWidgetSnapshot: Codable, Equatable {
    let status: QuestRivalWidgetSnapshotStatus
    let message: String
    let summary: QuestRivalWidgetSummarySnapshot?
    let contextKey: String
    let updatedAt: TimeInterval

    static let initial = QuestRivalWidgetSnapshot(
        status: .guestLocked,
        message: "로그인 후 퀘스트 진행률과 라이벌 지표를 위젯에서 확인할 수 있어요.",
        summary: nil,
        contextKey: "guest",
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
        return WalkWidgetSnapshot(
            isWalking: decoded.isWalking,
            elapsedSeconds: decoded.elapsedSeconds,
            petName: decoded.petName,
            petContext: decoded.petContext ?? decoded.normalizedPetContext,
            status: decoded.status,
            statusMessage: decoded.statusMessage,
            actionState: decoded.normalizedActionState,
            updatedAt: decoded.updatedAt
        )
    }

    /// 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 스냅샷입니다.
    func save(_ snapshot: WalkWidgetSnapshot) {
        let previous = load()
        let normalizedSnapshot = WalkWidgetSnapshot(
            isWalking: snapshot.isWalking,
            elapsedSeconds: snapshot.elapsedSeconds,
            petName: snapshot.petName,
            petContext: snapshot.normalizedPetContext,
            status: snapshot.status,
            statusMessage: snapshot.statusMessage,
            actionState: snapshot.normalizedActionState,
            updatedAt: snapshot.updatedAt
        )
        guard let data = try? encoder.encode(normalizedSnapshot) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.snapshotStorageKey)
        #if canImport(WidgetKit)
        if previous.timelineReloadSignature != normalizedSnapshot.timelineReloadSignature {
            WidgetCenter.shared.reloadTimelines(ofKind: WalkWidgetBridgeContract.walkWidgetKind)
        }
        #endif
    }

    /// App Group 저장소를 우선 사용하고, 실패 시 표준 저장소를 반환합니다.
    /// - Returns: 위젯과 앱 간 공유 가능한 UserDefaults 인스턴스입니다.
    private static func resolveStorage() -> UserDefaults {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WalkWidgetBridgeContract.appGroupIdentifier
        ) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
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
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WalkWidgetBridgeContract.appGroupIdentifier
        ) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
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
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WalkWidgetBridgeContract.appGroupIdentifier
        ) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
    }
}

protocol QuestRivalWidgetSnapshotStoring {
    /// 퀘스트/라이벌 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> QuestRivalWidgetSnapshot

    /// 퀘스트/라이벌 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 퀘스트/라이벌 스냅샷입니다.
    func save(_ snapshot: QuestRivalWidgetSnapshot)
}

final class DefaultQuestRivalWidgetSnapshotStore: QuestRivalWidgetSnapshotStoring {
    static let shared = DefaultQuestRivalWidgetSnapshotStore()

    private let storage: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// 퀘스트/라이벌 위젯 스냅샷 저장소를 초기화합니다.
    /// - Parameter storage: 스냅샷 직렬화 데이터를 저장할 UserDefaults입니다.
    init(storage: UserDefaults = DefaultQuestRivalWidgetSnapshotStore.resolveStorage()) {
        self.storage = storage
    }

    /// 퀘스트/라이벌 위젯 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷이 있으면 해당 값, 없으면 기본 스냅샷을 반환합니다.
    func load() -> QuestRivalWidgetSnapshot {
        guard
            let data = storage.data(forKey: WalkWidgetBridgeContract.questRivalSnapshotStorageKey),
            let decoded = try? decoder.decode(QuestRivalWidgetSnapshot.self, from: data)
        else {
            return .initial
        }
        return decoded
    }

    /// 퀘스트/라이벌 위젯 스냅샷을 저장합니다.
    /// - Parameter snapshot: 위젯 표시용으로 직렬화할 최신 퀘스트/라이벌 스냅샷입니다.
    func save(_ snapshot: QuestRivalWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.questRivalSnapshotStorageKey)
    }

    /// App Group 저장소를 우선 사용하고, 실패 시 표준 저장소를 반환합니다.
    /// - Returns: 위젯과 앱 간 공유 가능한 UserDefaults 인스턴스입니다.
    private static func resolveStorage() -> UserDefaults {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WalkWidgetBridgeContract.appGroupIdentifier
        ) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: WalkWidgetBridgeContract.appGroupIdentifier) ?? .standard
    }
}
