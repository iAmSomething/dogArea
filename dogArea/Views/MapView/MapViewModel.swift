//
//  MapViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine
import WatchConnectivity
#if canImport(UIKit)
import UIKit
#endif

enum WeatherRiskLevelValue: String, CaseIterable {
    case clear
    case caution
    case bad
    case severe
}

struct WeatherRiskSnapshot: Equatable {
    let level: WeatherRiskLevelValue
    let observedAt: TimeInterval
}

protocol WeatherRiskProviding {
    /// 주어진 좌표의 현재 날씨를 조회해 위험도 레벨을 산출합니다.
    /// - Parameters:
    ///   - latitude: 조회 대상 위도입니다.
    ///   - longitude: 조회 대상 경도입니다.
    /// - Returns: 위험도 레벨과 관측 시각을 담은 스냅샷입니다.
    func fetchRisk(latitude: Double, longitude: Double) async throws -> WeatherRiskSnapshot
}

final class OpenMeteoWeatherRiskProvider: WeatherRiskProviding {
    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature2M: Double
            let precipitation: Double
            let windSpeed10M: Double

            enum CodingKeys: String, CodingKey {
                case time
                case temperature2M = "temperature_2m"
                case precipitation
                case windSpeed10M = "wind_speed_10m"
            }
        }

        let current: Current
    }

    private let session: URLSession
    private let requestTimeout: TimeInterval

    /// Open-Meteo 기반 날씨 위험도 조회기를 생성합니다.
    /// - Parameters:
    ///   - session: HTTP 요청에 사용할 URLSession입니다.
    ///   - requestTimeout: 단건 요청 타임아웃(초)입니다.
    init(session: URLSession = .shared, requestTimeout: TimeInterval = 6.0) {
        self.session = session
        self.requestTimeout = requestTimeout
    }

    /// 주어진 좌표의 현재 날씨를 조회해 위험도 레벨을 산출합니다.
    /// - Parameters:
    ///   - latitude: 조회 대상 위도입니다.
    ///   - longitude: 조회 대상 경도입니다.
    /// - Returns: 위험도 레벨과 관측 시각을 담은 스냅샷입니다.
    func fetchRisk(latitude: Double, longitude: Double) async throws -> WeatherRiskSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,precipitation,wind_speed_10m"),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        var decoded: OpenMeteoResponse?
        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, _) = try await session.data(for: request)
                decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                break
            } catch {
                lastError = error
                let urlError = error as? URLError
                let shouldRetry = attempt == 0 && (urlError?.code == .timedOut || urlError?.code == .networkConnectionLost)
                guard shouldRetry else { throw error }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }

        guard let decoded else {
            throw lastError ?? URLError(.cannotParseResponse)
        }
        let observedAt = Self.parseObservedAt(decoded.current.time)
        let risk = Self.score(
            precipitationMMPerHour: decoded.current.precipitation,
            temperatureC: decoded.current.temperature2M,
            windMps: decoded.current.windSpeed10M
        )
        return WeatherRiskSnapshot(level: risk, observedAt: observedAt)
    }

    /// Open-Meteo 시각 문자열을 epoch seconds로 변환합니다.
    /// - Parameter value: Open-Meteo `current.time` 문자열입니다.
    /// - Returns: 파싱된 epoch seconds이며, 실패 시 현재 시각을 반환합니다.
    private static func parseObservedAt(_ value: String) -> TimeInterval {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date.timeIntervalSince1970
        }
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = fallbackFormatter.date(from: value) {
            return date.timeIntervalSince1970
        }
        return Date().timeIntervalSince1970
    }

    /// 강수/기온/풍속 지표를 종합해 최종 날씨 위험도를 계산합니다.
    /// - Parameters:
    ///   - precipitationMMPerHour: 시간당 강수량(mm/h)입니다.
    ///   - temperatureC: 기온(섭씨)입니다.
    ///   - windMps: 풍속(m/s)입니다.
    /// - Returns: 지표별 최대 위험도 규칙으로 계산된 최종 위험도입니다.
    private static func score(
        precipitationMMPerHour: Double,
        temperatureC: Double,
        windMps: Double
    ) -> WeatherRiskLevelValue {
        let precipitationRisk = riskForPrecipitation(precipitationMMPerHour)
        let temperatureRisk = riskForTemperature(temperatureC)
        let windRisk = riskForWind(windMps)
        return [precipitationRisk, temperatureRisk, windRisk]
            .max(by: { $0.severityRank < $1.severityRank }) ?? .clear
    }

    /// 강수량 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 시간당 강수량(mm/h)입니다.
    /// - Returns: 강수량 기준 위험도입니다.
    private static func riskForPrecipitation(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 12 { return .severe }
        if value >= 6 { return .bad }
        if value >= 1 { return .caution }
        return .clear
    }

    /// 기온 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 섭씨 기온입니다.
    /// - Returns: 기온 기준 위험도입니다.
    private static func riskForTemperature(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 33 || value <= -8 { return .severe }
        if value >= 30 || value <= -3 { return .bad }
        if value >= 28 || value <= 0 { return .caution }
        return .clear
    }

    /// 풍속 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 풍속(m/s)입니다.
    /// - Returns: 풍속 기준 위험도입니다.
    private static func riskForWind(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 14 { return .severe }
        if value >= 10 { return .bad }
        if value >= 6 { return .caution }
        return .clear
    }
}

private extension WeatherRiskLevelValue {
    var severityRank: Int {
        switch self {
        case .clear: return 0
        case .caution: return 1
        case .bad: return 2
        case .severe: return 3
        }
    }
}

private enum MapCoreLocationCallTracer {
    #if DEBUG
    private static let lock = NSLock()
    private static var eventCounts: [String: Int] = [:]
    private static var windowStartedAt: Date = Date()
    #endif

    /// 지도 탭의 CoreLocation API 호출 이벤트를 1초 단위로 집계해 디버그 콘솔에 출력합니다.
    /// - Parameters:
    ///   - event: 호출 지점을 구분하는 이벤트 식별자입니다.
    ///   - detail: 호출 시점의 보조 상태 정보입니다.
    ///   - file: 호출 파일 식별자입니다.
    ///   - line: 호출 라인 번호입니다.
    static func record(
        _ event: String,
        detail: String? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        #if DEBUG
        let now = Date()
        var shouldPrintWindowSummary = false
        var summaryText = ""
        var occurrenceCount = 0

        lock.lock()
        eventCounts[event, default: 0] += 1
        occurrenceCount = eventCounts[event, default: 0]
        if now.timeIntervalSince(windowStartedAt) >= 1.0 {
            shouldPrintWindowSummary = true
            summaryText = eventCounts
                .sorted { lhs, rhs in lhs.value > rhs.value }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            eventCounts.removeAll()
            windowStartedAt = now
        }
        lock.unlock()

        if occurrenceCount <= 2 {
            if let detail, detail.isEmpty == false {
                print("[CoreLocationTrace][Map] \(event) @\(file):\(line) detail=\(detail)")
            } else {
                print("[CoreLocationTrace][Map] \(event) @\(file):\(line)")
            }
        }

        if shouldPrintWindowSummary {
            print("[CoreLocationTrace][Map][1s] \(summaryText)")
        }
        #else
        _ = event
        _ = detail
        _ = file
        _ = line
        #endif
    }
}

class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, WCSessionDelegate {
    enum WalkEndReason: String {
        case manual = "manual"
        case autoInactive = "auto_inactive"
        case autoTimeout = "auto_timeout"
    }

    enum WalkPointRecordMode: String {
        case manual
        case auto

        var title: String {
            switch self {
            case .manual: return "포인트 수동 기록"
            case .auto: return "포인트 자동 기록"
            }
        }
    }

    enum CameraChangeReason: String {
        case manualMove = "manual_move"
        case locationButton = "location_button"
        case systemFallback = "system_fallback"
    }

    private struct ActiveWalkPointSnapshot: Codable {
        let latitude: Double
        let longitude: Double
        let createdAt: TimeInterval
    }

    private struct ActiveWalkSessionSnapshot: Codable {
        let sessionId: String?
        let startedAt: TimeInterval
        let elapsedTime: TimeInterval
        let selectedPetId: String?
        let selectedPetName: String
        let currentWalkingPetName: String
        let pointRecordMode: String
        let lastMovementAt: TimeInterval?
        let points: [ActiveWalkPointSnapshot]
        let savedAt: TimeInterval
    }

    private struct CameraSnapshot {
        let centerCoordinate: CLLocationCoordinate2D
        let distance: Double
    }

    private enum MapOverlayLODTuning {
        static let overlayMaxCameraDistanceKey = "map.lod.overlay.maxCameraDistance"
        static let overlayClusterThresholdKey = "map.lod.overlay.clusterThreshold"
        static let overlayPolygonCountThresholdKey = "map.lod.overlay.polygonCountThreshold"
        static let singleClusterOverlayLimitKey = "map.lod.overlay.singleClusterLimit"
        static let clusterCellDistanceRatioKey = "map.lod.cluster.cellDistanceRatio"
        static let clusterCellMinMetersKey = "map.lod.cluster.cellMinMeters"
        static let clusterCellMaxMetersKey = "map.lod.cluster.cellMaxMeters"

        static let overlayMaxCameraDistanceDefault = 4_500.0
        static let overlayClusterThresholdDefault = 24
        static let overlayPolygonCountThresholdDefault = 900
        static let singleClusterOverlayLimitDefault = 160
        static let clusterCellDistanceRatioDefault = 0.08
        static let clusterCellMinMetersDefault = 80.0
        static let clusterCellMaxMetersDefault = 500.0
    }

