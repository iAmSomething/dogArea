import Foundation

/// 프라이버시 센터에서 최근 공유 상태 요약에 사용할 로컬 스냅샷입니다.
struct PrivacyControlRecentStatus: Codable, Equatable {
    enum Kind: String, Codable {
        case guestLocked
        case privateMode
        case sharingOn
        case permissionRequired
        case authRefreshRequired
        case offlinePending
        case serverDelayed
    }

    let kind: Kind
    let detail: String
    let updatedAt: TimeInterval
}

/// 프라이버시 센터에서 서버 기준 공유 상태를 표현하는 canonical 스냅샷입니다.
struct PrivacyControlServerSyncSnapshot: Codable, Equatable {
    enum State: String, Codable {
        case localPending
        case serverConfirmed
        case serverFailed
    }

    enum FailureCategory: String, Codable {
        case offline
        case serverDelayed
        case authRequired
        case unknown
    }

    let desiredEnabled: Bool
    let canonicalEnabled: Bool?
    let requestedAt: TimeInterval?
    let resultRecordedAt: TimeInterval
    let serverUpdatedAt: TimeInterval?
    let requestId: String?
    let state: State
    let failureCategory: FailureCategory?
    let failureCode: String?

    /// 사용자가 방금 기기에서 요청한 optimistic 상태를 생성합니다.
    /// - Parameters:
    ///   - desiredEnabled: 사용자가 의도한 목표 공유 상태입니다.
    ///   - lastCanonicalEnabled: 서버에서 마지막으로 확인한 canonical 상태입니다. 아직 없으면 `nil`입니다.
    ///   - requestedAt: 사용자가 토글을 누른 시각입니다.
    ///   - requestId: 서버와 상호 추적할 요청 식별자입니다.
    /// - Returns: 서버 확인 전 단계의 canonical snapshot입니다.
    static func localPending(
        desiredEnabled: Bool,
        lastCanonicalEnabled: Bool?,
        requestedAt: Date,
        requestId: String? = nil
    ) -> PrivacyControlServerSyncSnapshot {
        PrivacyControlServerSyncSnapshot(
            desiredEnabled: desiredEnabled,
            canonicalEnabled: lastCanonicalEnabled,
            requestedAt: requestedAt.timeIntervalSince1970,
            resultRecordedAt: requestedAt.timeIntervalSince1970,
            serverUpdatedAt: nil,
            requestId: requestId,
            state: .localPending,
            failureCategory: nil,
            failureCode: nil
        )
    }

    /// 서버 반영 완료 응답을 canonical snapshot으로 변환합니다.
    /// - Parameters:
    ///   - desiredEnabled: 사용자가 의도했던 목표 공유 상태입니다.
    ///   - canonicalEnabled: 서버가 최종적으로 반영한 공유 상태입니다.
    ///   - requestedAt: 사용자가 마지막으로 요청한 시각입니다. 없으면 `nil`입니다.
    ///   - serverUpdatedAt: 서버 row가 갱신된 시각입니다. 없으면 `nil`입니다.
    ///   - recordedAt: 앱이 성공 응답을 기록한 시각입니다.
    ///   - requestId: 서버와 상호 추적할 요청 식별자입니다.
    /// - Returns: 서버 확인 완료 상태의 canonical snapshot입니다.
    static func serverConfirmed(
        desiredEnabled: Bool,
        canonicalEnabled: Bool,
        requestedAt: Date?,
        serverUpdatedAt: Date?,
        recordedAt: Date,
        requestId: String? = nil
    ) -> PrivacyControlServerSyncSnapshot {
        PrivacyControlServerSyncSnapshot(
            desiredEnabled: desiredEnabled,
            canonicalEnabled: canonicalEnabled,
            requestedAt: requestedAt?.timeIntervalSince1970,
            resultRecordedAt: recordedAt.timeIntervalSince1970,
            serverUpdatedAt: serverUpdatedAt?.timeIntervalSince1970,
            requestId: requestId,
            state: .serverConfirmed,
            failureCategory: nil,
            failureCode: nil
        )
    }

