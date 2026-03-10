import SwiftUI
import CoreLocation

struct RivalExternalRoute: Equatable {
    enum Source: String, Equatable {
        case hotspotWidget = "hotspot_widget"
    }

    let source: Source
    let radiusPreset: HotspotWidgetRadiusPreset
    let widgetStatus: HotspotWidgetSnapshotStatus

    var bannerMessage: String {
        switch widgetStatus {
        case .offlineCached, .syncDelayed:
            return "위젯에서 \(radiusPreset.shortLabel) 기준으로 열었어요. 이 범위는 마지막 업데이트 시각을 함께 보는 게 중요해요."
        case .privacyGuarded:
            return "위젯에서 \(radiusPreset.shortLabel) 기준으로 열었어요. 상세 신호는 프라이버시 정책에 맞게 축약됩니다."
        default:
            return "위젯에서 \(radiusPreset.shortLabel) 기준으로 열었어요. 같은 반경으로 상세를 확인합니다."
        }
    }
}

extension RivalTabViewModel {
    /// 외부 라우트가 지정한 반경 문맥을 라이벌 탭 상태에 반영합니다.
    /// - Parameter route: 위젯에서 전달된 반경/상태 문맥입니다.
    func applyExternalRoute(_ route: RivalExternalRoute) {
        let shouldForceRefresh = hotspotRadiusPreset == route.radiusPreset
        hotspotExternalRouteBannerMessage = route.bannerMessage
        setHotspotRadiusPreset(route.radiusPreset, source: route.source.rawValue)
        if shouldForceRefresh {
            refreshHotspots(force: true)
        }
    }

    /// 사용자가 선택한 핫스팟 반경 preset을 반영하고 필요 시 즉시 다시 조회합니다.
    /// - Parameters:
    ///   - preset: 새로 적용할 핫스팟 반경 preset입니다.
    ///   - source: preset 변경을 유발한 진입 소스 식별자입니다.
    func setHotspotRadiusPreset(_ preset: HotspotWidgetRadiusPreset, source: String) {
        let didChange = hotspotRadiusPreset != preset
        hotspotRadiusPreset = preset
        persistHotspotRadiusPreset(preset, for: currentUserId)

        if source != RivalExternalRoute.Source.hotspotWidget.rawValue {
            hotspotExternalRouteBannerMessage = nil
        }

        guard didChange else { return }
        metricTracker.track(
            .rivalHotspotFetchRequested,
            userKey: currentUserId,
            featureKey: .nearbyHotspotV1,
            payload: ["source": source, "radius_preset": preset.rawValue]
        )
        refreshHotspots(force: true)
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
                recordRecentPrivacyStatus(
                    kind: .sharingOn,
                    detail: "서버 반영까지 확인했어요. 산책 중 익명 공유를 다시 사용할 수 있어요.",
                    for: userId
                )
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
                recordVisibilityFailureStatus(enabled: true, for: userId, error: error)
                locationSharingEnabled = false
                refreshViewState()
                showToast(visibilityFailureMessage(for: error))
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
        recordRecentPrivacyStatus(
            kind: .privateMode,
            detail: "지금부터 비공개예요. 새 공유는 우선 중단됐어요.",
            for: userId
        )
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

        let now = Date()
        if shouldSkipHotspotRefresh(force: force, now: now) {
            return
        }
        guard isHotspotRefreshing == false else { return }

        isHotspotRefreshing = true
        if force == false {
            lastRefreshAt = now
        }
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
                    radiusKm: hotspotRadiusPreset.radiusKm
                )
                let maxIntensity = fetched.map(\.intensity).max() ?? 0
                metricTracker.track(
                    .rivalHotspotFetchSucceeded,
                    userKey: userId,
                    featureKey: .nearbyHotspotV1,
                    eventValue: Double(fetched.count),
                    payload: [
                        "radius_preset": hotspotRadiusPreset.rawValue,
                        "cell_count": "\(fetched.count)",
                        "max_intensity": String(format: "%.4f", maxIntensity)
                    ]
                )
                hotspots = fetched
                lastRefreshAt = Date()
                resetHotspotFailureBackoff()
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
                        "radius_preset": hotspotRadiusPreset.rawValue,
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
                applyHotspotFailureBackoff(for: error, now: Date())
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
        guard isLeaderboardRefreshing == false else { return }
        if force == false && Date().timeIntervalSince(lastLeaderboardRefreshAt) < leaderboardMinimumRefreshInterval {
            return
        }

