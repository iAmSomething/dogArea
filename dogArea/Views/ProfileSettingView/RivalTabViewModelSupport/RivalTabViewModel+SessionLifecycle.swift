import Foundation
import CoreLocation

extension RivalTabViewModel {
    /// UI 테스트에서 위치 권한 상태를 허용으로 고정해야 하는지 반환합니다.
    /// - Returns: `-UITest.RivalForceAuthorizedLocation` 인자가 포함되면 `true`를 반환합니다.
    private var shouldForceAuthorizedLocationForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.RivalForceAuthorizedLocation")
    }

    /// 인증 토큰은 있지만 사용자 컨텍스트가 아직 라이벌 탭에 반영되지 않은 과도기 상태인지 반환합니다.
    var isResolvingAuthenticatedSession: Bool {
        authSessionStore.currentTokenSession() != nil && currentUserId == nil
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
        scheduleSessionRevalidationIfNeeded()
        startPollingIfNeeded()
    }

    /// 탭 이탈 시 폴링/위치 업데이트를 중단합니다.
    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        sessionRevalidationTask?.cancel()
        sessionRevalidationTask = nil
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

    /// 인증 세션이 방금 바뀐 직후 라이벌 탭이 게스트 잠금 상태로 남지 않도록 짧은 재동기화를 예약합니다.
    private func scheduleSessionRevalidationIfNeeded() {
        sessionRevalidationTask?.cancel()
        sessionRevalidationTask = nil

        guard authSessionStore.currentTokenSession() != nil else { return }
        guard screenState == .guestLocked || currentUserId == nil else { return }

        sessionRevalidationTask = Task { @MainActor [weak self] in
            let retryDelays: [UInt64] = [300_000_000, 800_000_000, 1_500_000_000, 3_000_000_000]
            for delay in retryDelays {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: delay)
                guard Task.isCancelled == false else { return }
                self.refreshSessionContext()
                if self.currentUserId != nil, self.screenState != .guestLocked {
                    self.sessionRevalidationTask = nil
                    return
                }
            }
            self?.sessionRevalidationTask = nil
        }
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
        scheduleSessionRevalidationIfNeeded()
    }
}