    /// 마지막 요청 메타데이터를 보존한 채 서버 canonical 상태만 새로 갱신합니다.
    /// - Parameters:
    ///   - canonicalEnabled: 서버가 현재 보유한 canonical 공유 상태입니다.
    ///   - requestedAt: 마지막 사용자 요청 시각입니다. 없으면 `nil`입니다.
    ///   - desiredEnabled: 사용자가 현재 기기에 저장한 목표 공유 상태입니다.
    ///   - previousRequestId: 이전 요청 식별자입니다.
    ///   - serverUpdatedAt: 서버 row가 갱신된 시각입니다. 없으면 `nil`입니다.
    ///   - recordedAt: 앱이 서버 canonical 상태를 읽어온 시각입니다.
    /// - Returns: fetch 기반으로 새로 고친 canonical snapshot입니다.
    static func refreshedCanonical(
        canonicalEnabled: Bool,
        requestedAt: Date?,
        desiredEnabled: Bool,
        previousRequestId: String?,
        serverUpdatedAt: Date?,
        recordedAt: Date
    ) -> PrivacyControlServerSyncSnapshot {
        PrivacyControlServerSyncSnapshot(
            desiredEnabled: desiredEnabled,
            canonicalEnabled: canonicalEnabled,
            requestedAt: requestedAt?.timeIntervalSince1970,
            resultRecordedAt: recordedAt.timeIntervalSince1970,
            serverUpdatedAt: serverUpdatedAt?.timeIntervalSince1970,
            requestId: previousRequestId,
            state: .serverConfirmed,
            failureCategory: nil,
            failureCode: nil
        )
    }

    /// 서버 반영 실패 결과를 canonical snapshot으로 변환합니다.
    /// - Parameters:
    ///   - desiredEnabled: 사용자가 의도한 목표 공유 상태입니다.
    ///   - lastCanonicalEnabled: 마지막으로 확인된 canonical 상태입니다. 없으면 `nil`입니다.
    ///   - requestedAt: 사용자가 요청한 시각입니다. 없으면 `nil`입니다.
    ///   - recordedAt: 앱이 실패를 기록한 시각입니다.
    ///   - requestId: 서버와 상호 추적할 요청 식별자입니다.
    ///   - failureCategory: 사용자 문구에 매핑할 실패 분류입니다.
    ///   - failureCode: 장애 분석용 세부 코드입니다.
    /// - Returns: 서버 확인 실패 상태의 canonical snapshot입니다.
    static func serverFailed(
        desiredEnabled: Bool,
        lastCanonicalEnabled: Bool?,
        requestedAt: Date?,
        recordedAt: Date,
        requestId: String? = nil,
        failureCategory: FailureCategory,
        failureCode: String?
    ) -> PrivacyControlServerSyncSnapshot {
        PrivacyControlServerSyncSnapshot(
            desiredEnabled: desiredEnabled,
            canonicalEnabled: lastCanonicalEnabled,
            requestedAt: requestedAt?.timeIntervalSince1970,
            resultRecordedAt: recordedAt.timeIntervalSince1970,
            serverUpdatedAt: nil,
            requestId: requestId,
            state: .serverFailed,
            failureCategory: failureCategory,
            failureCode: failureCode
        )
    }
}

/// 프라이버시 공유 동기화 실패를 사용자 문구와 서버 스냅샷 분류로 해석한 결과입니다.
struct PrivacyControlVisibilityFailureDescriptor: Equatable {
    let recentStatusKind: PrivacyControlRecentStatus.Kind
    let detail: String
    let toastMessage: String
    let failureCategory: PrivacyControlServerSyncSnapshot.FailureCategory
    let failureCode: String?

