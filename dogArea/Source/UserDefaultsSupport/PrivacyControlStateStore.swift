import Foundation

/// 프라이버시 센터에서 최근 공유 상태 요약에 사용할 로컬 스냅샷입니다.
struct PrivacyControlRecentStatus: Codable, Equatable {
    enum Kind: String, Codable {
        case guestLocked
        case privateMode
        case sharingOn
        case permissionRequired
        case offlinePending
        case serverDelayed
    }

    let kind: Kind
    let detail: String
    let updatedAt: TimeInterval
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
}

final class DefaultPrivacyControlStateStore: PrivacyControlStateStoreProtocol {
    static let shared = DefaultPrivacyControlStateStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let scopedSharingKeyPrefix = "nearby.locationSharingEnabled.v1"
    private let initializedKeyPrefix = "nearby.locationSharingPolicyInitialized.v1"
    private let legacyScopedGlobalKey = "nearby.locationSharingEnabled.v1"
    private let legacyMapGlobalKey = "nearby.locationSharingEnabled"
    private let recentStatusKeyPrefix = "privacy.center.recentStatus.v1"

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
}
