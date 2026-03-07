import Foundation

/// 위젯-앱 간 공유 저장소/딥링크 규약을 정의합니다.
enum WalkWidgetBridgeContract {
    static let appGroupIdentifier = "group.com.th.dogArea.shared"
    static let snapshotStorageKey = "walk.widget.snapshot.v1"
    static let walkWidgetKind = "com.th.dogArea.walk-control"
    static let territorySnapshotStorageKey = "territory.widget.snapshot.v1"
    static let territoryWidgetKind = "com.th.dogArea.territory-status"
    static let hotspotSnapshotStorageKey = "hotspot.widget.snapshot.v1"
    static let hotspotWidgetKind = "com.th.dogArea.hotspot-status"
    static let questRivalSnapshotStorageKey = "quest.rival.widget.snapshot.v1"
    static let questRivalWidgetKind = "com.th.dogArea.quest-rival-status"
    static let actionRequestStorageKey = "walk.widget.action.request.v1"
    static let deepLinkScheme = "dogarea"
    static let deepLinkHost = "widget"
    static let walkDeepLinkPath = "/walk"
    static let territoryDeepLinkPath = "/territory"
    static let hotspotDeepLinkPath = "/hotspot"
    static let deepLinkActionQueryName = "action"
    static let deepLinkActionIdQueryName = "action_id"
    static let deepLinkSourceQueryName = "source"
    static let deepLinkContextQueryName = "context_id"
    static let deepLinkDestinationQueryName = "destination"
    static let territoryStatusQueryName = "territory_status"
    static let hotspotStatusQueryName = "hotspot_status"
    static let hotspotRadiusPresetQueryName = "radius_preset"

    /// 지정한 핫스팟 반경 preset에 대응하는 공유 저장소 키를 생성합니다.
    /// - Parameter radiusPreset: 스냅샷을 구분할 위젯 반경 preset입니다.
    /// - Returns: preset별 핫스팟 스냅샷 저장 키 문자열입니다.
    static func hotspotSnapshotStorageKey(for radiusPreset: HotspotWidgetRadiusPreset) -> String {
        "\(hotspotSnapshotStorageKey).\(radiusPreset.rawValue)"
    }
}

enum WalkWidgetActionKind: String, Codable, CaseIterable {
    case startWalk = "start_walk"
    case endWalk = "end_walk"
    case openWalkTab = "open_walk_tab"
    case claimQuestReward = "claim_quest_reward"
    case openQuestDetail = "open_quest_detail"
    case openQuestRecovery = "open_quest_recovery"
    case openRivalTab = "open_rival_tab"

    var deepLinkValue: String {
        rawValue
    }
}

struct WalkWidgetActionRoute: Equatable {
    let kind: WalkWidgetActionKind
    let actionId: String
    let source: String
    let contextId: String?

    /// 위젯 액션 라우트를 앱 딥링크 URL로 직렬화합니다.
    /// - Returns: 앱 라우팅에 사용할 `dogarea://widget/walk?...` URL입니다.
    func makeURL() -> URL? {
        var components = URLComponents()
        components.scheme = WalkWidgetBridgeContract.deepLinkScheme
        components.host = WalkWidgetBridgeContract.deepLinkHost
        components.path = WalkWidgetBridgeContract.walkDeepLinkPath
        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkActionQueryName,
                value: kind.deepLinkValue
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkActionIdQueryName,
                value: actionId
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkSourceQueryName,
                value: source
            )
        ]
        if let contextId,
           contextId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            queryItems.append(
                URLQueryItem(
                    name: WalkWidgetBridgeContract.deepLinkContextQueryName,
                    value: contextId
                )
            )
        }
        components.queryItems = queryItems
        return components.url
    }

    /// 앱으로 전달된 URL에서 위젯 액션 라우트를 파싱합니다.
    /// - Parameter url: URL 스킴을 통해 전달된 입력 URL입니다.
    /// - Returns: 규약에 맞는 라우트면 `WalkWidgetActionRoute`, 아니면 `nil`입니다.
    static func parse(from url: URL) -> WalkWidgetActionRoute? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == WalkWidgetBridgeContract.deepLinkScheme,
            components.host?.lowercased() == WalkWidgetBridgeContract.deepLinkHost,
            components.path == WalkWidgetBridgeContract.walkDeepLinkPath
        else {
            return nil
        }

        let queryByName = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        guard
            let actionRaw = queryByName[WalkWidgetBridgeContract.deepLinkActionQueryName],
            let kind = WalkWidgetActionKind(rawValue: actionRaw)
        else {
            return nil
        }

        let actionId = queryByName[WalkWidgetBridgeContract.deepLinkActionIdQueryName]
            .flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString.lowercased()
        let source = queryByName[WalkWidgetBridgeContract.deepLinkSourceQueryName]
            .flatMap { $0.isEmpty ? nil : $0 } ?? "widget"
        let contextId = queryByName[WalkWidgetBridgeContract.deepLinkContextQueryName]
            .flatMap { $0.isEmpty ? nil : $0 }
        return .init(kind: kind, actionId: actionId, source: source, contextId: contextId)
    }
}