    /// 원본 오류를 프라이버시 센터 표면에 맞는 실패 분류로 변환합니다.
    /// - Parameters:
    ///   - error: 서버 동기화 중 발생한 원본 오류입니다.
    ///   - enabled: 사용자가 의도한 목표 공유 상태입니다.
    ///   - authSessionAvailable: 현재 로컬 토큰 세션이 남아 있는지 여부입니다.
    /// - Returns: 최근 상태 문구, 토스트, 서버 snapshot 분류가 정리된 결과입니다.
    static func make(
        from error: Error,
        enabled: Bool,
        authSessionAvailable: Bool
    ) -> PrivacyControlVisibilityFailureDescriptor {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                let detail = enabled
                    ? "연결이 없어 공유 시작 요청을 저장만 했어요. 서버 확인은 연결이 돌아오면 다시 진행됩니다."
                    : "연결이 없어 비공개 전환 요청을 저장만 했어요. 서버 확인은 연결이 돌아오면 다시 진행됩니다."
                return PrivacyControlVisibilityFailureDescriptor(
                    recentStatusKind: .offlinePending,
                    detail: detail,
                    toastMessage: detail,
                    failureCategory: .offline,
                    failureCode: "url_\(urlError.code.rawValue)"
                )
            default:
                break
            }
        }

        if let supabaseError = error as? SupabaseHTTPError,
           case .unexpectedStatusCode(let statusCode) = supabaseError {
            if statusCode == 401 || statusCode == 403 {
                let detail = authSessionAvailable
                    ? "로그인은 유지되어 있지만 서버 인증 확인이 필요해요. 잠시 후 다시 시도해주세요."
                    : "로그인 상태를 다시 확인한 뒤 공유 상태를 바꿔주세요."
                return PrivacyControlVisibilityFailureDescriptor(
                    recentStatusKind: .authRefreshRequired,
                    detail: detail,
                    toastMessage: detail,
                    failureCategory: .authRequired,
                    failureCode: "http_\(statusCode)"
                )
            }

            let detail = enabled
                ? "공유 시작 요청을 보냈지만 서버 확인이 늦고 있어요. 잠시 후 다시 확인해주세요."
                : "비공개 전환 요청을 보냈지만 서버 확인이 늦고 있어요. 잠시 후 다시 확인해주세요."
            return PrivacyControlVisibilityFailureDescriptor(
                recentStatusKind: .serverDelayed,
                detail: detail,
                toastMessage: detail,
                failureCategory: .serverDelayed,
                failureCode: "http_\(statusCode)"
            )
        }

        let detail = enabled
            ? "공유 시작 요청을 보냈지만 서버 확인이 늦고 있어요. 잠시 후 다시 확인해주세요."
            : "비공개 전환 요청을 보냈지만 서버 확인이 늦고 있어요. 잠시 후 다시 확인해주세요."
        return PrivacyControlVisibilityFailureDescriptor(
            recentStatusKind: .serverDelayed,
            detail: detail,
            toastMessage: detail,
            failureCategory: .unknown,
            failureCode: nil
        )
    }
}

/// 공유 기본값과 최근 상태 스냅샷을 공통으로 저장/조회하는 계약입니다.
protocol PrivacyControlStateStoreProtocol {
    /// 현재 사용자 범위의 익명 공유 기본값을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 `nil`입니다.
    /// - Returns: 현재 사용자에게 적용할 공유 활성 상태입니다.
    func loadSharingEnabled(for userId: String?) -> Bool

    /// 현재 사용자 범위의 익명 공유 기본값을 저장합니다.
    /// - Parameters:
    ///   - enabled: 저장할 공유 활성 상태입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 저장하지 않습니다.
    func persistSharingEnabled(_ enabled: Bool, for userId: String?)

    /// 현재 사용자 범위에 저장된 최근 공유 상태 요약을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 읽습니다.
    /// - Returns: 저장된 최근 공유 상태가 있으면 반환하고, 없으면 `nil`입니다.
    func loadRecentStatus(for userId: String?) -> PrivacyControlRecentStatus?

    /// 현재 사용자 범위에 저장된 서버 기준 공유 상태 스냅샷을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 읽습니다.
    /// - Returns: 저장된 canonical server snapshot이 있으면 반환하고, 없으면 `nil`입니다.
    func loadServerSyncSnapshot(for userId: String?) -> PrivacyControlServerSyncSnapshot?

