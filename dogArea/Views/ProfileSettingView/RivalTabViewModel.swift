import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class RivalTabViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
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
    private let locationSharingKey = "nearby.locationSharingEnabled.v1"
    private var pollingTimer: Timer? = nil
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
        sessionProvider: @escaping () -> AppSessionState = { AppFeatureGate.currentSession() }
    ) {
        self.nearbyService = nearbyService
        self.rivalLeagueService = rivalLeagueService
        self.preferenceStore = preferenceStore
        self.moderationStore = moderationStore ?? RivalModerationStore(preferenceStore: preferenceStore)
        self.locationManager = locationManager
        self.authSessionStore = authSessionStore
        self.sessionProvider = sessionProvider
        super.init()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    /// 탭 진입 시 권한/공유 상태를 불러오고 폴링을 시작합니다.
    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
        loadModerationPreferences()
        refreshSessionContext()
        startPollingIfNeeded()
    }

    /// 탭 이탈 시 폴링/위치 업데이트를 중단합니다.
    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        locationManager.stopUpdatingLocation()
    }

    /// 로그인/로그아웃 직후 세션 컨텍스트를 다시 읽고 UI 상태를 즉시 갱신합니다.
    func refreshSessionContext() {
        locationSharingEnabled = preferenceStore.bool(forKey: locationSharingKey, default: false)
        loadModerationPreferences()
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 위치 권한 요청을 수행합니다.
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 동의 시트 완료 후 익명 공유를 활성화합니다.
    func enableSharingWithConsent() {
        guard currentUserId != nil else {
            showToast("회원 전용 기능입니다. 로그인 후 다시 시도해주세요.")
            refreshViewState()
            return
        }

        isSharingInFlight = true
        Task {
            defer { isSharingInFlight = false }
            do {
                try await nearbyService.setVisibility(userId: currentUserId ?? "", enabled: true)
                preferenceStore.set(true, forKey: locationSharingKey)
                locationSharingEnabled = true
                showToast("익명 공유가 시작됐어요")
                refreshViewState()
                refreshHotspots(force: true)
                refreshLeaderboard(force: true)
            } catch {
                preferenceStore.set(false, forKey: locationSharingKey)
                locationSharingEnabled = false
                refreshViewState()
                showToast(RivalNetworkErrorInterpreter.visibilityFailureMessage(from: error))
            }
        }
    }

    /// 익명 공유를 비활성화하고 핫스팟을 초기화합니다.
    func disableSharing() {
        guard let userId = currentUserId else {
            preferenceStore.set(false, forKey: locationSharingKey)
            locationSharingEnabled = false
            hotspots = []
            refreshViewState()
            return
        }

        isSharingInFlight = true
        let previous = locationSharingEnabled
        preferenceStore.set(false, forKey: locationSharingKey)
        locationSharingEnabled = false
        hotspots = []
        leaderboardEntries = []
        latestRawLeaderboardEntries = []
        refreshViewState()
        showToast("익명 공유를 중지했어요")

        Task {
            defer { isSharingInFlight = false }
            do {
                try await nearbyService.setVisibility(userId: userId, enabled: false)
            } catch {
                preferenceStore.set(previous, forKey: locationSharingKey)
                locationSharingEnabled = previous
                refreshViewState()
                showToast(RivalNetworkErrorInterpreter.visibilityFailureMessage(from: error))
            }
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
                hotspots = fetched
                lastRefreshAt = Date()
                updateHotspotSummary()
                if fetched.isEmpty {
                    screenState = .empty
                } else {
                    screenState = .ready
                }
            } catch {
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
                latestRawLeaderboardEntries = rows
                lastLeaderboardRefreshAt = Date()
                applyLeaderboardModerationFilter()
            } catch {
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

    private var currentUserId: String? {
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
            Task { @MainActor in
                self?.refreshHotspots(force: false)
                self?.refreshLeaderboard(force: false)
            }
        }
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

    /// 위치 권한이 바뀌면 화면 상태를 즉시 재계산합니다.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 새 좌표를 받으면 공유 상태에서만 핫스팟을 즉시 갱신합니다.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.isEmpty == false,
              locationSharingEnabled else { return }
        refreshHotspots(force: false)
        refreshLeaderboard(force: false)
    }
}
