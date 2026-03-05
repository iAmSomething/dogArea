import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

private enum RivalCoreLocationCallTracer {
    private static let lock = NSLock()
    private static var eventCounts: [String: Int] = [:]
    private static var windowStartedAt: Date = Date()
    private static var heartbeatTimer: DispatchSourceTimer?
    private static var isHeartbeatStarted: Bool = false

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
        let summary = eventCounts
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        eventCounts.removeAll()
        windowStartedAt = now
        lock.unlock()

        guard elapsed >= 0.95 else { return }
        if summary.isEmpty {
            print("[CoreLocationTrace][Rival][1s] idle")
        } else {
            print("[CoreLocationTrace][Rival][1s] \(summary)")
        }
    }
}

@MainActor
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

    @Published private(set) var permissionState: PermissionState = .notDetermined
    @Published private(set) var screenState: ScreenState = .guestLocked
    @Published private(set) var leaderboardState: LeaderboardState = .guestLocked
    @Published private(set) var locationSharingEnabled: Bool = false
    @Published private(set) var hotspots: [NearbyHotspotDTO] = []
    @Published private(set) var leaderboardEntries: [RivalLeaderboardEntryDTO] = []
    @Published private(set) var hiddenAliases: [String] = []
    @Published private(set) var blockedAliases: [String] = []
    @Published private(set) var hotspotPreviewRows: [HotspotPreviewRow] = []
    @Published private(set) var isSharingInFlight: Bool = false
    @Published private(set) var isHotspotRefreshing: Bool = false
    @Published private(set) var isLeaderboardRefreshing: Bool = false
    @Published private(set) var lastUpdatedText: String = "-"
    @Published private(set) var maxIntensityText: String = "없음"
    @Published private(set) var compareScope: RivalCompareScope = .rival
    @Published private(set) var leaderboardPeriod: RivalLeaderboardPeriod = .week
    @Published var toastMessage: String? = nil

    private let nearbyService: NearbyPresenceServiceProtocol
    private let rivalLeagueService: RivalLeagueServiceProtocol
    private let preferenceStore: MapPreferenceStoreProtocol
    private let moderationStore: RivalModerationStoreProtocol
    private let locationManager: CLLocationManager
    private let authSessionStore: AuthSessionStoreProtocol
    private let sessionProvider: () -> AppSessionState
    private let metricTracker: AppMetricTracker
    private let locationSharingKeyPrefix = "nearby.locationSharingEnabled.v1"
    private let locationSharingLegacyGlobalKey = "nearby.locationSharingEnabled.v1"
    private let locationSharingPolicyInitializedKeyPrefix = "nearby.locationSharingPolicyInitialized.v1"
    private let visibilityOffPropagationDeadline: TimeInterval = 30
    private let visibilityOffRetryInterval: TimeInterval = 10
    private let visibilityOffMaxRetries: Int = 3
    private var pollingTimer: Timer? = nil
    private var authSessionObserver: NSObjectProtocol? = nil
    private var lastRefreshAt: Date = .distantPast
    private var lastLeaderboardRefreshAt: Date = .distantPast
    private var latestRawLeaderboardEntries: [RivalLeaderboardEntryDTO] = []

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

    /// 탭 진입 시 권한/공유 상태를 불러오고 폴링을 시작합니다.
    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        startAuthSessionObserverIfNeeded()
        RivalCoreLocationCallTracer.record(
            "authorizationStatus.read",
            detail: "source=start status=\(locationManager.authorizationStatus.rawValue)"
        )
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            RivalCoreLocationCallTracer.record(
                "startUpdatingLocation",
                detail: "source=start"
            )
            locationManager.startUpdatingLocation()
        default:
            RivalCoreLocationCallTracer.record(
                "stopUpdatingLocation",
                detail: "source=start"
            )
            locationManager.stopUpdatingLocation()
        }
        loadModerationPreferences()
        refreshSessionContext()
        startPollingIfNeeded()
    }

    /// 탭 이탈 시 폴링/위치 업데이트를 중단합니다.
    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stopAuthSessionObserver()
        RivalCoreLocationCallTracer.record(
            "stopUpdatingLocation",
            detail: "source=stop"
        )
        locationManager.stopUpdatingLocation()
    }

    /// 로그인/로그아웃 직후 세션 컨텍스트를 다시 읽고 UI 상태를 즉시 갱신합니다.
    func refreshSessionContext() {
        locationSharingEnabled = loadLocationSharingPreference(for: currentUserId)
        loadModerationPreferences()
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 위치 권한 요청을 수행합니다.
    func requestLocationPermission() {
        RivalCoreLocationCallTracer.record(
            "requestWhenInUseAuthorization",
            detail: "source=requestLocationPermission"
        )
        locationManager.requestWhenInUseAuthorization()
    }

    /// 동의 시트 완료 후 익명 공유를 활성화합니다.
    func enableSharingWithConsent() {
        guard let userId = currentUserId else {
            showToast("회원 전용 기능입니다. 로그인 후 다시 시도해주세요.")
            refreshViewState()
            return
        }

        isSharingInFlight = true
        Task {
            defer { isSharingInFlight = false }
            do {
                try await nearbyService.setVisibility(userId: userId, enabled: true)
                persistLocationSharingPreference(true, for: userId)
                locationSharingEnabled = true
                metricTracker.track(
                    .rivalPrivacyOptInCompleted,
                    userKey: userId,
                    featureKey: .nearbyHotspotV1,
                    payload: ["source": "consent_sheet"]
                )
                showToast("익명 공유가 시작됐어요")
                refreshViewState()
                refreshHotspots(force: true)
                refreshLeaderboard(force: true)
            } catch {
                if handleAuthFailureIfNeeded(error) {
                    return
                }
                persistLocationSharingPreference(false, for: userId)
                locationSharingEnabled = false
                refreshViewState()
                showToast(RivalNetworkErrorInterpreter.visibilityFailureMessage(from: error))
            }
        }
    }

    /// 익명 공유를 비활성화하고 핫스팟을 초기화합니다.
    func disableSharing() {
        guard let userId = currentUserId else {
            persistLocationSharingPreference(false, for: nil)
            locationSharingEnabled = false
            hotspots = []
            refreshViewState()
            return
        }

        isSharingInFlight = true
        persistLocationSharingPreference(false, for: userId)
        locationSharingEnabled = false
        hotspots = []
        leaderboardEntries = []
        latestRawLeaderboardEntries = []
        refreshViewState()
        showToast("익명 공유를 중지했어요")

        Task {
            defer { isSharingInFlight = false }
            await syncVisibilityOffWithRetry(userId: userId, startedAt: Date(), attempt: 0)
        }
    }

    /// 핫스팟을 새로 조회하고 카드 상태를 갱신합니다.
    func refreshHotspots(force: Bool = false) {
        guard screenState != .guestLocked else { return }
        guard permissionState == .authorized else {
            refreshViewState()
            return
        }
        guard locationSharingEnabled else {
            refreshViewState()
            return
        }
        guard let coordinate = locationManager.location?.coordinate else {
            screenState = hotspots.isEmpty ? .empty : .ready
            return
        }

        if force == false && Date().timeIntervalSince(lastRefreshAt) < 1.0 {
            return
        }

        isHotspotRefreshing = true
        if hotspots.isEmpty {
            screenState = .loading
        }
        let userId = currentUserId
        Task {
            defer { isHotspotRefreshing = false }
            do {
                let fetched = try await nearbyService.getHotspots(
                    userId: userId,
                    centerLatitude: coordinate.latitude,
                    centerLongitude: coordinate.longitude,
                    radiusKm: 1.0
                )
                let maxIntensity = fetched.map(\.intensity).max() ?? 0
                metricTracker.track(
                    .rivalHotspotFetchSucceeded,
                    userKey: userId,
                    featureKey: .nearbyHotspotV1,
                    eventValue: Double(fetched.count),
                    payload: [
                        "cell_count": "\(fetched.count)",
                        "max_intensity": String(format: "%.4f", maxIntensity)
                    ]
                )
                hotspots = fetched
                lastRefreshAt = Date()
                updateHotspotSummary()
                if fetched.isEmpty {
                    screenState = .empty
                } else {
                    screenState = .ready
                }
            } catch {
                let metricErrorCode: String
                if let supabaseError = error as? SupabaseHTTPError,
                   case .unexpectedStatusCode(let statusCode) = supabaseError {
                    metricErrorCode = "http_\(statusCode)"
                } else if error is URLError {
                    metricErrorCode = "network"
                } else {
                    metricErrorCode = "unknown"
                }
                metricTracker.track(
                    .rivalHotspotFetchFailed,
                    userKey: userId,
                    featureKey: .nearbyHotspotV1,
                    payload: [
                        "error_code": metricErrorCode,
                        "retryable": RivalNetworkErrorInterpreter.isConnectivityError(error) ? "true" : "false"
                    ]
                )
                if handleAuthFailureIfNeeded(error) {
                    return
                }
                if let supabaseError = error as? SupabaseHTTPError,
                   case .unexpectedStatusCode(404) = supabaseError {
                    hotspots = []
                    updateHotspotSummary()
                    screenState = .empty
                } else if RivalNetworkErrorInterpreter.isConnectivityError(error) {
                    screenState = hotspots.isEmpty ? .offlineEmpty : .offlineCached
                } else {
                    screenState = .errorRetryable
                }
            }
        }
    }

    /// 리더보드의 비교 범위를 전환합니다.
    func setCompareScope(_ scope: RivalCompareScope) {
        compareScope = scope
        refreshLeaderboard(force: true)
    }

    /// 리더보드의 비교 기간(주간/시즌)을 전환합니다.
    func setLeaderboardPeriod(_ period: RivalLeaderboardPeriod) {
        leaderboardPeriod = period
        refreshLeaderboard(force: true)
    }

    /// 익명 리더보드를 조회하고 숨김/차단 필터를 적용합니다.
    func refreshLeaderboard(force: Bool = false) {
        guard compareScope == .rival else {
            leaderboardState = .friendPreview
            leaderboardEntries = []
            return
        }
        guard currentUserId != nil else {
            leaderboardState = .guestLocked
            leaderboardEntries = []
            return
        }
        guard permissionState == .authorized else {
            leaderboardState = .permissionRequired
            leaderboardEntries = []
            return
        }
        guard locationSharingEnabled else {
            leaderboardState = .consentRequired
            leaderboardEntries = []
            return
        }
        if force == false && Date().timeIntervalSince(lastLeaderboardRefreshAt) < 1.0 {
            return
        }

        isLeaderboardRefreshing = true
        if leaderboardEntries.isEmpty {
            leaderboardState = .loading
        }
        Task {
            defer { isLeaderboardRefreshing = false }
            do {
                let rows = try await rivalLeagueService.fetchLeaderboard(period: leaderboardPeriod, topN: 20)
                metricTracker.track(
                    .rivalLeaderboardFetched,
                    userKey: currentUserId,
                    featureKey: .nearbyHotspotV1,
                    eventValue: Double(rows.count),
                    payload: [
                        "period": leaderboardPeriod.rawValue,
                        "row_count": "\(rows.count)"
                    ]
                )
                latestRawLeaderboardEntries = rows
                lastLeaderboardRefreshAt = Date()
                applyLeaderboardModerationFilter()
            } catch {
                if handleAuthFailureIfNeeded(error) {
                    return
                }
                leaderboardState = .errorRetryable
            }
        }
    }

    /// 익명 코드 숨김을 적용하고 즉시 목록에서 제거합니다.
    func hideAlias(aliasCode: String) {
        var next = Set(hiddenAliases)
        next.insert(aliasCode)
        hiddenAliases = next.sorted()
        persistModerationPreferences()
        appendModerationLog(action: "hide", aliasCode: aliasCode, reason: nil)
        applyLeaderboardModerationFilter()
        showToast("\(aliasCode) 숨김 처리됐어요")
    }

    /// 익명 코드 차단을 적용하고 즉시 목록에서 제거합니다.
    func blockAlias(aliasCode: String) {
        var blocked = Set(blockedAliases)
        blocked.insert(aliasCode)
        blockedAliases = blocked.sorted()
        var hidden = Set(hiddenAliases)
        hidden.insert(aliasCode)
        hiddenAliases = hidden.sorted()
        persistModerationPreferences()
        appendModerationLog(action: "block", aliasCode: aliasCode, reason: nil)
        applyLeaderboardModerationFilter()
        showToast("\(aliasCode) 차단 처리됐어요")
    }

    /// 숨김된 익명 코드를 다시 표시 대상으로 복구합니다.
    func unhideAlias(aliasCode: String) {
        hiddenAliases.removeAll { $0 == aliasCode }
        persistModerationPreferences()
        applyLeaderboardModerationFilter()
    }

    /// 차단된 익명 코드를 다시 표시 대상으로 복구합니다.
    func unblockAlias(aliasCode: String) {
        blockedAliases.removeAll { $0 == aliasCode }
        hiddenAliases.removeAll { $0 == aliasCode }
        persistModerationPreferences()
        applyLeaderboardModerationFilter()
    }

    /// 신고 사유를 로컬 로그에 남기고 중복 신고를 방지합니다.
    func reportAlias(aliasCode: String, reason: RivalReportReason) {
        appendModerationLog(action: "report", aliasCode: aliasCode, reason: reason.rawValue)
        showToast("\(aliasCode) 신고가 접수됐어요")
    }

    /// 권한 안내 카드에서 시스템 설정 화면을 엽니다.
    func openSystemSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
#endif
    }

    /// 짧은 사용자 피드백 메시지를 노출합니다.
    func showToast(_ message: String) {
        toastMessage = message
    }

    /// 노출 중인 토스트를 제거합니다.
    func clearToast() {
        toastMessage = nil
    }

    var sharingBadgeText: String {
        locationSharingEnabled ? "공유 중" : "비공개"
    }

    var sharingBadgeColor: Color {
        locationSharingEnabled ? Color.appGreen : Color.appTextLightGray
    }

    var permissionBadgeText: String {
        guard currentUserId != nil else { return "로그인 필요" }
        return permissionState == .authorized ? "위치 허용" : "권한 필요"
    }

    var permissionBadgeColor: Color {
        guard currentUserId != nil else { return Color.appTextLightGray }
        return permissionState == .authorized ? Color.appGreen : Color.appRed
    }

    /// 사용자 ID 범위에 맞는 위치 공유 설정 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 사용자 범위가 포함된 저장 키 문자열입니다.
    private func locationSharingPreferenceKey(for userId: String?) -> String {
        let scope: String
        if let userId {
            let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            scope = normalized.isEmpty ? "guest" : normalized
        } else {
            scope = "guest"
        }
        return "\(locationSharingKeyPrefix).\(scope)"
    }

    /// 사용자별 위치 공유 기본 정책 초기화 여부 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 정책 초기화 여부를 저장할 키 문자열입니다.
    private func locationSharingPolicyInitializedKey(for userId: String) -> String {
        "\(locationSharingPolicyInitializedKeyPrefix).\(userId)"
    }

    /// 특정 키에 저장된 Bool 값이 존재할 때만 해당 값을 반환합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 값이 있으면 `Bool`, 없으면 `nil`입니다.
    private func storedBoolIfExists(forKey key: String) -> Bool? {
        let whenDefaultTrue = preferenceStore.bool(forKey: key, default: true)
        let whenDefaultFalse = preferenceStore.bool(forKey: key, default: false)
        guard whenDefaultTrue == whenDefaultFalse else {
            return nil
        }
        return whenDefaultTrue
    }

    /// 정책(회원 기본 ON)에 따라 현재 세션의 공유 상태를 로드합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 현재 사용자에게 적용할 익명 공유 활성 상태입니다.
    private func loadLocationSharingPreference(for userId: String?) -> Bool {
        guard let userId else {
            return false
        }

        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedUserId.isEmpty == false else { return false }
        let key = locationSharingPreferenceKey(for: normalizedUserId)
        let initializedKey = locationSharingPolicyInitializedKey(for: normalizedUserId)
        let isInitialized = preferenceStore.bool(forKey: initializedKey, default: false)
        if isInitialized {
            return preferenceStore.bool(forKey: key, default: true)
        }

        let seededValue: Bool
        if let legacyValue = storedBoolIfExists(forKey: locationSharingLegacyGlobalKey) {
            seededValue = legacyValue
        } else {
            seededValue = true
        }

        preferenceStore.set(seededValue, forKey: key)
        preferenceStore.set(true, forKey: initializedKey)
        preferenceStore.removeObject(forKey: locationSharingLegacyGlobalKey)
        return seededValue
    }

    /// 현재 사용자 범위에 익명 공유 상태를 저장합니다.
    /// - Parameters:
    ///   - enabled: 저장할 공유 활성 상태입니다.
    ///   - userId: 저장 대상 사용자 ID입니다.
    private func persistLocationSharingPreference(_ enabled: Bool, for userId: String?) {
        guard let userId else { return }
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedUserId.isEmpty == false else { return }
        preferenceStore.set(enabled, forKey: locationSharingPreferenceKey(for: normalizedUserId))
        preferenceStore.set(true, forKey: locationSharingPolicyInitializedKey(for: normalizedUserId))
    }

    /// 공유 OFF 요청을 최대 30초 창 내에서 재시도해 서버 반영 성공 확률을 높입니다.
    /// - Parameters:
    ///   - userId: 공유 비활성화를 적용할 사용자 ID입니다.
    ///   - startedAt: OFF 처리 시작 시각입니다.
    ///   - attempt: 현재 재시도 시도 횟수입니다.
    private func syncVisibilityOffWithRetry(userId: String, startedAt: Date, attempt: Int) async {
        if attempt > visibilityOffMaxRetries {
            showToast("공유 OFF 서버 반영이 지연되고 있어요. 네트워크 확인 후 다시 시도해주세요.")
            return
        }
        do {
            try await nearbyService.setVisibility(userId: userId, enabled: false)
        } catch {
            if handleAuthFailureIfNeeded(error) {
                return
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = visibilityOffPropagationDeadline - elapsed
            guard remaining > 0 else {
                showToast("공유 OFF 서버 반영이 지연되고 있어요. 네트워크 확인 후 다시 시도해주세요.")
                return
            }

            let delay = min(visibilityOffRetryInterval, remaining)
            let nanos = UInt64(max(1, delay * 1_000_000_000))
            try? await Task.sleep(nanoseconds: nanos)
            await syncVisibilityOffWithRetry(
                userId: userId,
                startedAt: startedAt,
                attempt: attempt + 1
            )
        }
    }

    private var currentUserId: String? {
        guard authSessionStore.currentTokenSession() != nil else {
            return nil
        }
        if let authUserId = authSessionStore.currentIdentity()?.userId,
           let canonical = authUserId.canonicalUUIDString {
            return canonical
        }
        guard case .member(let userId) = sessionProvider(),
              let canonical = userId.canonicalUUIDString else {
            return nil
        }
        return canonical
    }

    /// 권한 상태를 iOS 시스템 값에서 앱 상태로 변환합니다.
    private func updatePermissionState() {
        RivalCoreLocationCallTracer.record(
            "authorizationStatus.read",
            detail: "source=updatePermissionState status=\(locationManager.authorizationStatus.rawValue)"
        )
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .notDetermined
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    /// 인증/권한/공유 상태를 바탕으로 라이벌 화면 상태를 결정합니다.
    private func refreshViewState() {
        let resolved = RivalViewStateResolver.resolve(
            RivalViewStateInput(
                hasAuthenticatedUser: currentUserId != nil,
                permissionState: permissionState,
                locationSharingEnabled: locationSharingEnabled,
                hasHotspots: hotspots.isEmpty == false,
                compareScope: compareScope,
                hasLeaderboardEntries: leaderboardEntries.isEmpty == false
            )
        )
        screenState = resolved.screen
        leaderboardState = resolved.leaderboard
    }

    /// 핫스팟 요약 텍스트를 계산해 카드에 표시합니다.
    private func updateHotspotSummary() {
        let summary = RivalHotspotSummaryBuilder.build(from: hotspots)
        maxIntensityText = summary.maxIntensityText
        lastUpdatedText = summary.lastUpdatedText
        hotspotPreviewRows = summary.previewRows
    }

    /// 주기 조회 타이머를 시작해 공유 중 상태에서 10초마다 핫스팟을 갱신합니다.
    private func startPollingIfNeeded() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshHotspots(force: false)
            self.refreshLeaderboard(force: false)
        }
    }

    /// 라이벌 탭 활성화 동안 인증 세션 변경 알림을 구독합니다.
    private func startAuthSessionObserverIfNeeded() {
        guard authSessionObserver == nil else { return }
        authSessionObserver = NotificationCenter.default.addObserver(
            forName: .authSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAuthSessionDidChange()
        }
    }

    /// 라이벌 탭 비활성화 시 인증 세션 변경 알림 구독을 해제합니다.
    private func stopAuthSessionObserver() {
        guard let authSessionObserver else { return }
        NotificationCenter.default.removeObserver(authSessionObserver)
        self.authSessionObserver = nil
    }

    /// 인증 세션 변경 이벤트를 반영해 라이벌 탭 상태를 즉시 동기화합니다.
    private func handleAuthSessionDidChange() {
        refreshSessionContext()
    }

    /// 저장된 숨김/차단 익명 코드 목록을 불러옵니다.
    private func loadModerationPreferences() {
        let snapshot = moderationStore.loadSnapshot()
        hiddenAliases = snapshot.hiddenAliases
        blockedAliases = snapshot.blockedAliases
    }

    /// 현재 숨김/차단 익명 코드 목록을 로컬 설정에 저장합니다.
    private func persistModerationPreferences() {
        moderationStore.saveSnapshot(
            RivalModerationSnapshot(
                hiddenAliases: hiddenAliases,
                blockedAliases: blockedAliases
            )
        )
    }

    /// 리더보드 원본 데이터에 숨김/차단 필터를 적용해 사용자 노출 목록을 갱신합니다.
    private func applyLeaderboardModerationFilter() {
        let blocked = Set(blockedAliases)
        let hidden = Set(hiddenAliases)
        leaderboardEntries = latestRawLeaderboardEntries.filter { row in
            blocked.contains(row.aliasCode) == false && hidden.contains(row.aliasCode) == false
        }
        if compareScope == .friend {
            leaderboardState = .friendPreview
        } else if leaderboardEntries.isEmpty {
            leaderboardState = .empty
        } else {
            leaderboardState = .ready
        }
    }

    /// 신고/차단/숨김 이력을 로컬 JSON 로그에 누적합니다.
    private func appendModerationLog(action: String, aliasCode: String, reason: String?) {
        moderationStore.appendLog(action: action, aliasCode: aliasCode, reason: reason)
    }

    /// Supabase 응답이 인증 실패(401/403)인지 판정합니다.
    /// - Parameter error: 판정할 원본 오류입니다.
    /// - Returns: 인증 실패 계열이면 `true`, 아니면 `false`입니다.
    private func isAuthFailure(_ error: Error) -> Bool {
        guard let supabaseError = error as? SupabaseHTTPError,
              case .unexpectedStatusCode(let statusCode) = supabaseError else {
            return false
        }
        return statusCode == 401 || statusCode == 403
    }

    /// 인증 실패를 감지하면 세션/공유 상태를 정리하고 재로그인 안내 UX로 전환합니다.
    /// - Parameter error: 네트워크 요청에서 발생한 원본 오류입니다.
    /// - Returns: 인증 실패를 처리해 호출 측이 추가 처리를 중단해야 하면 `true`입니다.
    @discardableResult
    private func handleAuthFailureIfNeeded(_ error: Error) -> Bool {
        guard isAuthFailure(error) else {
            return false
        }
        let affectedUserId = currentUserId
        persistLocationSharingPreference(false, for: affectedUserId)
        locationSharingEnabled = false
        hotspots = []
        updateHotspotSummary()
        leaderboardEntries = []
        latestRawLeaderboardEntries = []
        refreshViewState()
        showToast("인증 세션 확인이 필요해요. 다시 로그인 후 시도해주세요.")
        return true
    }

    /// 위치 권한이 바뀌면 화면 상태를 즉시 재계산합니다.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        RivalCoreLocationCallTracer.record(
            "locationManagerDidChangeAuthorization",
            detail: "status=\(manager.authorizationStatus.rawValue)"
        )
        updatePermissionState()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            RivalCoreLocationCallTracer.record(
                "startUpdatingLocation",
                detail: "source=locationManagerDidChangeAuthorization"
            )
            manager.startUpdatingLocation()
        default:
            RivalCoreLocationCallTracer.record(
                "stopUpdatingLocation",
                detail: "source=locationManagerDidChangeAuthorization"
            )
            manager.stopUpdatingLocation()
        }
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 새 좌표를 받으면 공유 상태에서만 핫스팟을 즉시 갱신합니다.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        RivalCoreLocationCallTracer.record(
            "didUpdateLocations",
            detail: "count=\(locations.count)"
        )
        guard locations.isEmpty == false,
              locationSharingEnabled else { return }
        refreshHotspots(force: false)
        refreshLeaderboard(force: false)
    }
}