    /// 런치 인자 기반으로 UI 테스트 런타임 여부를 판별합니다.
    /// - Returns: 디자인 감사/기능 회귀 UI 테스트 실행 중이면 `true`, 아니면 `false`입니다.
    private static func isRunningUITestRuntime() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-UITest.DesignAudit")
            || arguments.contains("-UITest.FeatureRegression")
    }

    /// UI 테스트에서 산책 시작 카운트다운을 강제로 활성화할지 판별합니다.
    /// - Returns: 런치 인자에 강제 카운트다운 플래그가 있으면 `true`, 아니면 `false`입니다.
    private static func shouldForceWalkCountdownForUITest() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.ForceWalkCountdown")
    }

    private let locationManager = CLLocationManager()
    private var timer: Timer? = nil
    private var isLocationUpdatesRunning: Bool = false
    private var isMapViewActive: Bool = false
    private var lastLocationSideEffectAt: Date = .distantPast
    private let locationSideEffectInterval: TimeInterval = 1.0
    @Published var time: TimeInterval = 0.0
    @Published var startTime = Date()
    @Published var location: CLLocation?
    @Published var polygon : Polygon = Polygon(walkingTime: 0.0, walkingArea: 0.0)
    @Published var polygonList: [Polygon] = []
    @Published var selectedPolygonList: [Polygon] = []
    @Published var isWalking: Bool = false{
        didSet {
            //산책 시작 버튼 눌렀을 때
            if self.isWalking {
                self.showOnlyOne = true
            }
            self.publishWatchState()
        }
    }
    @Published var centerLocations: [Cluster] = []
    @Published private(set) var currentCameraDistance: Double = 2_000
    @Published var camera: MapCamera = .init(.init())
    @Published var cameraPosition = MapCameraPosition.automatic
    @Published var selectedMarker: Location? = nil
    @Published var showOnlyOne: Bool = true
    @Published var heatmapEnabled: Bool = true
    @Published var heatmapCells: [HeatmapCellDTO] = []
    @Published var nearbyHotspotEnabled: Bool = true
    @Published var locationSharingEnabled: Bool = false
    @Published var nearbyHotspots: [NearbyHotspotDTO] = []
    @Published var selectedPetId: String? = nil
    @Published var selectedPetName: String = "강아지"
    @Published var availablePets: [PetInfo] = []
    @Published var currentWalkingPetName: String = "강아지"
    @Published var walkStartCountdownEnabled: Bool = false
    @Published var walkPointRecordMode: WalkPointRecordMode = .manual
    @Published private(set) var walkAutoEndPolicyEnabled: Bool = true
    @Published var hasRecoverableWalkSession: Bool = false
    @Published var recoverableWalkSummaryText: String = ""
    @Published var recoverableWalkEstimateText: String = ""
    @Published var watchSyncStatusText: String = "워치 동기화 대기"
    @Published var latestWatchActionText: String = ""
    @Published var walkStatusMessage: String? = nil
    @Published var runtimeGuardStatusText: String = ""
    @Published var syncOutboxPendingCount: Int = 0
    @Published var syncOutboxPermanentFailureCount: Int = 0
    @Published var syncOutboxLastErrorCodeText: String = ""
    @Published var syncRecoveryToastMessage: String? = nil
    @Published private(set) var captureRipples: [CaptureRipple] = []
    @Published private(set) var clusterMotionTransition: ClusterMotionTransition = .none
    @Published private(set) var clusterMotionToken: Int = 0
    @Published private(set) var weatherOverlayRiskLevel: WeatherOverlayRiskLevel = .clear
    @Published private(set) var weatherOverlayOpacity: Double = 0.0
    @Published private(set) var weatherOverlayStatusText: String = "날씨 상태 정상"
    @Published private(set) var weatherOverlayFallbackActive: Bool = false
    @Published var mapMotionReduced: Bool = false
    @Published var isAddPointLongPressModeEnabled: Bool = false
    private let watchSession = WCSession.isSupported() ? WCSession.default : nil
    private let featureFlags = FeatureFlagStore.shared
    private let metricTracker = AppMetricTracker.shared
    private let nearbyService = NearbyPresenceService()
    private var nearbyTickTimer: Timer? = nil
    private var lastPresenceSentAt: Date = .distantPast
    private var lastNearbyFetchedAt: Date = .distantPast
    private var lastNearbyHotspotErrorLogAt: Date = .distantPast
    private var suppressedNearbyHotspotErrorCount: Int = 0
    private var lastVisibilitySyncErrorLogAt: Date = .distantPast
    private var suppressedVisibilitySyncErrorCount: Int = 0
    private let nearbyHotspotErrorLogInterval: TimeInterval = 60
    private var processedWatchActionIds: Set<String> = []
    private var processedWatchActionOrder: [String] = []
    private let maxProcessedWatchActions = 500
    private var lastWatchContextSyncAt: Date = .distantPast
    private var lastAppliedWatchActionId: String = ""
    private var lastAppliedWidgetActionId: String = ""
    private let processedWatchActionStorageKey = "watch.processedActionIds"
    private let activeWalkSessionStorageKey = "walk.activeSession.v1"
    private let lastWidgetActionIdKey = "walk.widget.lastActionId.v1"
    private let heatmapEnabledKey = "heatmap.enabled"
    private let locationSharingKey = "nearby.locationSharingEnabled"
    private let nearbyHotspotEnabledKey = "nearby.hotspotEnabled"
    private let nearbyPresenceUserIdKey = "nearby.presenceUserId"
    private let mapMotionReducedKey = "map.motion.reduced"
    private let addPointLongPressModeKey = "map.addPoint.longPressModeEnabled"
    private let weatherRiskOverrideKey = "weather.risk.level.v1"
    private let weatherRiskObservedAtKey = "weather.risk.observed_at.v1"
    private let weatherRiskCacheTTL: TimeInterval = 7200
    private let weatherRiskRefreshInterval: TimeInterval = 3600
    private var lastAutoRecordedLocation: CLLocation?
    private var lastAutoRecordedAt: Date = .distantPast
    private let autoRecordMinDistance: CLLocationDistance = 12.0
    private let autoRecordMinInterval: TimeInterval = 8.0
    private let autoRecordNoiseDistance: CLLocationDistance = 4.0
    private let locationAccuracyThreshold: CLLocationAccuracy = 65.0
    private let inactivityAccuracyThreshold: CLLocationAccuracy = 40.0
    private let inactivitySpeedThreshold: CLLocationSpeed = 0.3
    private let inactivityDistanceThreshold: CLLocationDistance = 25.0
    private let jumpSpeedThreshold: CLLocationSpeed = 12.0
    private let jumpDistanceThreshold: CLLocationDistance = 150.0
    private let jumpTimeWindow: TimeInterval = 10.0
    private let restCandidateInterval: TimeInterval = 300.0
    private let inactivityWarningInterval: TimeInterval = 720.0
    private let inactivityFinalizeInterval: TimeInterval = 900.0
    private let walkAutoTimeoutInterval: TimeInterval = 3600.0
    private let recoverableSessionMaxAge: TimeInterval = 43_200.0
    private var lastPointEventAt: Date?
    private var lastMovementAt: Date?
    private var movementAnchorLocation: CLLocation?
    private var didNotifyRestCandidate: Bool = false
    private var didNotifyInactivityWarning: Bool = false
    private var lastSnapshotPersistAt: Date = .distantPast
    private var pendingRecoverableSession: ActiveWalkSessionSnapshot?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var lastAcceptedWalkLocation: CLLocation?
    private var pendingCameraChangeReason: CameraChangeReason?
    private var pendingCameraReasonSetAt: Date = .distantPast
    private let pendingCameraReasonTTL: TimeInterval = 2.0
    private var lastLoggedCameraCenter: CLLocationCoordinate2D?
    private var lastLoggedCameraDistance: Double?
    private var lastLoggedCameraReason: CameraChangeReason?
    private let cameraLogCenterThreshold: CLLocationDistance = 40.0
    private let cameraLogDistanceThreshold: Double = 120.0
    private var pendingPointAddCameraSnapshot: CameraSnapshot?
    private var lastSyncFlushAt: Date = .distantPast
    private var lastSyncSummarySnapshot: SyncOutboxSummary? = nil
    private var lastWidgetSnapshotSyncAt: Date = .distantPast
    private var lastLiveActivitySyncAt: Date = .distantPast
    private var liveActivitySyncTask: Task<Void, Never>? = nil
    private var lastLiveActivityFallbackReason: WalkLiveActivityFallbackReason? = nil
    private var syncFlushTask: Task<Void, Never>? = nil
    private let syncOutbox = SyncOutboxStore.shared
    private let syncTransport = SupabaseSyncOutboxTransport()
    private let walkRepository: WalkRepositoryProtocol
    private let userSessionStore: UserSessionStoreProtocol
    private let authSessionStore: AuthSessionStoreProtocol
    private let preferenceStore: MapPreferenceStoreProtocol
    private let weatherRiskProvider: WeatherRiskProviding
    private let areaCalculationService: MapAreaCalculationServicing
    private let clusterAnnotationService: MapClusterAnnotationServicing
    private let widgetSnapshotStore: WalkWidgetSnapshotStoring
    private let liveActivityService: WalkLiveActivityServicing
    private let eventCenter: AppEventCenterProtocol
    private var lastCaptureHapticAt: Date = .distantPast
    private var lastWarningHapticAt: Date = .distantPast
    private let maxCaptureRipples = 12
    private let trailLifetime: TimeInterval = 5.0
    private let trailLimit = 12
    private var weatherFetchTask: Task<Void, Never>? = nil
    private var lastWeatherFetchAttemptAt: Date = .distantPast
    private let widgetSnapshotSyncInterval: TimeInterval = 5.0
    private let liveActivitySyncInterval: TimeInterval = 2.0

    private enum WatchIncomingAction: String {
        case startWalk
        case addPoint
        case endWalk
        case syncState
    }

    private struct WatchActionEnvelope {
        let version: String
        let action: WatchIncomingAction
        let actionId: String
        let sentAt: TimeInterval?
    }

    private enum WatchContract {
        static let version = "watch.remote.v1"
        static let actionType = "watch_action"
        static let ackType = "watch_ack"
    }

    private enum PointAppendSource {
        case manual
        case auto
        case watch
    }

    enum ClusterMotionTransition {
        case none
        case decompose
        case merge
    }

    enum WeatherOverlayRiskLevel: String {
        case clear
        case caution
        case bad
        case severe

        var displayTitle: String {
            switch self {
            case .clear: return "정상"
            case .caution: return "주의"
            case .bad: return "악천후"
            case .severe: return "고위험"
            }
        }
    }

    struct CaptureRipple: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let createdAt: TimeInterval

        init(
            id: UUID = UUID(),
            coordinate: CLLocationCoordinate2D,
            createdAt: TimeInterval = Date().timeIntervalSince1970
        ) {
            self.id = id
            self.coordinate = coordinate
            self.createdAt = createdAt
        }
    }

    struct TrailMarker: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let age: TimeInterval

        var opacity: Double {
            let ratio = min(1.0, max(0.0, age / 5.0))
            return 0.75 - (ratio * 0.65)
        }

        var scale: Double {
            let ratio = min(1.0, max(0.0, age / 5.0))
            return 0.95 + ((1.0 - ratio) * 0.25)
        }
    }

    init(
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared,
        weatherRiskProvider: WeatherRiskProviding = OpenMeteoWeatherRiskProvider(),
        areaCalculationService: MapAreaCalculationServicing = MapAreaCalculationService(),
        clusterAnnotationService: MapClusterAnnotationServicing = MapClusterAnnotationService(),
        widgetSnapshotStore: WalkWidgetSnapshotStoring = DefaultWalkWidgetSnapshotStore.shared,
        liveActivityService: WalkLiveActivityServicing = WalkLiveActivityService(),
        eventCenter: AppEventCenterProtocol = DefaultAppEventCenter.shared
    ) {
        let isUITestRuntime = Self.isRunningUITestRuntime()
        self.walkRepository = walkRepository
        self.userSessionStore = userSessionStore
        self.authSessionStore = authSessionStore
        self.preferenceStore = preferenceStore
        self.weatherRiskProvider = weatherRiskProvider
        self.areaCalculationService = areaCalculationService
        self.clusterAnnotationService = clusterAnnotationService
        self.widgetSnapshotStore = widgetSnapshotStore
        self.liveActivityService = liveActivityService
        self.eventCenter = eventCenter
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.locationManager.distanceFilter = 8
        self.locationManager.pausesLocationUpdatesAutomatically = true
        if isUITestRuntime == false {
            self.locationManager.allowsBackgroundLocationUpdates = true
        }
        self.reloadPolygonState(restoreLatestPolygon: true)
        self.loadProcessedWatchActions()
        self.lastAppliedWidgetActionId = preferenceStore.string(forKey: lastWidgetActionIdKey) ?? ""

        let storedHeatmapEnabled = preferenceStore.bool(forKey: heatmapEnabledKey, default: true)
        let storedNearbyHotspotEnabled = preferenceStore.bool(forKey: nearbyHotspotEnabledKey, default: true)
        let storedLocationSharingEnabled = preferenceStore.bool(forKey: locationSharingKey, default: false)
        let storedMotionReduced = preferenceStore.bool(forKey: mapMotionReducedKey, default: false)
        let storedAddPointLongPressMode = preferenceStore.bool(forKey: addPointLongPressModeKey, default: false)

        self.heatmapEnabled = featureFlags.isEnabled(.heatmapV1) ? storedHeatmapEnabled : false
        let nearbyFeatureOn = featureFlags.isEnabled(.nearbyHotspotV1)
        self.nearbyHotspotEnabled = nearbyFeatureOn ? storedNearbyHotspotEnabled : false
        self.locationSharingEnabled = nearbyFeatureOn ? storedLocationSharingEnabled : false
        self.mapMotionReduced = storedMotionReduced
        self.isAddPointLongPressModeEnabled = storedAddPointLongPressMode
        self.walkStartCountdownEnabled = userSessionStore.walkStartCountdownEnabled()
        if Self.shouldForceWalkCountdownForUITest() {
            self.walkStartCountdownEnabled = true
        }
        self.walkAutoEndPolicyEnabled = true
        self.walkPointRecordMode = WalkPointRecordMode(
            rawValue: userSessionStore.walkPointRecordModeRawValue()
        ) ?? .manual
        self.prepareRecoverableSessionIfNeeded()
        self.reloadSelectedPetContext()
        self.setupWatchConnectivity()
        self.setupLifecycleObservers()
        self.refreshWeatherOverlayRisk()
        if isUITestRuntime == false {
            self.refreshFeatureFlagsFromRemote()
            self.refreshSyncOutboxSummary()
        }
        self.syncWalkWidgetSnapshot(force: true)
        self.syncWalkLiveActivity(force: true)
    }

    deinit {
        timer?.invalidate()
        nearbyTickTimer?.invalidate()
        locationManager.stopUpdatingLocation()
        liveActivitySyncTask?.cancel()
        syncFlushTask?.cancel()
        weatherFetchTask?.cancel()
        lifecycleObservers.forEach { eventCenter.removeObserver($0) }
    }

    private func applyPolygonList(_ polygons: [Polygon], restoreLatestPolygon: Bool = false) {
        self.polygonList = polygons
        if restoreLatestPolygon {
            self.polygon = polygons.last ?? Polygon(walkingTime: 0.0, walkingArea: 0.0)
        }
        self.refreshHeatmap()
    }

    private func reloadPolygonState(restoreLatestPolygon: Bool = false) {
        let latest = self.walkRepository.fetchPolygons()
        self.applyPolygonList(latest, restoreLatestPolygon: restoreLatestPolygon)
    }

    func fetchPolygonList() {
        self.reloadPolygonState()
    }

    /// 지도 탭이 화면에 노출될 때 위치/동기화 폴링을 활성화합니다.
    func activateMapRuntimeServices() {
        isMapViewActive = true
        MapCoreLocationCallTracer.record(
            "requestWhenInUseAuthorization",
            detail: "source=activateMapRuntimeServices"
        )
        locationManager.requestWhenInUseAuthorization()
        startLocationUpdatesIfAuthorized()
        startNearbyTicker()
        syncVisibilitySettingIfNeeded()
        flushSyncOutboxIfNeeded(force: true)
        refreshWeatherRiskFromProviderIfNeeded(location: locationManager.location, force: true)
    }

    /// 지도 탭이 화면에서 사라질 때 불필요한 위치/폴링 작업을 중단합니다.
    func deactivateMapRuntimeServices() {
        isMapViewActive = false
        nearbyTickTimer?.invalidate()
        nearbyTickTimer = nil
        if isWalking == false {
            stopLocationUpdatesIfNeeded()
        }
    }

    /// 권한 상태가 허용일 때만 위치 업데이트를 시작합니다.
    private func startLocationUpdatesIfAuthorized() {
        guard isLocationUpdatesRunning == false else { return }
        let status = locationManager.authorizationStatus
        MapCoreLocationCallTracer.record(
            "authorizationStatus.read",
            detail: "source=startLocationUpdatesIfAuthorized status=\(status.rawValue)"
        )
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        MapCoreLocationCallTracer.record(
            "startUpdatingLocation",
            detail: "source=startLocationUpdatesIfAuthorized"
        )
        locationManager.startUpdatingLocation()
        isLocationUpdatesRunning = true
    }

    /// 현재 활성화된 위치 업데이트를 안전하게 중단합니다.
    private func stopLocationUpdatesIfNeeded() {
        guard isLocationUpdatesRunning else { return }
        MapCoreLocationCallTracer.record(
            "stopUpdatingLocation",
            detail: "source=stopLocationUpdatesIfNeeded"
        )
        locationManager.stopUpdatingLocation()
        isLocationUpdatesRunning = false
    }

    func fetchSelectedPolygonList(for clusters: Cluster) {
        if clusters.sumLocs.count == self.selectedPolygonList.count {
            var isSame = true
            for i in selectedPolygonList.indices {
                isSame = isSame && clusters.sumLocs[i].1 == self.selectedPolygonList[i].id
            }
            if isSame {
                self.selectedPolygonList = []
                return }
        }
        self.selectedPolygonList = []
        for loc in clusters.sumLocs {
            if let p = self.polygonList.polygon(at: loc.1) {
                self.selectedPolygonList.append(p)
            }
        }
    }
    /// 현재 위치를 수동 포인트로 즉시 추가합니다.
    /// - Returns: 포인트가 추가되면 생성된 포인트 UUID, 위치 정보가 없으면 `nil`입니다.
    @discardableResult
    func addLocation() -> UUID? {
        guard let location = self.location else { return nil }
        let appendedPoint = appendWalkPoint(from: location, recordedAt: Date(), source: .manual)
        return appendedPoint.id
    }

    /// 수동 포인트 추가 전에 현재 카메라 중심/거리 상태를 저장합니다.
    func preparePointAddCameraSnapshot() {
        pendingPointAddCameraSnapshot = CameraSnapshot(
            centerCoordinate: camera.centerCoordinate,
            distance: max(120.0, camera.distance)
        )
    }

    /// 수동 포인트를 추가한 뒤 필요 시 저장된 카메라 상태를 복원합니다.
    /// - Returns: 포인트가 추가되면 생성된 포인트 UUID, 추가하지 못하면 `nil`입니다.
    @discardableResult
    func addLocationPreservingCamera() -> UUID? {
        let addedPointId = addLocation()
        restorePointAddCameraSnapshotIfNeeded()
        return addedPointId
    }

    /// 지정한 포인트 UUID를 현재 세션에서 롤백합니다.
    /// - Parameter pointID: 실행 취소할 포인트 UUID입니다.
    /// - Returns: 실제로 포인트가 롤백되면 `true`, 대상이 없으면 `false`입니다.
    @discardableResult
    func undoAddedPoint(_ pointID: UUID) -> Bool {
        guard let targetIndex = polygon.locations.firstIndex(where: { $0.id == pointID }) else {
            return false
        }
        polygon.locations.remove(at: targetIndex)

        if polygon.locations.count > 2 {
            polygon.makePolygon(walkArea: calculateArea(), walkTime: time)
        } else {
            polygon.polygon = nil
            polygon.walkingArea = calculateArea(points: polygon.locations)
            polygon.walkingTime = time
        }

        if let lastPoint = polygon.locations.last {
            let lastPointDate = Date(timeIntervalSince1970: lastPoint.createdAt)
            lastAutoRecordedLocation = CLLocation(
                latitude: lastPoint.coordinate.latitude,
                longitude: lastPoint.coordinate.longitude
            )
            lastAutoRecordedAt = lastPointDate
            lastPointEventAt = lastPointDate
            movementAnchorLocation = lastAutoRecordedLocation
        } else {
            lastAutoRecordedLocation = nil
            lastAutoRecordedAt = .distantPast
            lastPointEventAt = nil
            movementAnchorLocation = nil
        }

        persistActiveWalkSession(force: true)
        syncWatchContext(force: true)
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
        return true
    }
    func removeLocation(_ locationID : UUID){
        if polygon.locations.firstIndex(where:{ $0.id == locationID}) != nil {
            polygon.removeAt(locationID)
            if polygon.locations.count<3 {
                let updated = walkRepository.deletePolygon(id: self.polygon.id)
                self.applyPolygonList(updated)
            }
        }
    }
    func makePolygon() {
        if self.polygon.locations.count > 2{
            polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time)
        }
    }
    func endWalk(
        img: UIImage? = nil,
        reason: WalkEndReason = .manual,
        endedAtOverride: Date? = nil
    ) {
        if isWalking {
                timerStop()
                if self.polygon.locations.count > 2{
                    if let endedAtOverride {
                        self.time = max(0, endedAtOverride.timeIntervalSince(self.startTime))
                    }
                    self.polygon.petId = selectedPetId
                    polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time, img: img)
                    let completedPolygon = self.polygon
                    let updated = walkRepository.savePolygon(completedPolygon)
                    let saved = updated.contains(where: { $0.id == completedPolygon.id })
                    metricTracker.track(
                        saved ? .walkSaveSuccess : .walkSaveFailed,
                        userKey: currentMetricUserId(),
                        featureKey: .heatmapV1,
                        payload: ["pointCount": "\(completedPolygon.locations.count)"]
                    )
                    if saved {
                        let endedAt = (endedAtOverride ?? Date()).timeIntervalSince1970
                        WalkSessionMetadataStore.shared.set(
                            sessionId: completedPolygon.id,
                            reason: .init(rawValue: reason.rawValue) ?? .manual,
                            endedAt: endedAt,
                            petId: selectedPetId
                        )
                        enqueueSyncOutbox(for: completedPolygon, hasImage: img != nil)
                    } else {
                        walkStatusMessage = "로컬 저장에 실패해 동기화 큐 적재를 건너뛰었습니다."
                    }
                    self.applyPolygonList(updated)
                }
            time = 0.0
            self.currentWalkingPetName = self.selectedPetName
            self.resetAutoPointRecordState()
            self.resetInactivityTracking(now: Date(), clearAnchor: true)
            self.clearActiveWalkSession()
        }
        else {
            clearActiveWalkSession()
            self.reloadSelectedPetContext()
            startLocationUpdatesIfAuthorized()
            setTrackingMode()
            startTime = Date()
            timerSet()
            polygon.clear()
            polygon.petId = selectedPetId
            self.currentWalkingPetName = self.selectedPetName
            self.resetAutoPointRecordState()
            self.lastAcceptedWalkLocation = nil
            self.lastPointEventAt = Date()
            self.resetInactivityTracking(now: Date(), clearAnchor: true)
            self.persistActiveWalkSession(force: true)
        }
        withAnimation{ [weak self] in
            self?.isWalking.toggle()
        }
        if self.isWalking == false, self.isMapViewActive == false {
            stopLocationUpdatesIfNeeded()
        }
        self.syncWatchContext(force: true)
        self.syncWalkWidgetSnapshot(force: true)
        self.syncWalkLiveActivity(force: true)
    }

    func startWalkNow() {
        guard isWalking == false else { return }
        endWalk()
    }

    func discardCurrentWalk() {
        guard isWalking else { return }
        timerStop()
        polygon.clear()
        time = 0.0
        selectedPolygonList = []
        currentWalkingPetName = selectedPetName
        resetAutoPointRecordState()
        resetInactivityTracking(now: Date(), clearAnchor: true)
        lastAcceptedWalkLocation = nil
        clearActiveWalkSession()
        withAnimation { [weak self] in
            self?.isWalking = false
        }
        syncWatchContext(force: true)
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
    }

    func toggleWalkStartCountdown() {
        walkStartCountdownEnabled.toggle()
        userSessionStore.setWalkStartCountdownEnabled(walkStartCountdownEnabled)
    }

    func toggleWalkPointRecordMode() {
        walkPointRecordMode = walkPointRecordMode == .manual ? .auto : .manual
        userSessionStore.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)
        resetAutoPointRecordState()
    }

    /// 영역 추가 버튼 입력 방식을 1탭 모드와 길게 누르기 모드 사이에서 전환합니다.
    func toggleAddPointLongPressMode() {
        isAddPointLongPressModeEnabled.toggle()
        preferenceStore.set(isAddPointLongPressModeEnabled, forKey: addPointLongPressModeKey)
    }

    var isAutoPointRecordMode: Bool {
        walkPointRecordMode == .auto
    }

    var autoEndPolicySummaryText: String {
        "무이동 5/12/15분 단계(휴식 후보/경고/자동 종료) + 최대 1시간 자동 종료"
    }

    var autoEndPolicyHintText: String {
        "판정 기준: 정확도 40m 이내, 속도 0.3m/s 미만, 이동거리 25m 미만"
    }

    var shouldShowWatchStatus: Bool {
        isWalking || latestWatchActionText.isEmpty == false
    }

    var hasRuntimeGuardStatus: Bool {
        runtimeGuardStatusText.isEmpty == false
    }

    var hasSyncOutboxStatus: Bool {
        syncOutboxPendingCount > 0 || syncOutboxPermanentFailureCount > 0
    }

    var isLocationPermissionDenied: Bool {
        let status = locationManager.authorizationStatus
        MapCoreLocationCallTracer.record(
            "authorizationStatus.read",
            detail: "source=isLocationPermissionDenied status=\(status.rawValue)"
        )
        return status == .restricted || status == .denied
    }

    var isOfflineRecoveryMode: Bool {
        syncOutboxPendingCount > 0 && syncOutboxLastErrorCodeText == SyncOutboxErrorCode.offline.rawValue
    }

    var syncOutboxStatusText: String {
        if syncOutboxPermanentFailureCount > 0 {
            if syncOutboxLastErrorCodeText.isEmpty == false {
                return "동기화 영구실패 \(syncOutboxPermanentFailureCount)건 (\(syncOutboxErrorDescription(rawValue: syncOutboxLastErrorCodeText)))"
            }
            return "동기화 영구실패 \(syncOutboxPermanentFailureCount)건"
        }
        if syncOutboxPendingCount > 0 {
            return "동기화 대기 \(syncOutboxPendingCount)건"
        }
        return ""
    }

    func clearWalkStatusMessage() {
        walkStatusMessage = nil
    }

    func clearRuntimeGuardStatus() {
        runtimeGuardStatusText = ""
    }

    func clearSyncRecoveryToastMessage() {
        syncRecoveryToastMessage = nil
    }

    func retrySyncNow() {
        walkStatusMessage = "동기화를 다시 시도합니다."
        flushSyncOutboxIfNeeded(force: true)
    }

    private func refreshSyncOutboxSummary() {
        let previous = lastSyncSummarySnapshot
        let summary = syncOutbox.summary()
        syncOutboxPendingCount = summary.pendingCount
        syncOutboxPermanentFailureCount = summary.permanentFailureCount
        syncOutboxLastErrorCodeText = summary.lastErrorCode?.rawValue ?? ""

        if let previous,
           previous.pendingCount > 0,
           previous.lastErrorCode == .offline,
           summary.pendingCount == 0,
           summary.lastErrorCode == nil {
            syncRecoveryToastMessage = "온라인 복구: 대기 중 기록 동기화를 완료했어요."
        }
        lastSyncSummarySnapshot = summary
    }

    /// 동기화 오류 코드를 사용자에게 읽기 쉬운 상태 문구로 변환합니다.
    /// - Parameter rawValue: `SyncOutboxErrorCode`의 raw 문자열입니다.
    /// - Returns: 상태 표시용 오류 문구입니다.
    private func syncOutboxErrorDescription(rawValue: String) -> String {
        guard let code = SyncOutboxErrorCode(rawValue: rawValue) else {
            return rawValue
        }
        switch code {
        case .notConfigured:
            return "서버 기능 미배포(404)"
        case .offline:
            return "오프라인"
        case .tokenExpired, .unauthorized:
            return "인증 만료"
        case .serverError:
            return "서버 오류"
        case .schemaMismatch:
            return "스키마 불일치"
        case .storageQuota:
            return "저장소 한도"
        case .conflict:
            return "충돌"
        case .unknown:
            return "알 수 없음"
        }
    }

    private func enqueueSyncOutbox(for polygon: Polygon, hasImage: Bool) {
        guard isCloudSyncAvailableForSession else { return }
        guard let sessionDTO = WalkBackfillDTOConverter.makeSessionDTO(
            from: polygon,
            ownerUserId: currentMetricUserId(),
            petId: polygon.petId,
            sourceDevice: "ios",
            hasImage: hasImage
        ) else { return }
        syncOutbox.enqueueWalkStages(sessionDTO: sessionDTO)
        refreshSyncOutboxSummary()
        flushSyncOutboxIfNeeded(force: true)
    }

    private func flushSyncOutboxIfNeeded(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastSyncFlushAt) < 5.0 {
            return
        }
        guard syncFlushTask == nil else { return }
        lastSyncFlushAt = now
        syncFlushTask = Task { [weak self] in
            guard let self else { return }
            let summary = await syncOutbox.flush(using: syncTransport, now: Date())
            await MainActor.run {
                let previous = self.lastSyncSummarySnapshot
                self.syncOutboxPendingCount = summary.pendingCount
                self.syncOutboxPermanentFailureCount = summary.permanentFailureCount
                self.syncOutboxLastErrorCodeText = summary.lastErrorCode?.rawValue ?? ""
                if let previous,
                   previous.pendingCount > 0,
                   previous.lastErrorCode == .offline,
                   summary.pendingCount == 0,
                   summary.lastErrorCode == nil {
                    self.syncRecoveryToastMessage = "온라인 복구: 대기 중 기록 동기화를 완료했어요."
                }
                self.lastSyncSummarySnapshot = summary
                self.syncFlushTask = nil
            }
        }
    }

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func statusTimeString(from date: Date) -> String {
        statusTimeFormatter.string(from: date)
    }

    private func setRuntimeGuardStatus(_ message: String) {
        runtimeGuardStatusText = "\(Self.statusTimeString(from: Date())) \(message)"
        triggerWarningHapticIfNeeded()
    }

    var isMapMotionReduced: Bool {
        #if canImport(UIKit)
        return mapMotionReduced || UIAccessibility.isReduceMotionEnabled
        #else
        return mapMotionReduced
        #endif
    }

    func toggleMapMotionReduced() {
        mapMotionReduced.toggle()
        preferenceStore.set(mapMotionReduced, forKey: mapMotionReducedKey)
    }

    var weatherOverlayTintColor: Color {
        switch weatherOverlayRiskLevel {
        case .clear: return .clear
        case .caution: return Color.appYellowPale
        case .bad: return Color.appPeach
        case .severe: return Color.appRed
        }
    }

    var weatherOverlayAnimationDuration: Double {
        isMapMotionReduced ? 0.18 : 0.42
    }

    var clusterMotionAnimationDuration: Double {
        isMapMotionReduced ? 0.14 : 0.28
    }

    var captureRippleDuration: Double {
        isMapMotionReduced ? 0.35 : 0.52
    }

    var activeTrailMarkers: [TrailMarker] {
        guard isWalking else { return [] }
        let now = Date().timeIntervalSince1970
        return Array(
            polygon.locations
            .suffix(trailLimit * 2)
            .reversed()
            .compactMap { point in
                let age = max(0, now - point.createdAt)
                guard age <= trailLifetime else { return nil }
                return TrailMarker(id: point.id, coordinate: point.coordinate, age: age)
            }
            .prefix(trailLimit)
            .map { $0 }
            .reversed()
        )
    }

    func activeCaptureRipples(at now: Date = Date()) -> [CaptureRipple] {
        let nowTs = now.timeIntervalSince1970
        return captureRipples.filter { nowTs - $0.createdAt <= captureRippleDuration }
    }

    func captureRippleProgress(for ripple: CaptureRipple, now: Date = Date()) -> Double {
        let elapsed = max(0, now.timeIntervalSince1970 - ripple.createdAt)
        return min(1.0, elapsed / max(0.001, captureRippleDuration))
    }

    func compactMapMotionArtifacts(now: Date = Date()) {
        let valid = activeCaptureRipples(at: now)
        if valid.count != captureRipples.count {
            captureRipples = valid
        }
    }

    private func pushCaptureRipple(at coordinate: CLLocationCoordinate2D, source: PointAppendSource) {
        let ripple = CaptureRipple(coordinate: coordinate)
        captureRipples.append(ripple)
        if captureRipples.count > maxCaptureRipples {
            captureRipples.removeFirst(captureRipples.count - maxCaptureRipples)
        }
        if source != .auto {
            triggerCaptureHapticIfNeeded()
        }
    }

    private func triggerCaptureHapticIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastCaptureHapticAt) >= 0.08 else { return }
        lastCaptureHapticAt = now
        AppHapticFeedback.mapCaptureSuccess(reducedMotion: isMapMotionReduced)
    }

    private func triggerWarningHapticIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastWarningHapticAt) >= 1.2 else { return }
        lastWarningHapticAt = now
        AppHapticFeedback.mapWarning()
    }

    private func validateWalkLocationSample(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= locationAccuracyThreshold else {
            setRuntimeGuardStatus("저정확도 GPS 샘플 폐기")
            return false
        }

        if let last = lastAcceptedWalkLocation {
            let delta = max(0.001, location.timestamp.timeIntervalSince(last.timestamp))
            let distance = location.distance(from: last)
            let speed = distance / delta
            let isJumpBySpeed = speed > jumpSpeedThreshold && distance > autoRecordNoiseDistance
            let isJumpByDistance = distance > jumpDistanceThreshold && delta <= jumpTimeWindow
            if isJumpBySpeed || isJumpByDistance {
                setRuntimeGuardStatus("비정상 점프 포인트 폐기")
                return false
            }
        }

        lastAcceptedWalkLocation = location
        return true
    }

    private func resetInactivityTracking(now: Date, clearAnchor: Bool) {
        lastMovementAt = now
        if clearAnchor {
            movementAnchorLocation = nil
        }
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false
    }

    private func updateMovementState(with location: CLLocation) {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= inactivityAccuracyThreshold else {
            return
        }
        guard let anchor = movementAnchorLocation else {
            movementAnchorLocation = location
            lastMovementAt = location.timestamp
            return
        }
        let distance = location.distance(from: anchor)
        let speedCandidate = location.speed >= 0 ? location.speed : max(0, distance / max(1, location.timestamp.timeIntervalSince(anchor.timestamp)))
        let isMoving = speedCandidate >= inactivitySpeedThreshold || distance >= inactivityDistanceThreshold
        if isMoving {
            movementAnchorLocation = location
            resetInactivityTracking(now: location.timestamp, clearAnchor: false)
        }
    }

    private func pauseWalkForAuthorizationDowngrade() {
        guard isWalking else { return }
        timerStop()
        persistActiveWalkSession(force: true)
        prepareRecoverableSessionIfNeeded()
        withAnimation { [weak self] in
            self?.isWalking = false
        }
        syncWatchContext(force: true)
        walkStatusMessage = "위치 권한이 해제되어 산책을 안전 일시중지했습니다."
        setRuntimeGuardStatus("권한 강등 감지로 세션 일시중지")
        syncWalkWidgetSnapshot(force: true, statusOverride: .locationDenied, messageOverride: walkStatusMessage)
        syncWalkLiveActivity(force: true)
    }

    private func prepareRecoverableSessionIfNeeded() {
        guard let snapshot = decodeActiveWalkSession() else { return }
        guard Date().timeIntervalSince1970 - snapshot.savedAt <= recoverableSessionMaxAge else {
            clearActiveWalkSession()
            return
        }
        guard snapshot.elapsedTime > 0 || snapshot.points.isEmpty == false else {
            clearActiveWalkSession()
            return
        }
        let now = Date()
        pendingRecoverableSession = snapshot
        hasRecoverableWalkSession = true
        recoverableWalkSummaryText = "미종료 산책 \(Int(snapshot.elapsedTime))초 · 포인트 \(snapshot.points.count)개"
        recoverableWalkEstimateText = recoverableFinalizationEstimateText(snapshot: snapshot, now: now)
        metricTracker.track(
            .recoveryDraftDetected,
            userKey: currentMetricUserId(),
            payload: [
                "pointCount": "\(snapshot.points.count)",
                "elapsedSec": "\(Int(snapshot.elapsedTime))"
            ]
        )
    }

    private func recoverableFinalizationEstimate(
        snapshot: ActiveWalkSessionSnapshot,
        now: Date
    ) -> (endedAt: TimeInterval?, source: String) {
        let lastMovementAt = snapshotLastMovementTime(snapshot)
        let inactivity = now.timeIntervalSince(lastMovementAt)
        if inactivity < restCandidateInterval {
            return (nil, "resume_recommended")
        }
        let estimated = min(now.timeIntervalSince1970, lastMovementAt.timeIntervalSince1970 + inactivityFinalizeInterval)
        return (max(snapshot.startedAt, estimated), "last_movement_plus_threshold")
    }

    private func recoverableFinalizationEstimateText(
        snapshot: ActiveWalkSessionSnapshot,
        now: Date
    ) -> String {
        let estimate = recoverableFinalizationEstimate(snapshot: snapshot, now: now)
        guard let endedAt = estimate.endedAt else {
            return "최근 이동이 감지되어 세션 복구를 권장해요."
        }
        return "추정 종료 시각 \(Self.statusTimeString(from: Date(timeIntervalSince1970: endedAt))) (마지막 이동 + 15분)"
    }

    private func snapshotLastMovementTime(_ snapshot: ActiveWalkSessionSnapshot) -> Date {
        if let lastMovementAt = snapshot.lastMovementAt {
            return Date(timeIntervalSince1970: lastMovementAt)
        }
        if let lastPointAt = snapshot.points.last?.createdAt {
            return Date(timeIntervalSince1970: lastPointAt)
        }
        return Date(timeIntervalSince1970: snapshot.startedAt + snapshot.elapsedTime)
    }

    func resumeRecoverableWalkSession() {
        resumeRecoverableWalkSession(autoRecovered: false)
    }

    private func resumeRecoverableWalkSession(autoRecovered: Bool) {
        guard let snapshot = pendingRecoverableSession, isWalking == false else { return }

        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }

        polygon = Polygon(
            locations: restoredPoints,
            walkingTime: snapshot.elapsedTime,
            walkingArea: 0.0,
            petId: snapshot.selectedPetId
        )
        if let sessionId = snapshot.sessionId, let restoredId = UUID(uuidString: sessionId) {
            polygon.id = restoredId
        }
        time = snapshot.elapsedTime
        startTime = Date().addingTimeInterval(-snapshot.elapsedTime)
        if restoredPoints.count > 2 {
            makePolygon()
        }

        if let selectedPetId = snapshot.selectedPetId {
            userSessionStore.setSelectedPetId(selectedPetId, source: "walk_recovery")
        }
        reloadSelectedPetContext()
        currentWalkingPetName = snapshot.currentWalkingPetName
        walkPointRecordMode = WalkPointRecordMode(rawValue: snapshot.pointRecordMode) ?? .manual
        userSessionStore.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)

        lastPointEventAt = snapshot.points.last.map { Date(timeIntervalSince1970: $0.createdAt) } ?? Date()
        lastMovementAt = snapshot.lastMovementAt.map { Date(timeIntervalSince1970: $0) } ?? lastPointEventAt
        lastAutoRecordedLocation = snapshot.points.last.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        lastAcceptedWalkLocation = lastAutoRecordedLocation
        movementAnchorLocation = lastAutoRecordedLocation
        lastAutoRecordedAt = lastPointEventAt ?? Date()
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false

        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        pendingRecoverableSession = nil

        withAnimation { [weak self] in
            self?.isWalking = true
        }
        timerSet()
        persistActiveWalkSession(force: true)
        walkStatusMessage = autoRecovered ? "산책 세션을 자동 복구했습니다." : "이전 산책 세션을 복구했습니다."
        setRuntimeGuardStatus("세션 복구 완료")
        syncWatchContext(force: true)
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
    }

    func discardRecoverableWalkSession() {
        metricTracker.track(
            .recoveryDraftDiscarded,
            userKey: currentMetricUserId(),
            payload: [:]
        )
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        recoverableWalkEstimateText = ""
        clearActiveWalkSession()
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
    }

    func finalizeRecoverableWalkSessionEstimated() {
        guard let snapshot = pendingRecoverableSession else {
            clearActiveWalkSession()
            return
        }
        let estimate = recoverableFinalizationEstimate(snapshot: snapshot, now: Date())
        guard let endedAt = estimate.endedAt else {
            walkStatusMessage = "최근 이동이 감지되어 추정 종료를 권장하지 않아요. 복구 후 종료해주세요."
            return
        }
        finalizeRecoverableWalkSession(
            snapshot: snapshot,
            endedAt: endedAt,
            reason: .recoveryEstimated,
            successMessage: "미종료 산책을 추정 종료 시각으로 저장했습니다.",
            metricSource: estimate.source
        )
    }

    func finalizeRecoverableWalkSessionNow() {
        guard let snapshot = pendingRecoverableSession else {
            clearActiveWalkSession()
            return
        }
        finalizeRecoverableWalkSession(
            snapshot: snapshot,
            endedAt: Date().timeIntervalSince1970,
            reason: .manual,
            successMessage: "미종료 산책을 지금 종료로 저장했습니다.",
            metricSource: "manual_now"
        )
    }

    private func finalizeRecoverableWalkSession(
        snapshot: ActiveWalkSessionSnapshot,
        endedAt: TimeInterval,
        reason: WalkSessionEndReason,
        successMessage: String,
        metricSource: String
    ) {
        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }
        guard restoredPoints.count > 2 else {
            walkStatusMessage = "포인트 부족으로 종료 확정을 할 수 없어요. 복구 후 계속 기록하거나 폐기해주세요."
            metricTracker.track(
                .recoveryFinalizeFailed,
                userKey: currentMetricUserId(),
                payload: ["reason": "insufficient_points"]
            )
            return
        }
        let finalizedEndAt = max(snapshot.startedAt, endedAt)
        let walkTime = max(0, finalizedEndAt - snapshot.startedAt)
        let restoredSessionId = snapshot.sessionId.flatMap(UUID.init(uuidString:))
        let completed = Polygon(
            locations: restoredPoints,
            createdAt: snapshot.startedAt,
            id: restoredSessionId ?? UUID(),
            walkingTime: walkTime,
            walkingArea: 0.0,
            imgData: nil,
            petId: snapshot.selectedPetId
        )
        var finalized = completed
        finalized.makePolygon(walkArea: calculateArea(points: restoredPoints), walkTime: walkTime)
        let updated = walkRepository.savePolygon(finalized)
        if updated.contains(where: { $0.id == finalized.id }) {
            WalkSessionMetadataStore.shared.set(
                sessionId: finalized.id,
                reason: reason,
                endedAt: finalizedEndAt,
                petId: snapshot.selectedPetId
            )
            enqueueSyncOutbox(for: finalized, hasImage: finalized.binaryImage != nil)
            walkStatusMessage = successMessage
            metricTracker.track(
                .recoveryFinalizeConfirmed,
                userKey: currentMetricUserId(),
                payload: [
                    "mode": reason.rawValue,
                    "source": metricSource,
                    "endedAt": "\(Int(finalizedEndAt))"
                ]
            )
            applyPolygonList(updated)
            clearActiveWalkSession()
            syncWalkWidgetSnapshot(force: true)
            syncWalkLiveActivity(force: true)
        } else {
            walkStatusMessage = "미종료 산책 종료 저장에 실패했습니다."
            metricTracker.track(
                .recoveryFinalizeFailed,
                userKey: currentMetricUserId(),
                payload: ["reason": "local_save_failed"]
            )
        }
    }

    private func decodeActiveWalkSession() -> ActiveWalkSessionSnapshot? {
        guard let data = preferenceStore.data(forKey: activeWalkSessionStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ActiveWalkSessionSnapshot.self, from: data)
    }

    private func persistActiveWalkSession(force: Bool = false) {
        guard isWalking else { return }
        let now = Date()
        if force == false, now.timeIntervalSince(lastSnapshotPersistAt) < 10.0 {
            return
        }

        let snapshot = ActiveWalkSessionSnapshot(
            sessionId: polygon.id.uuidString.lowercased(),
            startedAt: startTime.timeIntervalSince1970,
            elapsedTime: time,
            selectedPetId: selectedPetId,
            selectedPetName: selectedPetName,
            currentWalkingPetName: currentWalkingPetName,
            pointRecordMode: walkPointRecordMode.rawValue,
            lastMovementAt: lastMovementAt?.timeIntervalSince1970,
            points: polygon.locations.map {
                ActiveWalkPointSnapshot(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude,
                    createdAt: $0.createdAt
                )
            },
            savedAt: now.timeIntervalSince1970
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            preferenceStore.set(data, forKey: activeWalkSessionStorageKey)
            lastSnapshotPersistAt = now
        }
    }

    private func clearActiveWalkSession() {
        preferenceStore.removeObject(forKey: activeWalkSessionStorageKey)
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        recoverableWalkEstimateText = ""
        lastPointEventAt = nil
        lastMovementAt = nil
        movementAnchorLocation = nil
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false
        lastAcceptedWalkLocation = nil
    }

    private func handleAutoEndIfNeeded(now: Date = Date()) {
        guard isWalking else { return }
        let baseline = lastMovementAt ?? lastPointEventAt ?? startTime
        let inactivity = now.timeIntervalSince(baseline)

        if inactivity >= inactivityFinalizeInterval {
            let endedAt = min(now.timeIntervalSince1970, baseline.timeIntervalSince1970 + inactivityFinalizeInterval)
            if polygon.locations.count > 2 {
                endWalk(reason: .autoInactive, endedAtOverride: Date(timeIntervalSince1970: endedAt))
                walkStatusMessage = "15분 무이동으로 산책을 자동 종료했습니다."
                triggerWarningHapticIfNeeded()
            } else {
                discardCurrentWalk()
                walkStatusMessage = "15분 무이동으로 산책 임시기록을 폐기했습니다."
                triggerWarningHapticIfNeeded()
            }
            return
        }

        if inactivity >= inactivityWarningInterval, didNotifyInactivityWarning == false {
            didNotifyInactivityWarning = true
            walkStatusMessage = "12분 무이동: 3분 후 자동 종료 예정입니다."
            triggerWarningHapticIfNeeded()
            syncWalkLiveActivity(force: true)
            return
        }

        if inactivity >= restCandidateInterval, didNotifyRestCandidate == false {
            didNotifyRestCandidate = true
            walkStatusMessage = "5분 무이동: 휴식 상태로 감지했습니다."
            syncWalkLiveActivity(force: true)
        }
    }

    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        let didBecomeActive = eventCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushSyncOutboxIfNeeded(force: true)
            self?.syncVisibilitySettingIfNeeded()
            self?.refreshWeatherOverlayRisk()
            self?.syncWalkLiveActivity(force: true)
        }
        let willResign = eventCenter.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let willTerminate = eventCenter.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let petContextChanged = eventCenter.addObserver(
            forName: UserdefaultSetting.selectedPetDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSelectedPetContext()
        }
        #if canImport(UIKit)
        let reduceMotionChanged = eventCenter.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
            self?.refreshWeatherOverlayRisk()
        }
        lifecycleObservers = [didBecomeActive, willResign, willTerminate, petContextChanged, reduceMotionChanged]
        #else
        lifecycleObservers = [didBecomeActive, willResign, willTerminate, petContextChanged]
        #endif
        #endif
    }

    private func appendWalkPoint(from location: CLLocation, recordedAt: Date, source: PointAppendSource) -> Location {
        let appendedPoint = Location(
            coordinate: location.coordinate,
            id: UUID(),
            createdAt: recordedAt.timeIntervalSince1970
        )
        polygon.addPoint(appendedPoint)
        pushCaptureRipple(at: location.coordinate, source: source)
        lastAutoRecordedLocation = location
        lastAutoRecordedAt = recordedAt
        lastPointEventAt = recordedAt
        movementAnchorLocation = location
        resetInactivityTracking(now: recordedAt, clearAnchor: false)
        if source == .watch {
            latestWatchActionText = "워치 포인트 반영 \(Self.statusTimeString(from: recordedAt))"
        }
        persistActiveWalkSession(force: true)
        syncWatchContext(force: true)
        syncWalkWidgetSnapshot()
        syncWalkLiveActivity()
        compactMapMotionArtifacts(now: recordedAt)
        eventCenter.post(
            name: .walkPointRecordedForQuest,
            object: nil,
            userInfo: [
                "source": "\(source)",
                "recordedAt": recordedAt.timeIntervalSince1970
            ]
        )
        return appendedPoint
    }

    private func resetAutoPointRecordState() {
        lastAutoRecordedLocation = nil
        lastAutoRecordedAt = .distantPast
    }

    private func handleAutoPointRecord(with location: CLLocation) {
        guard isWalking, walkPointRecordMode == .auto else { return }
        let now = Date()

        if polygon.locations.isEmpty {
            appendWalkPoint(from: location, recordedAt: now, source: .auto)
            return
        }

        if let lastPoint = polygon.locations.last {
            let lastPointLocation = CLLocation(
                latitude: lastPoint.coordinate.latitude,
                longitude: lastPoint.coordinate.longitude
            )
            if location.distance(from: lastPointLocation) < autoRecordNoiseDistance {
                return
            }
        }

        if let lastAutoRecordedLocation {
            let moved = location.distance(from: lastAutoRecordedLocation)
            let elapsed = now.timeIntervalSince(lastAutoRecordedAt)
            guard moved >= autoRecordMinDistance, elapsed >= autoRecordMinInterval else {
                return
            }
        }

        appendWalkPoint(from: location, recordedAt: now, source: .auto)
    }
    /// 지도 카메라를 내 위치 추적 모드로 전환합니다.
    /// - Parameter reason: 추적 전환을 유발한 원인입니다. 전달 시 카메라 변경 로그 원인으로 사용됩니다.
    func setTrackingMode(reason: CameraChangeReason? = nil) {
        if let reason {
            markPendingCameraChangeReason(reason)
        }
        guard let location = self.location else {
            walkStatusMessage = "현재 위치를 아직 확인하지 못했어요."
            return
        }
        setRegion(location, distance: 2000)
    }

    /// 사용자의 `내 위치 보기` 요청을 지도 추적 모드 전환으로 처리합니다.
    func handleLocationButtonTap() {
        setTrackingMode(reason: .locationButton)
    }

    /// 지도 카메라 변경 이벤트를 기록하고 원인별 디버그 로그를 남깁니다.
    /// - Parameters:
    ///   - camera: 현재 지도 카메라 상태입니다.
    ///   - now: 로그 판정 기준 시각입니다.
    func recordCameraChange(_ camera: MapCamera, now: Date = Date()) {
        self.camera = camera
        let reason = resolveCameraChangeReason(now: now)
        guard shouldLogCameraChange(camera, reason: reason) else { return }
        #if DEBUG
        let latitude = String(format: "%.5f", camera.centerCoordinate.latitude)
        let longitude = String(format: "%.5f", camera.centerCoordinate.longitude)
        print(
            "map camera change: reason=\(reason.rawValue) distance=\(Int(camera.distance)) center=(\(latitude),\(longitude))"
        )
        #endif
        lastLoggedCameraCenter = camera.centerCoordinate
        lastLoggedCameraDistance = camera.distance
        lastLoggedCameraReason = reason
    }

    /// 수동 포인트 추가 후 카메라가 점프했을 때 직전 스냅샷으로 복원합니다.
    private func restorePointAddCameraSnapshotIfNeeded() {
        guard let snapshot = pendingPointAddCameraSnapshot else { return }
        defer { pendingPointAddCameraSnapshot = nil }

        let centerDelta = greatCircleDistanceMeters(
            from: camera.centerCoordinate,
            to: snapshot.centerCoordinate
        )
        let distanceDelta = abs(camera.distance - snapshot.distance)
        guard centerDelta > 15 || distanceDelta > 15 else { return }

        setRegion(snapshot.centerCoordinate, distance: snapshot.distance, reason: .systemFallback)
    }

    /// 다음 카메라 변경 이벤트에 적용할 원인을 저장합니다.
    /// - Parameter reason: 카메라 변경 원인입니다.
    private func markPendingCameraChangeReason(_ reason: CameraChangeReason) {
        pendingCameraChangeReason = reason
        pendingCameraReasonSetAt = Date()
    }

    /// 저장된 카메라 변경 원인을 해석해 반환합니다.
    /// - Parameter now: 원인 유효 시간 판정 기준 시각입니다.
    /// - Returns: 저장된 원인이 유효하면 해당 값, 아니면 `.manualMove`입니다.
    private func resolveCameraChangeReason(now: Date) -> CameraChangeReason {
        guard let reason = pendingCameraChangeReason else { return .manualMove }
        defer { pendingCameraChangeReason = nil }
        if now.timeIntervalSince(pendingCameraReasonSetAt) > pendingCameraReasonTTL {
            return .manualMove
        }
        return reason
    }

    /// 카메라 로그를 남길지 여부를 이전 로그 상태와 비교해 판단합니다.
    /// - Parameters:
    ///   - camera: 현재 지도 카메라 상태입니다.
    ///   - reason: 이번 변경 원인입니다.
    /// - Returns: 임계치를 넘는 변경이거나 원인이 바뀌었으면 `true`입니다.
    private func shouldLogCameraChange(_ camera: MapCamera, reason: CameraChangeReason) -> Bool {
        guard let lastCenter = lastLoggedCameraCenter,
              let lastDistance = lastLoggedCameraDistance,
              let lastReason = lastLoggedCameraReason else {
            return true
        }

        if lastReason != reason { return true }

        let centerDelta = greatCircleDistanceMeters(from: lastCenter, to: camera.centerCoordinate)
        let distanceDelta = abs(camera.distance - lastDistance)
        return centerDelta >= cameraLogCenterThreshold || distanceDelta >= cameraLogDistanceThreshold
    }

    /// 두 좌표 사이의 대권 거리(미터)를 계산합니다.
    /// - Parameters:
    ///   - from: 시작 좌표입니다.
    ///   - to: 도착 좌표입니다.
    /// - Returns: 두 좌표 간 거리(미터)입니다.
    private func greatCircleDistanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadius * c
    }

    private func forceQuit() {
        endWalk(reason: .autoTimeout)
        walkStatusMessage = "최대 산책 시간 도달로 자동 종료했습니다."
    }

    func deletePolygonAndRefresh(_ id: UUID) {
        WalkSessionMetadataStore.shared.clear(sessionId: id)
        let updated = walkRepository.deletePolygon(id: id)
        self.applyPolygonList(updated)
    }

    func refreshHeatmap(now: Date = Date()) {
        guard isHeatmapFeatureAvailable else {
            self.heatmapCells = []
            return
        }
        let points = self.polygonList.flatMap { $0.locations }
        self.heatmapCells = HeatmapEngine.aggregate(points: points, now: now, precision: 7)
    }

    var isHeatmapFeatureAvailable: Bool {
        featureFlags.isEnabled(.heatmapV1)
    }

    var isCloudSyncAvailableForSession: Bool {
        AppFeatureGate.isAllowed(.cloudSync)
    }

    var isNearbySocialAvailableForSession: Bool {
        AppFeatureGate.isAllowed(.nearbySocial)
    }

    var isNearbyHotspotFeatureAvailable: Bool {
        featureFlags.isEnabled(.nearbyHotspotV1) && isNearbySocialAvailableForSession
    }

    private func lodIntValue(key: String, defaultValue: Int) -> Int {
        preferenceStore.integer(forKey: key, default: defaultValue)
    }

    private func lodDoubleValue(key: String, defaultValue: Double) -> Double {
        preferenceStore.double(forKey: key, default: defaultValue)
    }

    private var overlayMaxCameraDistance: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.overlayMaxCameraDistanceKey,
            defaultValue: MapOverlayLODTuning.overlayMaxCameraDistanceDefault
        )
    }

    private var overlayClusterThreshold: Int {
        lodIntValue(
            key: MapOverlayLODTuning.overlayClusterThresholdKey,
            defaultValue: MapOverlayLODTuning.overlayClusterThresholdDefault
        )
    }

    private var overlayPolygonCountThreshold: Int {
        lodIntValue(
            key: MapOverlayLODTuning.overlayPolygonCountThresholdKey,
            defaultValue: MapOverlayLODTuning.overlayPolygonCountThresholdDefault
        )
    }

    private var singleClusterOverlayLimit: Int {
        lodIntValue(
            key: MapOverlayLODTuning.singleClusterOverlayLimitKey,
            defaultValue: MapOverlayLODTuning.singleClusterOverlayLimitDefault
        )
    }

    private var clusterCellDistanceRatio: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellDistanceRatioKey,
            defaultValue: MapOverlayLODTuning.clusterCellDistanceRatioDefault
        )
    }

    private var clusterCellMinMeters: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellMinMetersKey,
            defaultValue: MapOverlayLODTuning.clusterCellMinMetersDefault
        )
    }

    private var clusterCellMaxMeters: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellMaxMetersKey,
            defaultValue: MapOverlayLODTuning.clusterCellMaxMetersDefault
        )
    }

    var shouldRenderFullPolygonOverlays: Bool {
        guard showOnlyOne == false else { return true }
        guard currentCameraDistance <= overlayMaxCameraDistance else { return false }
        guard centerLocations.count <= overlayClusterThreshold else { return false }
        guard polygonList.count <= overlayPolygonCountThreshold else { return false }
        return true
    }

    var renderablePolygonOverlays: [Polygon] {
        guard showOnlyOne == false else { return polygonList }
        guard shouldRenderFullPolygonOverlays == false else { return polygonList }

        let singleClusterIds: [UUID] = centerLocations.compactMap { cluster -> UUID? in
            guard cluster.sumLocs.count == 1 else { return nil }
            return cluster.sumLocs.first?.1
        }

        guard singleClusterIds.isEmpty == false else { return [] }
        let allowedIds = Set(singleClusterIds.prefix(singleClusterOverlayLimit))
        return polygonList.filter { allowedIds.contains($0.id) }
    }

    struct SeasonTileLegendItem: Identifiable, Equatable {
        let level: Int
        let label: String
        let status: String

        var id: Int { level }
    }

    func seasonTileIntensityLevel(for score: Double) -> Int {
        guard score > 0 else { return 0 }
        let level = Int(ceil(score * 4.0) - 1.0)
        return min(3, max(0, level))
    }

    func seasonTileStatusText(for score: Double) -> String {
        score >= 0.55 ? "점령" : "유지"
    }

    var seasonTileLegendItems: [SeasonTileLegendItem] {
        [
            .init(level: 0, label: "1단계", status: "유지"),
            .init(level: 1, label: "2단계", status: "유지"),
            .init(level: 2, label: "3단계", status: "점령"),
            .init(level: 3, label: "4단계", status: "점령")
        ]
    }

    var seasonOccupiedTileCount: Int {
        heatmapCells.filter { seasonTileStatusText(for: $0.score) == "점령" }.count
    }

    var seasonMaintainedTileCount: Int {
        heatmapCells.filter { seasonTileStatusText(for: $0.score) == "유지" }.count
    }

    var seasonTileStatusSummaryText: String {
        "시즌 타일 4단계 · 점령 \(seasonOccupiedTileCount) · 유지 \(seasonMaintainedTileCount)"
    }

    func heatmapColor(for score: Double) -> Color {
        let level = seasonTileIntensityLevel(for: score)
        let status = seasonTileStatusText(for: score)
        switch (level, status) {
        case (0, _): return Color.appGreen
        case (1, _): return Color.appYellowPale
        case (2, "점령"): return Color.appPeach
        case (2, _): return Color.appYellow
        case (3, "점령"): return Color.appRed
        default: return Color.appPeach
        }
    }

    func heatmapOpacity(for score: Double) -> Double {
        switch seasonTileIntensityLevel(for: score) {
        case 0: return 0.28
        case 1: return 0.38
        case 2: return 0.50
        default: return 0.62
        }
    }

    func nearbyHotspotColor(for intensity: Double) -> Color {
        switch intensity {
        case ..<0.2: return Color.appGreen
        case ..<0.4: return Color.appYellowPale
        case ..<0.6: return Color.appYellow
        case ..<0.8: return Color.appPeach
        default: return Color.appRed
        }
    }

    func nearbyHotspotOpacity(for intensity: Double) -> Double {
        switch intensity {
        case ..<0.2: return 0.22
        case ..<0.4: return 0.30
        case ..<0.6: return 0.40
        case ..<0.8: return 0.50
        default: return 0.60
        }
    }

    func toggleHeatmapEnabled() {
        guard isHeatmapFeatureAvailable else {
            self.heatmapEnabled = false
            self.heatmapCells = []
            return
        }
        self.heatmapEnabled.toggle()
        preferenceStore.set(self.heatmapEnabled, forKey: heatmapEnabledKey)
        if self.heatmapEnabled {
            refreshHeatmap()
        } else {
            self.heatmapCells = []
        }
    }

    func toggleLocationSharing() {
        guard isNearbyHotspotFeatureAvailable else {
            self.locationSharingEnabled = false
            preferenceStore.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
            return
        }
        self.locationSharingEnabled.toggle()
        preferenceStore.set(self.locationSharingEnabled, forKey: locationSharingKey)
        metricTracker.track(
            self.locationSharingEnabled ? .nearbyOptInEnabled : .nearbyOptInDisabled,
            userKey: currentMetricUserId(),
            featureKey: .nearbyHotspotV1
        )
        self.syncVisibilitySettingIfNeeded()
    }

    func toggleNearbyHotspotEnabled() {
        guard isNearbyHotspotFeatureAvailable else {
            self.nearbyHotspotEnabled = false
            self.nearbyHotspots = []
            preferenceStore.set(false, forKey: nearbyHotspotEnabledKey)
            return
        }
        self.nearbyHotspotEnabled.toggle()
        preferenceStore.set(self.nearbyHotspotEnabled, forKey: nearbyHotspotEnabledKey)
        if nearbyHotspotEnabled == false {
            self.nearbyHotspots = []
        }
    }

    private func startNearbyTicker() {
        nearbyTickTimer?.invalidate()
        nearbyTickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.nearbyTick()
        }
    }

    private func nearbyTick() {
        flushSyncOutboxIfNeeded()
        refreshWeatherOverlayRisk()
        guard let location else { return }
        let now = Date()

        if isNearbyHotspotFeatureAvailable && locationSharingEnabled && isWalking && now.timeIntervalSince(lastPresenceSentAt) >= 30 {
            lastPresenceSentAt = now
            sendPresence(location: location.coordinate)
        }

        if isNearbyHotspotFeatureAvailable && nearbyHotspotEnabled && now.timeIntervalSince(lastNearbyFetchedAt) >= 10 {
            lastNearbyFetchedAt = now
            fetchNearbyHotspots(center: location.coordinate)
        }
    }

    private func sendPresence(location: CLLocationCoordinate2D) {
        guard let userId = currentPresenceUserId() else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.nearbyService.upsertPresence(
                    userId: userId,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            } catch {
                print("presence upsert failed: \(error.localizedDescription)")
            }
        }
    }
    private func publishWatchState() {
        if Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.publishWatchState()
            }
            return
        }
        guard let watchSession else { return }
        #if os(iOS)
        guard watchSession.isWatchAppInstalled else { return }
        #endif
        let context: [String: Any] = [
            "isWalking": isWalking,
            "time": time,
            "area": calculateArea()
        ]
        try? watchSession.updateApplicationContext(context)
    }
    private func applyWatchAction(_ action: String) {
        switch action {
        case "startWalk":
            if !isWalking {
                endWalk()
            }
        case "addPoint":
            if isWalking {
                addLocation()
                makePolygon()
            }
        case "endWalk":
            if isWalking {
                timerStop()
                endWalk()
            }
        default:
            break
        }
    }

    private func fetchNearbyHotspots(center: CLLocationCoordinate2D) {
        let userId = currentPresenceUserId()
        Task { [weak self] in
            guard let self else { return }
            do {
                let hotspots = try await nearbyService.getHotspots(
                    userId: userId,
                    centerLatitude: center.latitude,
                    centerLongitude: center.longitude,
                    radiusKm: 1.0
                )
                await MainActor.run {
                    self.nearbyHotspots = hotspots
                }
            } catch {
                if self.isNearbyHotspotNotFoundError(error) {
                    #if DEBUG
                    print("nearby hotspot fetch failed (not found): \(error.localizedDescription)")
                    #endif
                    await MainActor.run {
                        self.nearbyHotspots = []
                    }
                    return
                }
                self.logNearbyHotspotErrorIfNeeded(error)
            }
        }
    }

    /// 주변 핫스팟 조회 에러가 "리소스 없음(404)"인지 판별합니다.
    /// - Parameter error: 조회 실패 시 전달된 원본 에러입니다.
    /// - Returns: 404 계열 에러로 판단되면 `true`를 반환합니다.
    private func isNearbyHotspotNotFoundError(_ error: Error) -> Bool {
        if let supabaseError = error as? SupabaseHTTPError,
           case .unexpectedStatusCode(404) = supabaseError {
            return true
        }

        // SupabaseError가 래핑되어 올라오는 경우 localizedDescription 패턴으로 보조 판별합니다.
        let message = error.localizedDescription
        if message.contains("404") {
            return true
        }
        return false
    }

    /// 주변 핫스팟 조회 에러 로그를 일정 주기로만 출력해 콘솔 노이즈를 줄입니다.
    /// - Parameter error: 출력할 조회 실패 에러입니다.
    private func logNearbyHotspotErrorIfNeeded(_ error: Error) {
        #if DEBUG
        if suppressedNearbyHotspotErrorCount > 0 {
            print("nearby hotspot fetch failed: \(error.localizedDescription) (+\(suppressedNearbyHotspotErrorCount) suppressed)")
            suppressedNearbyHotspotErrorCount = 0
        } else {
            print("nearby hotspot fetch failed: \(error.localizedDescription)")
        }
        lastNearbyHotspotErrorLogAt = Date()
        return
        #endif

        let now = Date()
        if now.timeIntervalSince(lastNearbyHotspotErrorLogAt) < nearbyHotspotErrorLogInterval {
            suppressedNearbyHotspotErrorCount += 1
            return
        }

        if suppressedNearbyHotspotErrorCount > 0 {
            print("nearby hotspot fetch failed: \(error.localizedDescription) (+\(suppressedNearbyHotspotErrorCount) suppressed)")
            suppressedNearbyHotspotErrorCount = 0
        } else {
            print("nearby hotspot fetch failed: \(error.localizedDescription)")
        }
        lastNearbyHotspotErrorLogAt = now
    }

    /// 가시성(Visibility) 동기화 에러 로그를 일정 주기로만 출력해 콘솔 노이즈를 줄입니다.
    /// - Parameter error: 출력할 동기화 실패 에러입니다.
    private func logVisibilitySyncErrorIfNeeded(_ error: Error) {
        #if DEBUG
        if suppressedVisibilitySyncErrorCount > 0 {
            print("visibility sync failed: \(error.localizedDescription) (+\(suppressedVisibilitySyncErrorCount) suppressed)")
            suppressedVisibilitySyncErrorCount = 0
        } else {
            print("visibility sync failed: \(error.localizedDescription)")
        }
        lastVisibilitySyncErrorLogAt = Date()
        return
        #endif

        let now = Date()
        if now.timeIntervalSince(lastVisibilitySyncErrorLogAt) < nearbyHotspotErrorLogInterval {
            suppressedVisibilitySyncErrorCount += 1
            return
        }

        if suppressedVisibilitySyncErrorCount > 0 {
            print("visibility sync failed: \(error.localizedDescription) (+\(suppressedVisibilitySyncErrorCount) suppressed)")
            suppressedVisibilitySyncErrorCount = 0
        } else {
            print("visibility sync failed: \(error.localizedDescription)")
        }
        lastVisibilitySyncErrorLogAt = now
    }

    private func syncVisibilitySettingIfNeeded() {
        guard let userId = currentPresenceUserId() else { return }
        let enabled = isNearbyHotspotFeatureAvailable ? self.locationSharingEnabled : false
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.nearbyService.setVisibility(userId: userId, enabled: enabled)
                if enabled == false {
                    await MainActor.run {
                        self.nearbyHotspots = []
                    }
                }
            } catch {
                if self.isNearbyHotspotNotFoundError(error) {
                    #if DEBUG
                    print("visibility sync failed (not found): \(error.localizedDescription)")
                    #endif
                    return
                }
                self.logVisibilitySyncErrorIfNeeded(error)
            }
        }
    }

    private func refreshFeatureFlagsFromRemote() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.featureFlags.refresh()
            await MainActor.run {
                self.applyFeatureFlags()
            }
        }
    }

    private func applyFeatureFlags() {
        let heatmapAllowed = featureFlags.isEnabled(.heatmapV1)
        let nearbyAllowed = featureFlags.isEnabled(.nearbyHotspotV1)
        let nearbyAllowedForSession = nearbyAllowed && isNearbySocialAvailableForSession
        let heatmapPreference = preferenceStore.bool(forKey: heatmapEnabledKey, default: true)
        let nearbyPreference = preferenceStore.bool(forKey: nearbyHotspotEnabledKey, default: true)
        let sharingPreference = preferenceStore.bool(forKey: locationSharingKey, default: false)

        self.heatmapEnabled = heatmapAllowed ? heatmapPreference : false
        self.nearbyHotspotEnabled = nearbyAllowedForSession ? nearbyPreference : false
        self.locationSharingEnabled = nearbyAllowedForSession ? sharingPreference : false

        if heatmapAllowed {
            self.refreshHeatmap()
        } else {
            self.heatmapCells = []
        }

        if nearbyAllowedForSession == false {
            self.nearbyHotspots = []
            preferenceStore.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
        }
    }

    /// 저장된 날씨 위험도 캐시/환경값을 기준으로 현재 지도 오버레이 상태를 계산합니다.
    /// - Parameter now: 캐시 만료 판단 기준 시각입니다.
    /// - Returns: 적용할 위험도와 fallback 표시 여부입니다.
    private func resolveWeatherOverlayRiskFromDefaults(now: Date = Date()) -> (risk: WeatherOverlayRiskLevel, fallback: Bool) {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let fromEnv = WeatherOverlayRiskLevel(rawValue: env.lowercased()) {
            return (fromEnv, false)
        }
        if let raw = preferenceStore.string(forKey: weatherRiskOverrideKey),
           let fromDefaults = WeatherOverlayRiskLevel(rawValue: raw.lowercased()) {
            guard let observedAt = storedWeatherRiskObservedAt() else {
                return (fromDefaults, false)
            }
            let age = now.timeIntervalSince1970 - observedAt
            if age <= weatherRiskCacheTTL {
                return (fromDefaults, false)
            }
            let conservativeRisk: WeatherOverlayRiskLevel = fromDefaults == .clear ? .caution : fromDefaults
            return (conservativeRisk, true)
        }
        return (.caution, true)
    }

    func refreshWeatherOverlayRisk() {
        let next = resolveWeatherOverlayRiskFromDefaults()
        let nextRisk = next.risk
        weatherOverlayFallbackActive = next.fallback
        weatherOverlayStatusText = next.fallback
            ? "Fallback: 날씨 데이터 연결 불가"
            : "날씨 위험도 \(nextRisk.displayTitle)"
        guard nextRisk != weatherOverlayRiskLevel || (nextRisk == .clear && weatherOverlayOpacity != 0.0) else { return }
        withAnimation(.easeInOut(duration: weatherOverlayAnimationDuration)) {
            weatherOverlayRiskLevel = nextRisk
            weatherOverlayOpacity = nextRisk == .clear ? 0.0 : (isMapMotionReduced ? 0.12 : 0.18)
        }
    }

    /// 현재 위치를 기준으로 날씨 위험도를 비동기로 갱신하고 로컬 캐시에 반영합니다.
    /// - Parameters:
    ///   - location: 위험도 조회 기준 위치입니다.
    ///   - force: `true`이면 주기 제한을 무시하고 즉시 갱신합니다.
    private func refreshWeatherRiskFromProviderIfNeeded(location: CLLocation?, force: Bool) {
        guard ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"] == nil else { return }
        guard let location else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 160 else { return }
        guard weatherFetchTask == nil else { return }

        let now = Date()
        if force == false,
           now.timeIntervalSince(lastWeatherFetchAttemptAt) < weatherRiskRefreshInterval {
            return
        }
        lastWeatherFetchAttemptAt = now

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        weatherFetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await weatherRiskProvider.fetchRisk(
                    latitude: latitude,
                    longitude: longitude
                )
                await MainActor.run {
                    self.applyWeatherRiskSnapshot(snapshot)
                }
            } catch {
                await MainActor.run {
                    self.refreshWeatherOverlayRisk()
                }
            }
            await MainActor.run {
                self.weatherFetchTask = nil
            }
        }
    }

    /// 날씨 공급자 응답을 저장소와 UI 상태에 반영합니다.
    /// - Parameter snapshot: 공급자에서 계산된 날씨 위험도 스냅샷입니다.
    private func applyWeatherRiskSnapshot(_ snapshot: WeatherRiskSnapshot) {
        let next = WeatherOverlayRiskLevel(rawValue: snapshot.level.rawValue) ?? .clear
        preferenceStore.set(next.rawValue, forKey: weatherRiskOverrideKey)
        preferenceStore.set(String(snapshot.observedAt), forKey: weatherRiskObservedAtKey)
        refreshWeatherOverlayRisk()
    }

    /// 저장소에 캐시된 날씨 위험도 관측 시각을 조회합니다.
    /// - Returns: epoch seconds 관측 시각이며, 파싱 실패 시 `nil`을 반환합니다.
    private func storedWeatherRiskObservedAt() -> TimeInterval? {
        guard let raw = preferenceStore.string(forKey: weatherRiskObservedAtKey),
              let value = Double(raw) else {
            return nil
        }
        return value
    }

    private func currentPresenceUserId() -> String? {
        if let authUserId = authSessionStore.currentIdentity()?.userId,
           let canonical = authUserId.canonicalUUIDString {
            preferenceStore.set(canonical, forKey: nearbyPresenceUserIdKey)
            return canonical
        }

        if let existing = preferenceStore.string(forKey: nearbyPresenceUserIdKey),
           let canonical = existing.canonicalUUIDString {
            return canonical
        }

        if let profileUserId = userSessionStore.currentUserInfo()?.id,
           let canonical = profileUserId.canonicalUUIDString {
            preferenceStore.set(canonical, forKey: nearbyPresenceUserIdKey)
            return canonical
        }

        preferenceStore.removeObject(forKey: nearbyPresenceUserIdKey)
        return nil
    }

    private func currentMetricUserId() -> String? {
        guard let raw = userSessionStore.currentUserInfo()?.id, raw.isEmpty == false else {
            return nil
        }
        return raw
    }

    /// 위젯에서 전달된 산책 액션 딥링크를 적용합니다.
    /// - Parameter route: 위젯 액션 종류/중복 방지 식별자를 담은 라우트입니다.
    func applyWidgetWalkAction(_ route: WalkWidgetActionRoute) {
        guard shouldProcessWidgetAction(actionId: route.actionId) else {
            metricTracker.track(
                .widgetActionDuplicate,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            return
        }

        switch route.kind {
        case .startWalk:
            guard isWalking == false else {
                walkStatusMessage = "이미 산책이 진행 중입니다."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "already_walking"]
                )
                syncWalkWidgetSnapshot(force: true, statusOverride: .sessionConflict, messageOverride: walkStatusMessage)
                return
            }
            guard isLocationPermissionDenied == false else {
                walkStatusMessage = "위치 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "location_denied"]
                )
                syncWalkWidgetSnapshot(force: true, statusOverride: .locationDenied, messageOverride: walkStatusMessage)
                return
            }
            startWalkNow()
            walkStatusMessage = "위젯에서 산책을 시작했어요."
            metricTracker.track(
                .widgetActionApplied,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            syncWalkWidgetSnapshot(force: true)
            syncWalkLiveActivity(force: true)

        case .endWalk:
            guard isWalking else {
                walkStatusMessage = "종료할 산책 세션이 없습니다."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "no_active_session"]
                )
                syncWalkWidgetSnapshot(force: true, statusOverride: .sessionConflict, messageOverride: walkStatusMessage)
                return
            }
            endWalk()
            walkStatusMessage = "위젯에서 산책을 종료했어요."
            metricTracker.track(
                .widgetActionApplied,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            syncWalkWidgetSnapshot(force: true)
            syncWalkLiveActivity(force: true)

        case .claimQuestReward, .openRivalTab:
            metricTracker.track(
                .widgetActionRejected,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "reason": "unsupported_on_map"]
            )
        }
    }

    /// 중복 위젯 액션 식별자를 검사하고 최신 식별자를 저장합니다.
    /// - Parameter actionId: 위젯 액션 요청 ID입니다.
    /// - Returns: 처음 처리하는 요청이면 `true`, 중복 요청이면 `false`입니다.
    private func shouldProcessWidgetAction(actionId: String) -> Bool {
        let normalized = actionId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            return true
        }
        guard normalized != lastAppliedWidgetActionId else {
            return false
        }
        lastAppliedWidgetActionId = normalized
        preferenceStore.set(normalized, forKey: lastWidgetActionIdKey)
        return true
    }

    /// 현재 산책 상태를 위젯 공유 스냅샷으로 동기화합니다.
    /// - Parameters:
    ///   - force: `true`면 최소 간격 제한 없이 즉시 저장합니다.
    ///   - statusOverride: 상태를 강제로 지정할 때 사용하는 값입니다.
    ///   - messageOverride: 상태 메시지를 강제로 지정할 때 사용하는 값입니다.
    private func syncWalkWidgetSnapshot(
        force: Bool = false,
        statusOverride: WalkWidgetSnapshotStatus? = nil,
        messageOverride: String? = nil
    ) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastWidgetSnapshotSyncAt) < widgetSnapshotSyncInterval {
            return
        }

        let snapshot = WalkWidgetSnapshot(
            isWalking: isWalking,
            elapsedSeconds: Int(max(0, time.rounded(.down))),
            petName: currentWalkingPetName,
            status: statusOverride ?? (isLocationPermissionDenied ? .locationDenied : .ready),
            statusMessage: messageOverride,
            updatedAt: now.timeIntervalSince1970
        )
        widgetSnapshotStore.save(snapshot)
        lastWidgetSnapshotSyncAt = now
    }

    /// 현재 자동 종료 정책 기준으로 Live Activity 단계 값을 계산합니다.
    /// - Parameter now: 단계 계산 기준 시각입니다.
    /// - Returns: 무이동 정책(5/12/15분)에 매핑된 단계 값입니다.
    private func currentAutoEndStage(now: Date = Date()) -> WalkLiveActivityAutoEndStage {
        guard isWalking else { return .ended }
        let baseline = lastMovementAt ?? lastPointEventAt ?? startTime
        let inactivity = max(0, now.timeIntervalSince(baseline))
        if inactivity >= inactivityFinalizeInterval { return .autoEnding }
        if inactivity >= inactivityWarningInterval { return .warning }
        if inactivity >= restCandidateInterval { return .restCandidate }
        return .active
    }

    /// 현재 ViewModel 상태를 Live Activity 서비스용 상태 모델로 변환합니다.
    /// - Parameter now: 상태 스냅샷 기준 시각입니다.
    /// - Returns: 세션 식별자/경과시간/포인트/자동종료 단계를 포함한 상태입니다.
    private func makeWalkLiveActivityState(now: Date = Date()) -> WalkLiveActivityState {
        WalkLiveActivityState(
            sessionId: polygon.id.uuidString.lowercased(),
            startedAt: startTime.timeIntervalSince1970,
            isWalking: isWalking,
            elapsedSeconds: Int(max(0, time.rounded(.down))),
            pointCount: polygon.locations.count,
            petName: currentWalkingPetName,
            autoEndStage: currentAutoEndStage(now: now),
            statusMessage: walkStatusMessage,
            updatedAt: now.timeIntervalSince1970
        )
    }

    /// Live Activity/대체 알림 상태를 주기적으로 동기화합니다.
    /// - Parameter force: `true`면 최소 간격 제한 없이 즉시 동기화합니다.
    private func syncWalkLiveActivity(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastLiveActivitySyncAt) < liveActivitySyncInterval {
            return
        }
        guard liveActivitySyncTask == nil else { return }
        let state = makeWalkLiveActivityState(now: now)
        lastLiveActivitySyncAt = now

        liveActivitySyncTask = Task { [weak self] in
            guard let self else { return }
            let result: WalkLiveActivityServiceResult
            if state.isWalking {
                result = await liveActivityService.sync(state: state)
            } else {
                result = await liveActivityService.end(state: state, dismissImmediately: false)
            }
            await MainActor.run {
                self.applyWalkLiveActivityResult(result)
                self.liveActivitySyncTask = nil
            }
        }
    }

    /// Live Activity 동기화 결과를 배너 메시지 상태에 반영합니다.
    /// - Parameter result: Live Activity 서비스 처리 결과입니다.
    private func applyWalkLiveActivityResult(_ result: WalkLiveActivityServiceResult) {
        switch result {
        case .liveActivity, .ended:
            lastLiveActivityFallbackReason = nil
        case let .fallback(reason):
            guard lastLiveActivityFallbackReason != reason else { return }
            lastLiveActivityFallbackReason = reason
            switch reason {
            case .unsupportedOS:
                walkStatusMessage = "Live Activity 미지원 환경이라 일반 알림으로 대체합니다."
            case .activitiesDisabled:
                walkStatusMessage = "Live Activity가 비활성화되어 일반 알림 + 앱 배너로 안내합니다."
            case .requestFailed:
                walkStatusMessage = "Live Activity 생성에 실패해 일반 알림으로 대체했습니다."
            }
        }
    }

    func reloadSelectedPetContext() {
        let userInfo = userSessionStore.currentUserInfo()
        self.availablePets = userInfo?.pet ?? []
        let selectedPet = userSessionStore.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId
        self.selectedPetName = selectedPet?.petName ?? "강아지"
        if isWalking == false {
            self.currentWalkingPetName = self.selectedPetName
        }
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
    }

    var hasSelectedPet: Bool {
        selectedPetId != nil
    }

    func prepareWalkPetSelectionSuggestion() {
        guard isWalking == false else { return }
        guard let userInfo = userSessionStore.currentUserInfo(), userInfo.pet.isEmpty == false else {
            reloadSelectedPetContext()
            return
        }
        if let suggested = userSessionStore.suggestedPetForWalkStart(from: userInfo, now: Date()),
           suggested.petId != selectedPetId {
            userSessionStore.setSelectedPetId(suggested.petId, source: "walk_start_suggestion")
            metricTracker.track(
                .petSelectionSuggested,
                userKey: currentMetricUserId(),
                payload: [
                    "petId": suggested.petId,
                    "petName": suggested.petName
                ]
            )
            walkStatusMessage = "\(suggested.petName)을(를) 산책 대상으로 제안했어요."
        }
        reloadSelectedPetContext()
    }

    func cycleSelectedPetForWalkStart() {
        guard isWalking == false else { return }
        guard availablePets.count > 1 else { return }

        let currentIndex = availablePets.firstIndex(where: { $0.petId == selectedPetId }) ?? -1
        let nextIndex = (currentIndex + 1) % availablePets.count
        let nextPet = availablePets[nextIndex]
        userSessionStore.setSelectedPetId(nextPet.petId, source: "walk_start_switcher")
        walkStatusMessage = "산책 대상: \(nextPet.petName)"
        reloadSelectedPetContext()
    }

    private func setupWatchConnectivity() {
        guard let watchSession else { return }
        watchSession.delegate = self
        watchSession.activate()
        self.syncWatchContext(force: true)
    }

    private func syncWatchContext(force: Bool = false) {
        if Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.syncWatchContext(force: force)
            }
            return
        }
        guard let watchSession, watchSession.activationState == .activated else { return }
        #if os(iOS)
        guard watchSession.isWatchAppInstalled else {
            if watchSyncStatusText != "워치 앱 미설치" {
                watchSyncStatusText = "워치 앱 미설치"
            }
            return
        }
        #endif

        let now = Date()
        if force == false, now.timeIntervalSince(lastWatchContextSyncAt) < 1.0 {
            return
        }

        let context: [String: Any] = [
            "version": WatchContract.version,
            "type": "watch_state",
            "isWalking": self.isWalking,
            "time": self.time,
            "area": self.polygon.walkingArea,
            "last_sync_at": now.timeIntervalSince1970,
            "watch_status": self.watchSyncStatusText,
            "last_action_id_applied": self.lastAppliedWatchActionId
        ]

        do {
            try watchSession.updateApplicationContext(context)
            self.lastWatchContextSyncAt = now
            self.watchSyncStatusText = "워치 동기화 \(Self.statusTimeString(from: now))"
        } catch {
            self.watchSyncStatusText = "워치 동기화 실패"
            print("watch context update failed: \(error.localizedDescription)")
        }
    }

    private func loadProcessedWatchActions() {
        let stored = preferenceStore.stringArray(forKey: processedWatchActionStorageKey)
        self.processedWatchActionOrder = stored
        self.processedWatchActionIds = Set(stored)
    }

    private func persistProcessedWatchActions() {
        preferenceStore.set(self.processedWatchActionOrder, forKey: processedWatchActionStorageKey)
    }

    private func shouldProcessWatchAction(actionId: String) -> Bool {
        guard processedWatchActionIds.contains(actionId) == false else {
            return false
        }
        processedWatchActionIds.insert(actionId)
        processedWatchActionOrder.append(actionId)
        if processedWatchActionOrder.count > maxProcessedWatchActions {
            let overflow = processedWatchActionOrder.count - maxProcessedWatchActions
            let removed = Array(processedWatchActionOrder.prefix(overflow))
            processedWatchActionOrder.removeFirst(overflow)
            removed.forEach { processedWatchActionIds.remove($0) }
        }
        persistProcessedWatchActions()
        return true
    }

    @discardableResult
    private func handleWatchPayload(_ payload: [String: Any]) -> [String: Any]? {
        if Thread.isMainThread == false {
            return DispatchQueue.main.sync { [weak self] in
                self?.handleWatchPayload(payload)
            }
        }
        guard let envelope = parseWatchEnvelope(from: payload) else { return nil }
        let actionName = envelope.action.rawValue
        let sentAtLabel: String = {
            guard let sentAt = envelope.sentAt else { return "" }
            return " sent:\(Int(sentAt))"
        }()
        latestWatchActionText = "워치 \(actionName) 수신 \(Self.statusTimeString(from: Date()))"
        metricTracker.track(
            .watchActionReceived,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "version": envelope.version + sentAtLabel
            ]
        )
        if shouldProcessWatchAction(actionId: envelope.actionId) == false {
            metricTracker.track(
                .watchActionDuplicate,
                userKey: currentMetricUserId(),
                payload: [
                    "action": actionName,
                    "actionId": envelope.actionId
                ]
            )
            return [
                "version": WatchContract.version,
                "type": WatchContract.ackType,
                "status": "duplicate",
                "action": actionName,
                "action_id": envelope.actionId,
                "last_sync_at": Date().timeIntervalSince1970
            ]
        }
        metricTracker.track(
            .watchActionProcessed,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "actionId": envelope.actionId
            ]
        )
        self.applyWatchAction(envelope)
        return [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "accepted",
            "action": actionName,
            "action_id": envelope.actionId,
            "last_sync_at": Date().timeIntervalSince1970
        ]
    }

    private func parseWatchEnvelope(from payload: [String: Any]) -> WatchActionEnvelope? {
        let version = (payload["version"] as? String) ?? "watch.legacy.v0"
        if let type = payload["type"] as? String,
           type.isEmpty == false,
           type != WatchContract.actionType {
            return nil
        }
        let nestedPayload = payload["payload"] as? [String: Any]
        let actionPayload = nestedPayload ?? payload

        guard let rawAction = (actionPayload["action"] as? String) ?? (payload["action"] as? String),
              let action = WatchIncomingAction(rawValue: rawAction) else {
            return nil
        }
        let actionId: String = {
            if let id = (actionPayload["action_id"] as? String) ?? (payload["action_id"] as? String),
               id.isEmpty == false {
                return id
            }
            if let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval) {
                return "\(rawAction):\(Int(sentAt * 1000.0))"
            }
            return UUID().uuidString.lowercased()
        }()
        let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval)
        return WatchActionEnvelope(version: version, action: action, actionId: actionId, sentAt: sentAt)
    }

    private func applyWatchAction(_ envelope: WatchActionEnvelope) {
        let action = envelope.action
        switch action {
        case .startWalk:
            if self.isWalking == false {
                self.startWalkNow()
                self.latestWatchActionText = "워치 시작 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .addPoint:
            if self.isWalking {
                if let location = self.location {
                    self.appendWalkPoint(from: location, recordedAt: Date(), source: .watch)
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
                }
            }
        case .endWalk:
            if self.isWalking {
                self.endWalk()
                self.latestWatchActionText = "워치 종료 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .syncState:
            self.latestWatchActionText = "워치 상태 재동기화 \(Self.statusTimeString(from: Date()))"
        }
        self.lastAppliedWatchActionId = envelope.actionId
        self.syncWatchContext(force: true)
    }

}
//MARK: - 넓이와 시간로직
extension MapViewModel {
    func timerSet() {
        timerStop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] _ in
            guard let self = self else {return}
            guard self.isWalking else { return }
            self.time = max(0, Date().timeIntervalSince(self.startTime))
            self.persistActiveWalkSession()
            self.syncWatchContext()
            self.syncWalkWidgetSnapshot()
            self.syncWalkLiveActivity()
            if self.time >= self.walkAutoTimeoutInterval {
                self.forceQuit()
                return
            }
            self.handleAutoEndIfNeeded()
        }
    }
    func timerStop() {
        timer?.invalidate()
        timer = nil
    }
    func calculateArea() -> Double {
        let points = self.polygon.locations
        return calculateArea(points: points)
    }

    func calculateArea(points: [Location]) -> Double {
        areaCalculationService.calculateArea(points: points)
    }
    func calculatedAreaString(areaSize: Double? = nil , isPyong: Bool = false) -> String {
        let area = areaSize ?? calculateArea()
        return areaCalculationService.formattedAreaString(area: area, isPyong: isPyong)
    }
}
//MARK: - CLLocation 관련 로직
extension MapViewModel {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MapCoreLocationCallTracer.record(
            "locationManagerDidChangeAuthorization",
            detail: "status=\(manager.authorizationStatus.rawValue)"
        )
        switch manager.authorizationStatus {
        case .notDetermined:
            stopLocationUpdatesIfNeeded()
            syncWalkWidgetSnapshot(force: true)
            syncWalkLiveActivity(force: true)
        case .restricted, .denied:
            pauseWalkForAuthorizationDowngrade()
            stopLocationUpdatesIfNeeded()
            syncWalkWidgetSnapshot(force: true, statusOverride: .locationDenied)
            syncWalkLiveActivity(force: true)
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationUpdatesIfAuthorized()
            if isWalking {
                syncWatchContext(force: true)
            }
            refreshWeatherRiskFromProviderIfNeeded(location: manager.location, force: true)
            syncWalkWidgetSnapshot(force: true)
            syncWalkLiveActivity(force: true)
            
        @unknown default:
            stopLocationUpdatesIfNeeded()
            syncWalkWidgetSnapshot(force: true, statusOverride: .error, messageOverride: "위치 권한 상태를 확인해주세요.")
            syncWalkLiveActivity(force: true)
        }
    }
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
//        print(manager.location?.description)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MapCoreLocationCallTracer.record(
            "didUpdateLocations",
            detail: "count=\(locations.count)"
        )
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isWalking {
                guard self.validateWalkLocationSample(location) else { return }
                self.updateMovementState(with: location)
            }
            self.location = location
            self.handleAutoPointRecord(with: location)
            let now = Date()
            if now.timeIntervalSince(self.lastLocationSideEffectAt) >= self.locationSideEffectInterval {
                self.lastLocationSideEffectAt = now
                self.refreshWeatherRiskFromProviderIfNeeded(location: location, force: false)
                self.persistActiveWalkSession()
                self.handleAutoEndIfNeeded(now: now)
                if self.isMapViewActive {
                    self.flushSyncOutboxIfNeeded()
                }
            }
        }
    }

    /// 위치 객체를 기준으로 지도의 중심/축척을 설정합니다.
    /// - Parameters:
    ///   - location: 중심으로 이동할 위치 객체입니다.
    ///   - distance: 카메라 거리(미터)입니다.
    ///   - reason: 카메라 변경 원인 로그에 사용할 선택값입니다.
    func setRegion(_ location : CLLocation?, distance: Double = 2000, reason: CameraChangeReason? = nil){
        guard let coordinate=location?.coordinate else {return}
        if let reason {
            markPendingCameraChangeReason(reason)
        }
        withAnimation(.easeInOut(duration: 0.3)){
            cameraPosition = MapCameraPosition.camera(.init(centerCoordinate: coordinate, distance: distance))
        }
    }
    /// 좌표를 기준으로 지도의 중심/축척을 설정합니다.
    /// - Parameters:
    ///   - coordination: 중심으로 이동할 좌표입니다.
    ///   - distance: 카메라 거리(미터)입니다.
    ///   - reason: 카메라 변경 원인 로그에 사용할 선택값입니다.
    func setRegion(_ coordination : CLLocationCoordinate2D?, distance: Double = 2000, reason: CameraChangeReason? = nil){
        guard let coordinate=coordination else {return}
        if let reason {
            markPendingCameraChangeReason(reason)
        }
        withAnimation(.easeInOut(duration: 0.3)){
            cameraPosition = MapCameraPosition.camera(.init(centerCoordinate: coordinate, distance: distance))
        }
    }
}
//MARK: - 클러스터링 관련 내용
extension MapViewModel {
    func updateAnnotations(cameraDistance: Double){
        let safeDistance = max(120.0, cameraDistance)
        let previousCount = centerLocations.count
        currentCameraDistance = safeDistance
        let nextClusters = cluster(distance: safeDistance)
        centerLocations = nextClusters

        let nextCount = nextClusters.count
        if nextCount > previousCount {
            clusterMotionTransition = .decompose
            clusterMotionToken += 1
        } else if nextCount < previousCount {
            clusterMotionTransition = .merge
            clusterMotionToken += 1
        } else {
            clusterMotionTransition = .none
        }
    }
    private func hotspots() async { // 핫스팟 로직 고민해보기

    }

    private func cluster(distance: Double) -> [Cluster] {
        clusterAnnotationService.cluster(
            polygons: polygonList,
            cameraDistance: distance,
            distanceRatio: clusterCellDistanceRatio,
            minCellMeters: clusterCellMinMeters,
            maxCellMeters: clusterCellMaxMeters
        )
    }
}

// MARK: - WatchConnectivity
extension MapViewModel {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error {
                print("watch activation failed: \(error.localizedDescription)")
                return
            }
            self.syncWatchContext(force: true)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.syncWatchContext(force: true)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        let ack = self.handleWatchPayload(message) ?? [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "ignored",
            "last_sync_at": Date().timeIntervalSince1970
        ]
        replyHandler(ack)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleWatchPayload(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        self.handleWatchPayload(userInfo)
    }
}
