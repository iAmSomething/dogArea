import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

#if DEBUG
enum RivalCoreLocationCallTracer {
    private static let lock = NSLock()
    private static var eventCounts: [String: Int] = [:]
    private static var windowStartedAt: Date = Date()
    private static var heartbeatTimer: DispatchSourceTimer?
    private static var isHeartbeatStarted: Bool = false
    private static var consecutiveIdleWindows: Int = 0
    private static let idleWindowStopThreshold: Int = 30

    /// 라이벌 탭의 CoreLocation API 호출 이벤트를 1초 단위로 집계해 디버그 콘솔에 출력합니다.
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
        startHeartbeatIfNeeded()
        var occurrenceCount = 0

        lock.lock()
        eventCounts[event, default: 0] += 1
        occurrenceCount = eventCounts[event, default: 0]
        lock.unlock()

        if occurrenceCount <= 2 {
            if let detail, detail.isEmpty == false {
                print("[CoreLocationTrace][Rival] \(event) @\(file):\(line) detail=\(detail)")
            } else {
                print("[CoreLocationTrace][Rival] \(event) @\(file):\(line)")
            }
        }

    }

    /// 트레이서가 활성화되면 1초 주기로 호출 집계를 출력하는 하트비트를 시작합니다.
    private static func startHeartbeatIfNeeded() {
        lock.lock()
        if isHeartbeatStarted {
            lock.unlock()
            return
        }
        isHeartbeatStarted = true
        consecutiveIdleWindows = 0
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler {
            flushWindowSummary()
        }
        heartbeatTimer = timer
        lock.unlock()
        timer.resume()
    }

    /// 최근 1초 구간의 이벤트 집계를 콘솔에 출력하고 카운터를 초기화합니다.
    private static func flushWindowSummary() {
        lock.lock()
        let now = Date()
        let elapsed = now.timeIntervalSince(windowStartedAt)
        let snapshot = eventCounts
        eventCounts.removeAll()
        windowStartedAt = now

        if snapshot.isEmpty {
            consecutiveIdleWindows += 1
        } else {
            consecutiveIdleWindows = 0
        }

        let shouldStopHeartbeat = consecutiveIdleWindows >= idleWindowStopThreshold
        let timerToCancel = shouldStopHeartbeat ? heartbeatTimer : nil
        if shouldStopHeartbeat {
            heartbeatTimer = nil
            isHeartbeatStarted = false
            consecutiveIdleWindows = 0
        }
        lock.unlock()

        if shouldStopHeartbeat {
            timerToCancel?.cancel()
        }

        guard elapsed >= 0.95 else { return }
        guard snapshot.isEmpty == false else { return }
        let summary = snapshot
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        print("[CoreLocationTrace][Rival][1s] \(summary)")
    }
}
#else
enum RivalCoreLocationCallTracer {
    /// Release 빌드에서는 CoreLocation 추적 오버헤드를 제거하기 위해 no-op으로 동작합니다.
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
        _ = event
        _ = detail
        _ = file
        _ = line
    }
}
#endif

@MainActor
@preconcurrency
final class RivalTabViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct HotspotPreviewRow {
        let title: String
        let value: String
    }

    enum PermissionState {
        case notDetermined
        case authorized
        case denied
    }

    enum ScreenState {
        case guestLocked
        case permissionRequired
        case consentRequired
        case loading
        case ready
        case empty
        case offlineCached
        case offlineEmpty
        case errorRetryable
    }

    enum LeaderboardState {
        case guestLocked
        case permissionRequired
        case consentRequired
        case friendPreview
        case loading
        case ready
        case empty
        case errorRetryable
    }

    @Published var permissionState: PermissionState = .notDetermined
    @Published var screenState: ScreenState = .guestLocked
    @Published var leaderboardState: LeaderboardState = .guestLocked
    @Published var locationSharingEnabled: Bool = false
    @Published var hotspots: [NearbyHotspotDTO] = []
    @Published var leaderboardEntries: [RivalLeaderboardEntryDTO] = []
    @Published var hiddenAliases: [String] = []
    @Published var blockedAliases: [String] = []
    @Published var hotspotPreviewRows: [HotspotPreviewRow] = []
    @Published var isSharingInFlight: Bool = false
    @Published var isHotspotRefreshing: Bool = false
    @Published var isLeaderboardRefreshing: Bool = false
    @Published var lastUpdatedText: String = "-"
    @Published var maxIntensityText: String = "없음"
    @Published var compareScope: RivalCompareScope = .rival
    @Published var leaderboardPeriod: RivalLeaderboardPeriod = .week
    @Published var toastMessage: String? = nil

    let nearbyService: NearbyPresenceServiceProtocol
    let rivalLeagueService: RivalLeagueServiceProtocol
    let preferenceStore: MapPreferenceStoreProtocol
    let moderationStore: RivalModerationStoreProtocol
    let locationManager: CLLocationManager
    let authSessionStore: AuthSessionStoreProtocol
    let sessionProvider: () -> AppSessionState
    let metricTracker: AppMetricTracker
    let locationSharingKeyPrefix = "nearby.locationSharingEnabled.v1"
    let locationSharingLegacyGlobalKey = "nearby.locationSharingEnabled.v1"
    let locationSharingPolicyInitializedKeyPrefix = "nearby.locationSharingPolicyInitialized.v1"
    let visibilityOffPropagationDeadline: TimeInterval = 30
    let visibilityOffRetryInterval: TimeInterval = 10
    let visibilityOffMaxRetries: Int = 3
    let hotspotMinimumRefreshInterval: TimeInterval = 10
    let leaderboardMinimumRefreshInterval: TimeInterval = 10
    let hotspotFailureBackoffBaseInterval: TimeInterval = 10
    let hotspotFailureBackoffMaxInterval: TimeInterval = 120
    var pollingTimer: Timer? = nil
    var authSessionObserver: NSObjectProtocol? = nil
    var lastRefreshAt: Date = .distantPast
    var lastLeaderboardRefreshAt: Date = .distantPast
    var hotspotFailureRetryAt: Date = .distantPast
    var hotspotFailureStreak: Int = 0
    var latestRawLeaderboardEntries: [RivalLeaderboardEntryDTO] = []

    /// 라이벌 탭 상태를 제어하는 뷰모델을 초기화합니다.
    init(
        nearbyService: NearbyPresenceServiceProtocol = NearbyPresenceService(),
        rivalLeagueService: RivalLeagueServiceProtocol = RivalLeagueService(),
        preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared,
        moderationStore: RivalModerationStoreProtocol? = nil,
        locationManager: CLLocationManager = CLLocationManager(),
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        sessionProvider: @escaping () -> AppSessionState = { AppFeatureGate.currentSession() },
        metricTracker: AppMetricTracker = .shared
    ) {
        self.nearbyService = nearbyService
        self.rivalLeagueService = rivalLeagueService
        self.preferenceStore = preferenceStore
        self.moderationStore = moderationStore ?? RivalModerationStore(preferenceStore: preferenceStore)
        self.locationManager = locationManager
        self.authSessionStore = authSessionStore
        self.sessionProvider = sessionProvider
        self.metricTracker = metricTracker
        super.init()
    }

    deinit {
        pollingTimer?.invalidate()
        if let authSessionObserver {
            NotificationCenter.default.removeObserver(authSessionObserver)
        }
    }
}
