import SwiftUI
import CoreLocation

extension RivalTabViewModel {
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
    func loadLocationSharingPreference(for userId: String?) -> Bool {
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
