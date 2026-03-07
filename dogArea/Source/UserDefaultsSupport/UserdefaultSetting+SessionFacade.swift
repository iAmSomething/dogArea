import Foundation

extension UserdefaultSetting {
    /// 현재 선택된 반려견 식별자를 반환합니다.
    /// - Returns: 저장된 반려견 식별자입니다. 선택값이 없으면 `nil`입니다.
    func selectedPetId() -> String? {
        petSelectionStore.selectedPetId()
    }

    /// 현재 선택된 반려견 식별자를 저장합니다.
    /// - Parameters:
    ///   - petId: 선택할 반려견 식별자입니다.
    ///   - source: 선택 변경의 발생 출처입니다.
    func setSelectedPetId(_ petId: String, source: String = "manual") {
        petSelectionStore.setSelectedPetId(petId, source: source)
    }

    /// 사용자 정보 기준으로 현재 활성 반려견을 계산합니다.
    /// - Parameter userInfo: 선택 해석에 사용할 사용자 정보입니다. `nil`이면 현재 저장된 사용자 정보를 사용합니다.
    /// - Returns: 현재 활성 반려견입니다. 선택 가능한 반려견이 없으면 `nil`입니다.
    func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo? {
        let info = userInfo ?? getValue()
        return petSelectionStore.selectedPet(from: info)
    }

    /// 산책 시작 시점에 가장 적합한 반려견을 추천합니다.
    /// - Parameters:
    ///   - userInfo: 추천 계산에 사용할 사용자 정보입니다. `nil`이면 현재 저장된 사용자 정보를 사용합니다.
    ///   - now: 추천 계산 기준 시각입니다.
    /// - Returns: 추천 반려견입니다. 추천 대상이 없으면 `nil`입니다.
    func suggestedPetForWalkStart(from userInfo: UserInfo? = nil, now: Date = Date()) -> PetInfo? {
        let info = userInfo ?? getValue()
        return petSelectionStore.suggestedPetForWalkStart(from: info, now: now)
    }

    /// 최근 반려견 선택 이벤트 목록을 반환합니다.
    /// - Returns: 저장된 선택 이벤트 배열입니다.
    func recentPetSelectionEvents() -> [PetSelectionEvent] {
        petSelectionStore.recentPetSelectionEvents()
    }

    /// 현재 선택된 반려견의 캐리커처 상태를 갱신합니다.
    /// - Parameters:
    ///   - status: 저장할 캐리커처 처리 상태입니다.
    ///   - caricatureURL: 생성된 캐리커처 이미지 URL입니다.
    ///   - provider: 캐리커처 생성 제공자 식별자입니다.
    func updateFirstPetCaricature(
        status: CaricatureStatus,
        caricatureURL: String? = nil,
        provider: String? = nil
    ) {
        guard let current = getValue(), current.pet.isEmpty == false else { return }
        let targetPetId = selectedPet(from: current)?.petId ?? current.pet.first?.petId
        guard let targetPetId else { return }
        _ = profileStore.updatePetCaricature(
            status: status,
            targetPetId: targetPetId,
            caricatureURL: caricatureURL,
            provider: provider
        )
    }

    /// 시즌 추격 버프 스냅샷을 조회합니다.
    /// - Returns: 저장된 스냅샷입니다. 값이 없으면 `nil`입니다.
    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot? {
        userDefaults.structData(
            SeasonCatchupBuffSnapshot.self,
            forKey: keyValue.seasonCatchupBuffSnapshot.rawValue
        )
    }

    /// 시즌 추격 버프 스냅샷을 저장하고 전역 갱신 알림을 발행합니다.
    /// - Parameter snapshot: 저장할 시즌 추격 버프 스냅샷입니다.
    func updateSeasonCatchupBuffSnapshot(_ snapshot: SeasonCatchupBuffSnapshot) {
        userDefaults.setStruct(snapshot, forKey: keyValue.seasonCatchupBuffSnapshot.rawValue)
        NotificationCenter.default.post(
            name: UserdefaultSetting.seasonCatchupBuffDidUpdateNotification,
            object: nil,
            userInfo: [
                "status": snapshot.status.rawValue,
                "isActive": snapshot.isActive,
                "walkSessionId": snapshot.walkSessionId
            ]
        )
    }

    /// 산책 시작 카운트다운 사용 여부를 조회합니다.
    /// - Returns: 카운트다운이 활성화되어 있으면 `true`입니다.
    func walkStartCountdownEnabled() -> Bool {
        walkSessionMetadataStore.walkStartCountdownEnabled()
    }

    /// 산책 시작 카운트다운 사용 여부를 저장합니다.
    /// - Parameter enabled: 저장할 카운트다운 활성 상태입니다.
    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        walkSessionMetadataStore.setWalkStartCountdownEnabled(enabled)
    }

    /// 산책 포인트 기록 모드의 원시 값을 조회합니다.
    /// - Returns: 저장된 포인트 기록 모드 원시 값입니다.
    func walkPointRecordModeRawValue() -> String {
        walkSessionMetadataStore.walkPointRecordModeRawValue()
    }

    /// 산책 포인트 기록 모드의 원시 값을 저장합니다.
    /// - Parameter rawValue: 저장할 포인트 기록 모드 원시 값입니다.
    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        walkSessionMetadataStore.setWalkPointRecordModeRawValue(rawValue)
    }

}