        isLeaderboardRefreshing = true
        if force == false {
            lastLeaderboardRefreshAt = Date()
        }
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

    /// 사용자 ID 범위에 맞는 핫스팟 반경 preset 저장 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 사용자 범위가 포함된 반경 preset 저장 키 문자열입니다.
    private func hotspotRadiusPresetKey(for userId: String?) -> String {
        let scope: String
        if let userId {
            let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            scope = normalized.isEmpty ? "guest" : normalized
        } else {
            scope = "guest"
        }
        return "\(hotspotRadiusPresetKeyPrefix).\(scope)"
    }

    /// 공통 프라이버시 저장소에서 현재 세션의 공유 상태를 로드합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 현재 사용자에게 적용할 익명 공유 활성 상태입니다.
    func loadLocationSharingPreference(for userId: String?) -> Bool {
        privacyControlStateStore.loadSharingEnabled(for: userId)
    }

    /// 현재 사용자 범위에 익명 공유 상태를 저장합니다.
    /// - Parameters:
    ///   - enabled: 저장할 공유 활성 상태입니다.
    ///   - userId: 저장 대상 사용자 ID입니다.
    private func persistLocationSharingPreference(_ enabled: Bool, for userId: String?) {
        privacyControlStateStore.persistSharingEnabled(enabled, for: userId)
    }

    /// 현재 사용자 범위에 저장된 핫스팟 반경 preset을 로드합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다.
    /// - Returns: 저장된 반경 preset이 있으면 해당 값, 없으면 기본 `balanced` preset입니다.
    func loadHotspotRadiusPreset(for userId: String?) -> HotspotWidgetRadiusPreset {
        guard let rawValue = preferenceStore.string(forKey: hotspotRadiusPresetKey(for: userId)),
              let preset = HotspotWidgetRadiusPreset(rawValue: rawValue) else {
            return .balanced
        }
        return preset
    }

    /// 현재 사용자 범위에 핫스팟 반경 preset을 저장합니다.
    /// - Parameters:
    ///   - preset: 저장할 핫스팟 반경 preset입니다.
    ///   - userId: 저장 대상 사용자 ID입니다.
    private func persistHotspotRadiusPreset(_ preset: HotspotWidgetRadiusPreset, for userId: String?) {
        preferenceStore.set(preset.rawValue, forKey: hotspotRadiusPresetKey(for: userId))
    }