    /// 최근 공유 상태 요약을 현재 사용자 범위에 저장합니다.
    /// - Parameters:
    ///   - kind: 저장할 최근 상태 종류입니다.
    ///   - detail: 사용자에게 보여줄 상세 설명입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    ///   - date: 상태가 기록된 시각입니다.
    func recordRecentStatus(
        kind: PrivacyControlRecentStatus.Kind,
        detail: String,
        for userId: String?,
        at date: Date
    )

    /// 서버 기준 공유 상태 스냅샷을 현재 사용자 범위에 저장합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 canonical server snapshot입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    func persistServerSyncSnapshot(_ snapshot: PrivacyControlServerSyncSnapshot, for userId: String?)
}

final class DefaultPrivacyControlStateStore: PrivacyControlStateStoreProtocol {
    static let shared = DefaultPrivacyControlStateStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let scopedSharingKeyPrefix = "nearby.locationSharingEnabled.v1"
    private let initializedKeyPrefix = "nearby.locationSharingPolicyInitialized.v1"
    private let legacyScopedGlobalKey = "nearby.locationSharingEnabled.v1"
    private let legacyMapGlobalKey = "nearby.locationSharingEnabled"
    private let recentStatusKeyPrefix = "privacy.center.recentStatus.v1"
    private let serverSnapshotKeyPrefix = "privacy.center.serverSyncSnapshot.v1"

    /// 공통 프라이버시 상태 저장소를 구성합니다.
    /// - Parameter preferenceStore: UserDefaults 기반 값 저장/조회에 사용할 저장소입니다.
    init(preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared) {
        self.preferenceStore = preferenceStore
    }

    /// 현재 사용자 범위의 익명 공유 기본값을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 `nil`입니다.
    /// - Returns: 현재 사용자에게 적용할 공유 활성 상태입니다.
    func loadSharingEnabled(for userId: String?) -> Bool {
        guard let normalizedUserId = normalizedUserID(from: userId) else {
            return false
        }
        let key = sharingKey(for: normalizedUserId)
        let initializedKey = sharingInitializedKey(for: normalizedUserId)
        let isInitialized = preferenceStore.bool(forKey: initializedKey, default: false)
        if isInitialized {
            return preferenceStore.bool(forKey: key, default: true)
        }

        let seededValue: Bool
        if let scopedLegacyValue = storedBoolIfExists(forKey: legacyScopedGlobalKey) {
            seededValue = scopedLegacyValue
        } else if let mapLegacyValue = storedBoolIfExists(forKey: legacyMapGlobalKey) {
            seededValue = mapLegacyValue
        } else {
            seededValue = false
        }

        preferenceStore.set(seededValue, forKey: key)
        preferenceStore.set(true, forKey: initializedKey)
        preferenceStore.removeObject(forKey: legacyScopedGlobalKey)
        preferenceStore.removeObject(forKey: legacyMapGlobalKey)
        return seededValue
    }

    /// 현재 사용자 범위의 익명 공유 기본값을 저장합니다.
    /// - Parameters:
    ///   - enabled: 저장할 공유 활성 상태입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 저장하지 않습니다.
    func persistSharingEnabled(_ enabled: Bool, for userId: String?) {
        guard let normalizedUserId = normalizedUserID(from: userId) else { return }
        preferenceStore.set(enabled, forKey: sharingKey(for: normalizedUserId))
        preferenceStore.set(true, forKey: sharingInitializedKey(for: normalizedUserId))
        preferenceStore.removeObject(forKey: legacyScopedGlobalKey)
        preferenceStore.removeObject(forKey: legacyMapGlobalKey)
    }

