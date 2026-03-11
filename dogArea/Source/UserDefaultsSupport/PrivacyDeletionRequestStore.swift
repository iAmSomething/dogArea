import Foundation

/// 프라이버시 삭제 요청의 로컬 추적 상태를 공통으로 저장/조회하는 계약입니다.
protocol PrivacyDeletionRequestStoreProtocol {
    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 `nil`입니다.
    /// - Returns: 저장된 삭제 요청 레코드가 있으면 반환하고, 없으면 `nil`입니다.
    func loadRecord(for userId: String?) -> PrivacyDeletionRequestRecord?

    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 저장합니다.
    /// - Parameters:
    ///   - record: 저장할 삭제 요청 추적 레코드입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    func persistRecord(_ record: PrivacyDeletionRequestRecord, for userId: String?)

    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 제거합니다.
    /// - Parameter userId: 제거 대상 사용자 ID입니다. 게스트면 guest 스코프를 사용합니다.
    func clearRecord(for userId: String?)
}

final class DefaultPrivacyDeletionRequestStore: PrivacyDeletionRequestStoreProtocol {
    static let shared = DefaultPrivacyDeletionRequestStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let requestKeyPrefix = "privacy.center.deletionRequest.v1"

    /// 공통 프라이버시 삭제 요청 저장소를 구성합니다.
    /// - Parameter preferenceStore: UserDefaults 기반 값 저장/조회에 사용할 저장소입니다.
    init(preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared) {
        self.preferenceStore = preferenceStore
    }

    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 읽습니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 `nil`입니다.
    /// - Returns: 저장된 삭제 요청 레코드가 있으면 반환하고, 없으면 `nil`입니다.
    func loadRecord(for userId: String?) -> PrivacyDeletionRequestRecord? {
        guard let data = preferenceStore.data(forKey: requestKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(PrivacyDeletionRequestRecord.self, from: data)
    }

    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 저장합니다.
    /// - Parameters:
    ///   - record: 저장할 삭제 요청 추적 레코드입니다.
    ///   - userId: 저장 대상 사용자 ID입니다. 게스트면 guest 스코프에 저장합니다.
    func persistRecord(_ record: PrivacyDeletionRequestRecord, for userId: String?) {
        let encoded = try? JSONEncoder().encode(record)
        preferenceStore.set(encoded, forKey: requestKey(for: userId))
    }

    /// 현재 사용자 범위의 삭제 요청 추적 레코드를 제거합니다.
    /// - Parameter userId: 제거 대상 사용자 ID입니다. 게스트면 guest 스코프를 사용합니다.
    func clearRecord(for userId: String?) {
        preferenceStore.removeObject(forKey: requestKey(for: userId))
    }

    /// 사용자 범위 삭제 요청 저장 키를 생성합니다.
    /// - Parameter userId: 현재 인증 사용자 ID입니다. 게스트면 guest 스코프를 사용합니다.
    /// - Returns: 사용자 범위가 포함된 삭제 요청 저장 키 문자열입니다.
    private func requestKey(for userId: String?) -> String {
        let scope = normalizedUserID(from: userId) ?? "guest"
        return "\(requestKeyPrefix).\(scope)"
    }

    /// 저장용 사용자 ID를 공백 제거 후 정규화합니다.
    /// - Parameter userId: 원본 사용자 ID 문자열입니다.
    /// - Returns: 유효한 사용자 ID면 정규화된 문자열, 아니면 `nil`입니다.
    private func normalizedUserID(from userId: String?) -> String? {
        guard let userId else { return nil }
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
