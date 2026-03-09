import Foundation

/// 지도 시작 전후에 산책의 의미를 설명하는 프레젠테이션을 생성하는 계약입니다.
protocol MapWalkStartPresenting {
    /// 현재 반려견 선택 상태를 바탕으로 지도 시작 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - hasSelectedPet: 산책 시작 대상 반려견이 확정되어 있는지 여부입니다.
    ///   - selectedPetName: 현재 선택된 반려견 이름입니다.
    /// - Returns: 지도 시작 전후 문맥 카드가 바로 렌더링할 수 있는 프레젠테이션입니다.
    func makePresentation(hasSelectedPet: Bool, selectedPetName: String) -> MapWalkStartPresentation
}

struct MapWalkStartPresentationService: MapWalkStartPresenting {
    /// 현재 반려견 선택 상태를 바탕으로 지도 시작 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - hasSelectedPet: 산책 시작 대상 반려견이 확정되어 있는지 여부입니다.
    ///   - selectedPetName: 현재 선택된 반려견 이름입니다.
    /// - Returns: 지도 시작 전후 문맥 카드가 바로 렌더링할 수 있는 프레젠테이션입니다.
    func makePresentation(hasSelectedPet: Bool, selectedPetName: String) -> MapWalkStartPresentation {
        MapWalkStartPresentation(
            selectedPetTitle: hasSelectedPet ? selectedPetName : "반려견 선택 필요",
            selectedPetMessage: hasSelectedPet
                ? "산책을 시작하면 \(selectedPetName) 기준으로 경로, 영역, 시간이 기록됩니다."
                : "산책 기록을 어느 반려견과 연결할지 먼저 선택해주세요.",
            meaningTitle: "이 산책이 바로 기록돼요",
            meaningSummary: "경로·영역·시간이 함께 저장돼요.",
            meaningDetail: "저장된 산책은 홈 목표, 산책 기록, 시즌 해석으로 이어집니다.",
            disclosureTitle: "기록 내용",
            disclosureCloseTitle: "접기",
            guideTitle: "설명 보기",
            walkingStatusText: "경로·영역 기록 중",
            endAlertMessage: "저장 후 종료하면 이번 경로와 영역이 산책 기록으로 남고, 홈 목표와 시즌 진행에 이어집니다. 계속 걷기를 누르면 산책을 이어갈 수 있어요."
        )
    }
}