enum TerritoryWidgetDeepLinkDestination: String, Codable, CaseIterable {
    case goalDetail = "goal_detail"
}

struct TerritoryWidgetDeepLinkRoute: Equatable {
    let destination: TerritoryWidgetDeepLinkDestination
    let source: String
    let status: TerritoryWidgetSnapshotStatus

    /// 영역 위젯 딥링크 라우트를 앱 URL 스킴으로 직렬화합니다.
    /// - Returns: 앱에서 영역 목표 상세 목적지를 복원할 수 있는 URL입니다.
    func makeURL() -> URL? {
        var components = URLComponents()
        components.scheme = WalkWidgetBridgeContract.deepLinkScheme
        components.host = WalkWidgetBridgeContract.deepLinkHost
        components.path = WalkWidgetBridgeContract.territoryDeepLinkPath
        components.queryItems = [
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkDestinationQueryName,
                value: destination.rawValue
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkSourceQueryName,
                value: source
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.territoryStatusQueryName,
                value: status.rawValue
            )
        ]
        return components.url
    }

    /// 앱으로 전달된 URL에서 영역 위젯 딥링크 라우트를 복원합니다.
    /// - Parameter url: 위젯 탭으로 유입된 입력 URL입니다.
    /// - Returns: 영역 위젯 규약에 맞는 라우트면 반환하고, 아니면 `nil`을 반환합니다.
    static func parse(from url: URL) -> TerritoryWidgetDeepLinkRoute? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == WalkWidgetBridgeContract.deepLinkScheme,
            components.host?.lowercased() == WalkWidgetBridgeContract.deepLinkHost,
            components.path == WalkWidgetBridgeContract.territoryDeepLinkPath
        else {
            return nil
        }

        let queryByName = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        guard
            let destinationRaw = queryByName[WalkWidgetBridgeContract.deepLinkDestinationQueryName],
            let destination = TerritoryWidgetDeepLinkDestination(rawValue: destinationRaw),
            let statusRaw = queryByName[WalkWidgetBridgeContract.territoryStatusQueryName],
            let status = TerritoryWidgetSnapshotStatus(rawValue: statusRaw)
        else {
            return nil
        }

        let source = queryByName[WalkWidgetBridgeContract.deepLinkSourceQueryName]
            .flatMap { $0.isEmpty ? nil : $0 } ?? "territory_widget"
        return .init(destination: destination, source: source, status: status)
    }
}

enum HotspotWidgetDeepLinkDestination: String, Codable, CaseIterable {
    case rivalDetail = "rival_detail"
}

struct HotspotWidgetDeepLinkRoute: Equatable {
    let destination: HotspotWidgetDeepLinkDestination
    let source: String
    let status: HotspotWidgetSnapshotStatus
    let radiusPreset: HotspotWidgetRadiusPreset