    /// 현재 사용자 범위에 저장된 최근 공유 상태 요약을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 읽습니다.
    /// - Returns: 저장된 최근 공유 상태가 있으면 반환하고, 없으면 `nil`입니다.
    func loadRecentStatus(for userId: String?) -> PrivacyControlRecentStatus? {
        guard let data = preferenceStore.data(forKey: recentStatusKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(PrivacyControlRecentStatus.self, from: data)
    }

    /// 현재 사용자 범위에 저장된 서버 기준 공유 상태 스냅샷을 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 읽습니다.
    /// - Returns: 저장된 canonical server snapshot이 있으면 반환하고, 없으면 `nil`입니다.
    func loadServerSyncSnapshot(for userId: String?) -> PrivacyControlServerSyncSnapshot? {
        guard let data = preferenceStore.data(forKey: serverSyncSnapshotKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(PrivacyControlServerSyncSnapshot.self, from: data)
    }

    /// 최근 공유 상태 요약을 현재 사용자 범위에 저장합니다.
    /// - Parameters:
    ///   - kind: 저장할 최근 상태 종류입니다.
    ///   - detail: 사용자에게 보여줄 상세 설명입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    ///   - date: 상태가 기록된 시각입니다.
    func recordRecentStatus(
        kind: PrivacyControlRecentStatus.Kind,
        detail: String,
        for userId: String?,
        at date: Date
    ) {
        let snapshot = PrivacyControlRecentStatus(
            kind: kind,
            detail: detail,
            updatedAt: date.timeIntervalSince1970
        )
        let encoded = try? JSONEncoder().encode(snapshot)
        preferenceStore.set(encoded, forKey: recentStatusKey(for: userId))
    }

    /// 서버 기준 공유 상태 스냅샷을 현재 사용자 범위에 저장합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 canonical server snapshot입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    func persistServerSyncSnapshot(_ snapshot: PrivacyControlServerSyncSnapshot, for userId: String?) {
        let encoded = try? JSONEncoder().encode(snapshot)
        preferenceStore.set(encoded, forKey: serverSyncSnapshotKey(for: userId))
    }

    /// 저장된 Bool 값이 실제로 존재할 때만 해당 값을 반환합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 값이 명시적으로 저장돼 있으면 `Bool`, 없으면 `nil`입니다.
    private func storedBoolIfExists(forKey key: String) -> Bool? {
        let whenDefaultTrue = preferenceStore.bool(forKey: key, default: true)
        let whenDefaultFalse = preferenceStore.bool(forKey: key, default: false)
        guard whenDefaultTrue == whenDefaultFalse else {
            return nil
        }
        return whenDefaultTrue
    }

    /// 저장용 사용자 ID를 공백 제거 후 정규화합니다.
    /// - Parameter userId: 원본 사용자 ID 문자열입니다.
    /// - Returns: 유효한 사용자 ID면 정규화된 문자열, 아니면 `nil`입니다.
    private func normalizedUserID(from userId: String?) -> String? {
        guard let userId else { return nil }
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    /// 사용자 범위 공유 기본값 키를 생성합니다.
    /// - Parameter userId: 정규화된 사용자 ID입니다.
    /// - Returns: 사용자 범위가 포함된 저장 키 문자열입니다.
    private func sharingKey(for userId: String) -> String {
        "\(scopedSharingKeyPrefix).\(userId)"
    }

    /// 사용자 범위 정책 초기화 여부 키를 생성합니다.
    /// - Parameter userId: 정규화된 사용자 ID입니다.
    /// - Returns: 정책 초기화 플래그 저장 키 문자열입니다.
    private func sharingInitializedKey(for userId: String) -> String {
        "\(initializedKeyPrefix).\(userId)"
    }

    /// 최근 공유 상태 저장 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 사용합니다.
    /// - Returns: 사용자 범위가 포함된 최근 상태 저장 키 문자열입니다.
    private func recentStatusKey(for userId: String?) -> String {
        let scope = normalizedUserID(from: userId) ?? "guest"
        return "\(recentStatusKeyPrefix).\(scope)"
    }

    /// 서버 기준 공유 상태 스냅샷 저장 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 사용합니다.
    /// - Returns: 사용자 범위가 포함된 canonical server snapshot 저장 키 문자열입니다.
    private func serverSyncSnapshotKey(for userId: String?) -> String {
        let scope = normalizedUserID(from: userId) ?? "guest"
        return "\(serverSnapshotKeyPrefix).\(scope)"
    }
}
