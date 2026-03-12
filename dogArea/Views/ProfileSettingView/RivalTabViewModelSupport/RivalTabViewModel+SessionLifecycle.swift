import Foundation
import CoreLocation

extension RivalTabViewModel {
    /// UI 테스트에서 위치 권한 상태를 허용으로 고정해야 하는지 반환합니다.
    /// - Returns: `-UITest.RivalForceAuthorizedLocation` 인자가 포함되면 `true`를 반환합니다.
    private var shouldForceAuthorizedLocationForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.RivalForceAuthorizedLocation")
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
        hotspotRadiusPreset = loadHotspotRadiusPreset(for: currentUserId)
        loadModerationPreferences()
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 위치 권한 요청을 수행합니다.
    func requestLocationPermission() {
        if shouldForceAuthorizedLocationForUITest {
            permissionState = .authorized
            refreshViewState()
            return
        }
        RivalCoreLocationCallTracer.record(
            "requestWhenInUseAuthorization",
            detail: "source=requestLocationPermission"
        )
        locationManager.requestWhenInUseAuthorization()
    }

    /// 권한 상태를 iOS 시스템 값에서 앱 상태로 변환합니다.
    func updatePermissionState() {
        if shouldForceAuthorizedLocationForUITest {
            permissionState = .authorized
            return
        }
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
    func refreshViewState() {
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
    func updateHotspotSummary() {
        let summary = RivalHotspotSummaryBuilder.build(from: hotspots)
        maxIntensityText = summary.maxIntensityText
        lastUpdatedText = summary.lastUpdatedText
        hotspotPreviewRows = summary.previewRows
    }

    /// 주기 조회 타이머를 시작해 공유 중 상태에서 10초마다 핫스팟을 갱신합니다.
    private func startPollingIfNeeded() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshHotspots(force: false)
                self.refreshLeaderboard(force: false)
            }
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
            Task { @MainActor [weak self] in
                self?.handleAuthSessionDidChange()
            }
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
}