    /// 공유 OFF 요청을 최대 30초 창 내에서 재시도해 서버 반영 성공 확률을 높입니다.
    /// - Parameters:
    ///   - userId: 공유 비활성화를 적용할 사용자 ID입니다.
    ///   - startedAt: OFF 처리 시작 시각입니다.
    ///   - attempt: 현재 재시도 시도 횟수입니다.
    private func syncVisibilityOffWithRetry(userId: String, startedAt: Date, attempt: Int) async {
        if attempt > visibilityOffMaxRetries {
            recordRecentPrivacyStatus(
                kind: .serverDelayed,
                detail: "비공개 요청의 서버 반영이 조금 늦고 있어요. 잠시 후 다시 확인해주세요.",
                for: userId
            )
            showToast("공유 OFF 서버 반영이 지연되고 있어요. 네트워크 확인 후 다시 시도해주세요.")
            return
        }
        do {
            try await nearbyService.setVisibility(userId: userId, enabled: false)
            recordRecentPrivacyStatus(
                kind: .privateMode,
                detail: "서버 반영까지 확인했어요. 새 공유는 더 이상 반영되지 않아요.",
                for: userId
            )
        } catch {
            if handleAuthFailureIfNeeded(error) {
                return
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = visibilityOffPropagationDeadline - elapsed
            guard remaining > 0 else {
                recordVisibilityFailureStatus(enabled: false, for: userId, error: error)
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

    var currentUserId: String? {
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

    /// 최근 프라이버시 상태 요약을 현재 사용자 범위에 저장합니다.
    /// - Parameters:
    ///   - kind: 저장할 상태 종류입니다.
    ///   - detail: 프라이버시 센터와 토스트에 노출할 사용자 문구입니다.
    ///   - userId: 저장 대상 사용자 ID입니다.
    private func recordRecentPrivacyStatus(
        kind: PrivacyControlRecentStatus.Kind,
        detail: String,
        for userId: String?
    ) {
        privacyControlStateStore.recordRecentStatus(
            kind: kind,
            detail: detail,
            for: userId,
            at: Date()
        )
    }

    /// 공유 상태 동기화 실패를 최근 상태 문구/배지로 변환해 저장합니다.
    /// - Parameters:
    ///   - enabled: 사용자가 의도한 목표 공유 상태입니다.
    ///   - userId: 현재 사용자 ID입니다.
    ///   - error: 서버 동기화 실패 원본 오류입니다.
    private func recordVisibilityFailureStatus(
        enabled: Bool,
        for userId: String?,
        error: Error
    ) {
        if RivalNetworkErrorInterpreter.isConnectivityError(error) {
            let detail = enabled
                ? "연결이 없어 공유 시작 반영이 보류됐어요. 연결이 돌아오면 다시 확인해주세요."
                : "연결이 없어 비공개 반영이 늦을 수 있어요. 새 공유는 우선 멈췄어요."
            recordRecentPrivacyStatus(kind: .offlinePending, detail: detail, for: userId)
            return
        }

        let detail = enabled
            ? "서버 반영이 조금 늦고 있어요. 잠시 후 다시 확인해주세요."
            : "비공개 요청의 서버 반영이 조금 늦고 있어요. 잠시 후 다시 확인해주세요."
        recordRecentPrivacyStatus(kind: .serverDelayed, detail: detail, for: userId)
    }

    /// Supabase 응답이 인증 실패(401/403)인지 판정합니다.
    /// - Parameter error: 판정할 원본 오류입니다.
    /// - Returns: 인증 실패 계열이면 `true`, 아니면 `false`입니다.
    private func isAuthFailure(_ error: Error) -> Bool {
        guard let supabaseError = error as? SupabaseHTTPError,
              case .unexpectedStatusCode(let statusCode) = supabaseError else {
            return false
        }
        guard statusCode == 401 || statusCode == 403 else {
            return false
        }
        return authSessionStore.currentTokenSession() == nil
    }

    /// 로컬 토큰 세션이 유지된 상태에서 서버 게이트 401/403이 발생했는지 판정합니다.
    /// - Parameter error: 판정할 원본 오류입니다.
    /// - Returns: 토큰 세션이 남아 있고 401/403만 발생한 상태면 `true`, 아니면 `false`입니다.
    private func isSessionPreservedUnauthorizedStatus(_ error: Error) -> Bool {
        guard let supabaseError = error as? SupabaseHTTPError,
              case .unexpectedStatusCode(let statusCode) = supabaseError else {
            return false
        }
        guard statusCode == 401 || statusCode == 403 else {
            return false
        }
        return authSessionStore.currentTokenSession() != nil
    }

    /// 공유 설정 실패 시 유효 세션 여부를 반영한 사용자 안내 메시지를 생성합니다.
    /// - Parameter error: 원본 네트워크 오류입니다.
    /// - Returns: 현재 인증 상태를 고려한 사용자 안내 메시지입니다.
    private func visibilityFailureMessage(for error: Error) -> String {
        if isSessionPreservedUnauthorizedStatus(error) {
            return "로그인은 유지되어 있어요. 서버 인증 상태를 다시 확인 중이니 잠시 후 다시 시도해주세요."
        }
        return RivalNetworkErrorInterpreter.visibilityFailureMessage(from: error)
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
        recordRecentPrivacyStatus(
            kind: .guestLocked,
            detail: "인증 세션이 없어 공유 상태를 유지할 수 없어요. 다시 로그인 후 시도해주세요.",
            for: affectedUserId
        )
        locationSharingEnabled = false
        hotspots = []
        updateHotspotSummary()
        leaderboardEntries = []
        latestRawLeaderboardEntries = []
        refreshViewState()
        showToast("인증 세션 확인이 필요해요. 다시 로그인 후 시도해주세요.")
        return true
    }

    /// `SupabaseHTTPError`에서 HTTP 상태 코드를 추출합니다.
    /// - Parameter error: 네트워크 요청 실패 오류입니다.
    /// - Returns: 상태 코드가 존재하면 정수값을 반환하고, 없으면 `nil`을 반환합니다.
    private func httpStatusCode(from error: Error) -> Int? {
        guard let supabaseError = error as? SupabaseHTTPError,
              case .unexpectedStatusCode(let statusCode) = supabaseError else {
            return nil
        }
        return statusCode
    }

    /// 핫스팟 갱신 요청을 현재 시점에 건너뛰어야 하는지 판정합니다.
    /// - Parameters:
    ///   - force: 강제 갱신 여부입니다.
    ///   - now: 판정 기준 시각입니다.
    /// - Returns: 요청을 보내지 말아야 하면 `true`, 요청 가능하면 `false`입니다.
    private func shouldSkipHotspotRefresh(force: Bool, now: Date) -> Bool {
        guard force == false else { return false }
        if now < hotspotFailureRetryAt {
            return true
        }
        return now.timeIntervalSince(lastRefreshAt) < hotspotMinimumRefreshInterval
    }

    /// 핫스팟 요청 실패 시 백오프 윈도우를 계산해 다음 호출 가능 시점을 지연합니다.
    /// - Parameters:
    ///   - error: 원본 네트워크 오류입니다.
    ///   - now: 실패가 발생한 시각입니다.
    /// - Returns: 없음. 내부 실패 스트릭/다음 재시도 시각 상태를 갱신합니다.
    private func applyHotspotFailureBackoff(for error: Error, now: Date) {
        let statusCode = httpStatusCode(from: error)
        let isServerFailure = (statusCode ?? 0) >= 500
        let isRetryableNetworkFailure = RivalNetworkErrorInterpreter.isConnectivityError(error)
        guard isServerFailure || isRetryableNetworkFailure else {
            hotspotFailureStreak = 0
            hotspotFailureRetryAt = now
            return
        }

        hotspotFailureStreak = min(6, hotspotFailureStreak + 1)
        let multiplier = pow(2.0, Double(max(0, hotspotFailureStreak - 1)))
        let backoff = min(
            hotspotFailureBackoffMaxInterval,
            hotspotFailureBackoffBaseInterval * multiplier
        )
        hotspotFailureRetryAt = now.addingTimeInterval(backoff)
        #if DEBUG
        print(
            "[Rival] hotspot refresh backoff applied streak=\(hotspotFailureStreak) backoff=\(Int(backoff))s status=\(statusCode ?? -1)"
        )
        #endif
    }

    /// 핫스팟 요청 성공 시 누적된 실패 백오프 상태를 초기화합니다.
    /// - Returns: 없음. 다음 갱신이 최소 주기 기준으로만 판단되도록 실패 상태를 리셋합니다.
    private func resetHotspotFailureBackoff() {
        hotspotFailureStreak = 0
        hotspotFailureRetryAt = .distantPast
    }
}
