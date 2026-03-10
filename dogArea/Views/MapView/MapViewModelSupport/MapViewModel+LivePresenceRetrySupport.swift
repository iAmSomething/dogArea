import Foundation

struct MapLivePresenceRetryState {
    static let baseBackoffInterval: TimeInterval = 10
    static let maxBackoffInterval: TimeInterval = 120
    static let bannerCooldownInterval: TimeInterval = 20

    var failureStreak: Int = 0
    var retryAt: Date = .distantPast
    var lastPresentedSignature: String?
    var lastPresentedAt: Date = .distantPast
}

extension MapViewModel {
    /// 현재 시점에 라이브 프레즌스 큐 flush를 건너뛰어야 하는지 판정합니다.
    /// - Parameter now: 판정 기준 시각입니다.
    /// - Returns: 백오프 윈도우 안이면 `true`, 즉시 재시도 가능하면 `false`입니다.
    func shouldSkipLivePresenceFlush(now: Date) -> Bool {
        now < livePresenceRetryState.retryAt
    }

    /// 라이브 프레즌스 재시도 실패 시 다음 업로드 가능 시점을 백오프로 지연합니다.
    /// - Parameters:
    ///   - error: 원본 업로드 오류입니다.
    ///   - now: 실패가 발생한 시각입니다.
    func applyLivePresenceFailureBackoff(for error: Error, now: Date) {
        guard shouldQueueLivePresenceRetry(for: error) else {
            livePresenceRetryState.failureStreak = 0
            livePresenceRetryState.retryAt = now
            return
        }

        livePresenceRetryState.failureStreak = min(6, livePresenceRetryState.failureStreak + 1)
        let multiplier = pow(2.0, Double(max(0, livePresenceRetryState.failureStreak - 1)))
        let backoff = min(
            MapLivePresenceRetryState.maxBackoffInterval,
            MapLivePresenceRetryState.baseBackoffInterval * multiplier
        )
        livePresenceRetryState.retryAt = now.addingTimeInterval(backoff)
    }

    /// 성공 복구 또는 세션 종료 시 라이브 프레즌스 실패 상태를 초기화합니다.
    func resetLivePresenceRetryFailureState() {
        livePresenceRetryState = MapLivePresenceRetryState()
        livePresenceRetryBannerText = ""
    }

    /// 동일한 재시도 실패 배너를 쿨다운 내 중복 노출하지 않도록 제어합니다.
    /// - Parameters:
    ///   - error: 원본 업로드 오류입니다.
    ///   - now: 배너 노출 판정 기준 시각입니다.
    func presentLivePresenceFailureBannerIfNeeded(for error: Error, now: Date) {
        let message = livePresenceFailureMessage(for: error)
        let signature = livePresenceFailureBannerSignature(for: error, message: message)
        if signature == livePresenceRetryState.lastPresentedSignature,
           now.timeIntervalSince(livePresenceRetryState.lastPresentedAt) < MapLivePresenceRetryState.bannerCooldownInterval {
            return
        }

        livePresenceRetryState.lastPresentedSignature = signature
        livePresenceRetryState.lastPresentedAt = now
        livePresenceRetryBannerText = message
    }

    /// 라이브 프레즌스 실패 배너의 중복 판정 키를 계산합니다.
    /// - Parameters:
    ///   - error: 원본 업로드 오류입니다.
    ///   - message: 사용자에게 노출할 최종 메시지입니다.
    /// - Returns: 동일 오류 재표시 억제에 사용할 안정적인 시그니처 문자열입니다.
    func livePresenceFailureBannerSignature(for error: Error, message: String) -> String {
        if let supabaseError = error as? SupabaseHTTPError,
           case .unexpectedStatusCode(let statusCode) = supabaseError {
            return "supabase-status-\(statusCode)-\(message)"
        }
        if let urlError = error as? URLError {
            return "url-\(urlError.code.rawValue)-\(message)"
        }
        return "generic-\(message)"
    }
}
