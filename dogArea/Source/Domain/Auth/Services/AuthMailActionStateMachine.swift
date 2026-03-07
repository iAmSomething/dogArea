import Foundation

protocol AuthMailActionStateStoring {
    /// 지정한 메일 액션 키에 해당하는 persisted snapshot을 조회합니다.
    /// - Parameter key: 조회할 메일 액션 고유 키입니다.
    /// - Returns: 저장된 snapshot이 있으면 해당 값을 반환하고, 없으면 `nil`을 반환합니다.
    func snapshot(for key: AuthMailActionKey) -> AuthMailResendSnapshot?

    /// 지정한 메일 액션 키에 대한 persisted snapshot을 저장합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 메일 액션 상태 snapshot입니다.
    ///   - key: snapshot을 연결할 메일 액션 고유 키입니다.
    func save(_ snapshot: AuthMailResendSnapshot, for key: AuthMailActionKey)

    /// 지정한 메일 액션 키에 연결된 persisted snapshot을 제거합니다.
    /// - Parameter key: 제거할 메일 액션 고유 키입니다.
    func removeSnapshot(for key: AuthMailActionKey)
}

protocol AuthMailActionStateManaging {
    /// persisted snapshot을 해석해 현재 시각 기준의 resend 상태를 반환합니다.
    /// - Parameters:
    ///   - key: 해석할 메일 액션 고유 키입니다.
    ///   - now: 상태 해석 기준 시각입니다.
    /// - Returns: 현재 시각 기준으로 계산된 resend 상태입니다.
    func state(for key: AuthMailActionKey, now: Date) -> AuthMailResendState

    /// 현재 상태가 실제 요청 전송을 허용하는지 판정합니다.
    /// - Parameters:
    ///   - key: 요청 전송 여부를 확인할 메일 액션 고유 키입니다.
    ///   - now: 판정 기준 시각입니다.
    /// - Returns: 현재 메일 액션 요청을 전송해도 되면 `true`, 아니면 `false`입니다.
    func canSend(for key: AuthMailActionKey, now: Date) -> Bool

    /// 서버 성공 응답을 기준으로 sent/cooldown snapshot을 기록합니다.
    /// - Parameters:
    ///   - key: 성공 상태를 기록할 메일 액션 고유 키입니다.
    ///   - now: 성공 처리 기준 시각입니다.
    ///   - fallbackCooldownSeconds: `Retry-After`가 없을 때 적용할 보수적 쿨다운 초 단위 값입니다.
    /// - Returns: 성공 직후 사용자에게 노출할 resend 상태입니다.
    @discardableResult
    func recordSuccess(
        for key: AuthMailActionKey,
        now: Date,
        fallbackCooldownSeconds: Int
    ) -> AuthMailResendState

    /// 429/Retry-After 응답을 기준으로 rate-limited snapshot을 기록합니다.
    /// - Parameters:
    ///   - key: 제한 상태를 기록할 메일 액션 고유 키입니다.
    ///   - retryAfterSeconds: 서버가 준 재시도 대기 시간입니다.
    ///   - now: 제한 처리 기준 시각입니다.
    ///   - fallbackCooldownSeconds: 헤더가 없을 때 사용할 보수적 fallback 초 단위 값입니다.
    /// - Returns: 제한 응답 직후 사용자에게 노출할 resend 상태입니다.
    @discardableResult
    func recordRateLimited(
        for key: AuthMailActionKey,
        retryAfterSeconds: Int?,
        now: Date,
        fallbackCooldownSeconds: Int
    ) -> AuthMailResendState
}

final class AuthMailActionStateMachine: AuthMailActionStateManaging {
    private let store: AuthMailActionStateStoring
    private let sentBannerSeconds: Int

    /// persisted snapshot 저장소를 주입해 메일 resend 상태 기계를 초기화합니다.
    /// - Parameters:
    ///   - store: 액션별 cooldown/rate-limit snapshot 저장소입니다.
    ///   - sentBannerSeconds: 성공 직후 `sent` 상태를 유지할 초 단위 시간입니다.
    init(
        store: AuthMailActionStateStoring = AuthMailActionStateStore(),
        sentBannerSeconds: Int = 8
    ) {
        self.store = store
        self.sentBannerSeconds = sentBannerSeconds
    }

    func state(for key: AuthMailActionKey, now: Date = Date()) -> AuthMailResendState {
        guard let snapshot = store.snapshot(for: key) else {
            return .idle
        }

        let nowSeconds = now.timeIntervalSince1970
        if nowSeconds >= snapshot.nextAllowedAt {
            store.removeSnapshot(for: key)
            return .idle
        }

        let remainingSeconds = max(Int(ceil(snapshot.nextAllowedAt - nowSeconds)), 1)
        if nowSeconds < snapshot.sentBannerUntil, snapshot.wasRateLimited == false {
            return .sent(remainingSeconds: remainingSeconds)
        }
        if snapshot.wasRateLimited {
            return .rateLimited(remainingSeconds: remainingSeconds)
        }
        return .cooldown(remainingSeconds: remainingSeconds)
    }

    func canSend(for key: AuthMailActionKey, now: Date = Date()) -> Bool {
        state(for: key, now: now).isRequestAllowed
    }

    @discardableResult
    func recordSuccess(
        for key: AuthMailActionKey,
        now: Date = Date(),
        fallbackCooldownSeconds: Int
    ) -> AuthMailResendState {
        let snapshot = AuthMailResendSnapshot(
            actionType: key.actionType,
            recipient: key.recipient,
            context: key.context,
            sentBannerUntil: now.addingTimeInterval(TimeInterval(sentBannerSeconds)).timeIntervalSince1970,
            nextAllowedAt: now.addingTimeInterval(TimeInterval(fallbackCooldownSeconds)).timeIntervalSince1970,
            retryAfterSeconds: nil,
            lastUpdatedAt: now.timeIntervalSince1970,
            wasRateLimited: false
        )
        store.save(snapshot, for: key)
        return .sent(remainingSeconds: max(fallbackCooldownSeconds, 1))
    }

    @discardableResult
    func recordRateLimited(
        for key: AuthMailActionKey,
        retryAfterSeconds: Int?,
        now: Date = Date(),
        fallbackCooldownSeconds: Int
    ) -> AuthMailResendState {
        let resolvedCooldownSeconds = max(retryAfterSeconds ?? fallbackCooldownSeconds, 1)
        let snapshot = AuthMailResendSnapshot(
            actionType: key.actionType,
            recipient: key.recipient,
            context: key.context,
            sentBannerUntil: now.timeIntervalSince1970,
            nextAllowedAt: now.addingTimeInterval(TimeInterval(resolvedCooldownSeconds)).timeIntervalSince1970,
            retryAfterSeconds: retryAfterSeconds,
            lastUpdatedAt: now.timeIntervalSince1970,
            wasRateLimited: true
        )
        store.save(snapshot, for: key)
        return .rateLimited(remainingSeconds: resolvedCooldownSeconds)
    }
}
