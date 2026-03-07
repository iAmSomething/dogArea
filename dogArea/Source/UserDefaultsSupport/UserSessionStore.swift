import Foundation

protocol UserSessionStoreProtocol {
    /// 현재 로그인 세션에 저장된 사용자 정보를 조회합니다.
    /// - Returns: 저장된 사용자 정보입니다. 세션이 없으면 `nil`입니다.
    func currentUserInfo() -> UserInfo?
    /// 사용자 정보 기준으로 현재 선택된 반려견을 계산합니다.
    /// - Parameter userInfo: 선택 상태를 해석할 사용자 정보입니다.
    /// - Returns: 현재 활성 반려견입니다. 선택 정보가 없으면 `nil`입니다.
    func selectedPet(from userInfo: UserInfo?) -> PetInfo?
    /// 현재 선택된 반려견 식별자를 저장합니다.
    /// - Parameters:
    ///   - petId: 선택할 반려견 식별자입니다.
    ///   - source: 선택 이벤트의 발생 출처입니다.
    func setSelectedPetId(_ petId: String, source: String)
    /// 산책 시작 시점에 가장 적합한 반려견을 추천합니다.
    /// - Parameters:
    ///   - userInfo: 추천 계산 기준 사용자 정보입니다.
    ///   - now: 추천 계산 기준 시각입니다.
    /// - Returns: 추천 반려견입니다. 추천 가능한 반려견이 없으면 `nil`입니다.
    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date) -> PetInfo?
    /// 현재 시즌 추격 버프 스냅샷을 조회합니다.
    /// - Returns: 저장된 시즌 추격 버프 상태입니다. 값이 없으면 `nil`입니다.
    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot?
    /// 산책 시작 카운트다운 사용 여부를 조회합니다.
    /// - Returns: 카운트다운이 활성화되어 있으면 `true`입니다.
    func walkStartCountdownEnabled() -> Bool
    /// 산책 시작 카운트다운 사용 여부를 저장합니다.
    /// - Parameter enabled: 저장할 카운트다운 활성 상태입니다.
    func setWalkStartCountdownEnabled(_ enabled: Bool)
    /// 산책 포인트 기록 모드의 원시 값을 조회합니다.
    /// - Returns: 저장된 포인트 기록 모드 원시 값입니다.
    func walkPointRecordModeRawValue() -> String
    /// 산책 포인트 기록 모드의 원시 값을 저장합니다.
    /// - Parameter rawValue: 저장할 포인트 기록 모드 원시 값입니다.
    func setWalkPointRecordModeRawValue(_ rawValue: String)
}

final class DefaultUserSessionStore: UserSessionStoreProtocol {
    static let shared = DefaultUserSessionStore()
    private let storage: UserdefaultSetting

    init(storage: UserdefaultSetting = .shared) {
        self.storage = storage
    }

    /// 현재 로그인 세션에 저장된 사용자 정보를 조회합니다.
    /// - Returns: 저장된 사용자 정보입니다. 세션이 없으면 `nil`입니다.
    func currentUserInfo() -> UserInfo? {
        storage.getValue()
    }

    /// 사용자 정보 기준으로 현재 선택된 반려견을 계산합니다.
    /// - Parameter userInfo: 선택 상태를 해석할 사용자 정보입니다.
    /// - Returns: 현재 활성 반려견입니다. 선택 정보가 없으면 `nil`입니다.
    func selectedPet(from userInfo: UserInfo?) -> PetInfo? {
        storage.selectedPet(from: userInfo)
    }

    /// 현재 선택된 반려견 식별자를 저장합니다.
    /// - Parameters:
    ///   - petId: 선택할 반려견 식별자입니다.
    ///   - source: 선택 이벤트의 발생 출처입니다.
    func setSelectedPetId(_ petId: String, source: String) {
        storage.setSelectedPetId(petId, source: source)
    }

    /// 산책 시작 시점에 가장 적합한 반려견을 추천합니다.
    /// - Parameters:
    ///   - userInfo: 추천 계산 기준 사용자 정보입니다.
    ///   - now: 추천 계산 기준 시각입니다.
    /// - Returns: 추천 반려견입니다. 추천 가능한 반려견이 없으면 `nil`입니다.
    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date) -> PetInfo? {
        storage.suggestedPetForWalkStart(from: userInfo, now: now)
    }

    /// 현재 시즌 추격 버프 스냅샷을 조회합니다.
    /// - Returns: 저장된 시즌 추격 버프 상태입니다. 값이 없으면 `nil`입니다.
    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot? {
        storage.seasonCatchupBuffSnapshot()
    }

    /// 산책 시작 카운트다운 사용 여부를 조회합니다.
    /// - Returns: 카운트다운이 활성화되어 있으면 `true`입니다.
    func walkStartCountdownEnabled() -> Bool {
        storage.walkStartCountdownEnabled()
    }

    /// 산책 시작 카운트다운 사용 여부를 저장합니다.
    /// - Parameter enabled: 저장할 카운트다운 활성 상태입니다.
    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        storage.setWalkStartCountdownEnabled(enabled)
    }

    /// 산책 포인트 기록 모드의 원시 값을 조회합니다.
    /// - Returns: 저장된 포인트 기록 모드 원시 값입니다.
    func walkPointRecordModeRawValue() -> String {
        storage.walkPointRecordModeRawValue()
    }

    /// 산책 포인트 기록 모드의 원시 값을 저장합니다.
    /// - Parameter rawValue: 저장할 포인트 기록 모드 원시 값입니다.
    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        storage.setWalkPointRecordModeRawValue(rawValue)
    }
}