    /// 핫스팟 위젯 딥링크 라우트를 앱 URL 스킴으로 직렬화합니다.
    /// - Returns: 앱에서 라이벌 상세 목적지와 반경 문맥을 복원할 수 있는 URL입니다.
    func makeURL() -> URL? {
        var components = URLComponents()
        components.scheme = WalkWidgetBridgeContract.deepLinkScheme
        components.host = WalkWidgetBridgeContract.deepLinkHost
        components.path = WalkWidgetBridgeContract.hotspotDeepLinkPath
        components.queryItems = [
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkDestinationQueryName,
                value: destination.rawValue
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.deepLinkSourceQueryName,
                value: source
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.hotspotStatusQueryName,
                value: status.rawValue
            ),
            URLQueryItem(
                name: WalkWidgetBridgeContract.hotspotRadiusPresetQueryName,
                value: radiusPreset.rawValue
            )
        ]
        return components.url
    }

    /// 앱으로 전달된 URL에서 핫스팟 위젯 딥링크 라우트를 복원합니다.
    /// - Parameter url: 위젯 탭으로 유입된 입력 URL입니다.
    /// - Returns: 핫스팟 위젯 규약에 맞는 라우트면 반환하고, 아니면 `nil`을 반환합니다.
    static func parse(from url: URL) -> HotspotWidgetDeepLinkRoute? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == WalkWidgetBridgeContract.deepLinkScheme,
            components.host?.lowercased() == WalkWidgetBridgeContract.deepLinkHost,
            components.path == WalkWidgetBridgeContract.hotspotDeepLinkPath
        else {
            return nil
        }

        let queryByName = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        guard
            let destinationRaw = queryByName[WalkWidgetBridgeContract.deepLinkDestinationQueryName],
            let destination = HotspotWidgetDeepLinkDestination(rawValue: destinationRaw),
            let statusRaw = queryByName[WalkWidgetBridgeContract.hotspotStatusQueryName],
            let status = HotspotWidgetSnapshotStatus(rawValue: statusRaw),
            let radiusRaw = queryByName[WalkWidgetBridgeContract.hotspotRadiusPresetQueryName],
            let radiusPreset = HotspotWidgetRadiusPreset(rawValue: radiusRaw)
        else {
            return nil
        }

        let source = queryByName[WalkWidgetBridgeContract.deepLinkSourceQueryName]
            .flatMap { $0.isEmpty ? nil : $0 } ?? "hotspot_widget"
        return .init(
            destination: destination,
            source: source,
            status: status,
            radiusPreset: radiusPreset
        )
    }
}

struct WalkWidgetActionRequest: Codable, Equatable {
    let kind: WalkWidgetActionKind
    let actionId: String
    let source: String
    let contextId: String?
    let requestedAt: TimeInterval

    /// 저장 요청 모델을 화면 라우팅 모델로 변환합니다.
    /// - Returns: 앱 내부 액션 적용용 라우트입니다.
    func asRoute() -> WalkWidgetActionRoute {
        .init(kind: kind, actionId: actionId, source: source, contextId: contextId)
    }
}

protocol WalkWidgetActionRequestStoring {
    /// 위젯 액션 요청을 공유 저장소에 기록합니다.
    /// - Parameter request: 앱 실행 후 소비할 액션 요청 모델입니다.
    func setPending(_ request: WalkWidgetActionRequest)

    /// 현재 대기 중인 위젯 액션 요청을 읽고 즉시 제거합니다.
    /// - Returns: 대기 요청이 있으면 반환하고, 없으면 `nil`을 반환합니다.
    func consumePending() -> WalkWidgetActionRequest?
}

final class DefaultWalkWidgetActionRequestStore: WalkWidgetActionRequestStoring {
    static let shared = DefaultWalkWidgetActionRequestStore()

    private let storage: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 위젯 액션 요청 저장소를 초기화합니다.
    /// - Parameter storage: 요청 데이터를 직렬화할 UserDefaults입니다.
    init(storage: UserDefaults = DefaultWalkWidgetActionRequestStore.resolveStorage()) {
        self.storage = storage
    }

    /// 위젯 액션 요청을 공유 저장소에 기록합니다.
    /// - Parameter request: 앱 실행 후 소비할 액션 요청 모델입니다.
    func setPending(_ request: WalkWidgetActionRequest) {
        guard let data = try? encoder.encode(request) else { return }
        storage.set(data, forKey: WalkWidgetBridgeContract.actionRequestStorageKey)
    }

    /// 현재 대기 중인 위젯 액션 요청을 읽고 즉시 제거합니다.
    /// - Returns: 대기 요청이 있으면 반환하고, 없으면 `nil`을 반환합니다.
    func consumePending() -> WalkWidgetActionRequest? {
        guard let data = storage.data(forKey: WalkWidgetBridgeContract.actionRequestStorageKey) else {
            return nil
        }
        storage.removeObject(forKey: WalkWidgetBridgeContract.actionRequestStorageKey)
        return try? decoder.decode(WalkWidgetActionRequest.self, from: data)
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

extension Notification.Name {
    static let walkWidgetActionRequested = Notification.Name("walk.widget.action.requested")
}
