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
            meaningTitle: "산책이 바로 기록이 됩니다",
            meaningMessage: "저장된 산책은 기록 목록, 영역 목표, 시즌 진행, 오늘 행동 해석으로 이어집니다.",
            pillars: [
                .init(id: "route", title: "경로·영역 기록"),
                .init(id: "history", title: "시간·기록 누적"),
                .init(id: "systems", title: "목표·미션 연결")
            ],
            secondaryFlowText: "실내 미션은 악천후나 예외 상황에서만 열리는 보조 흐름입니다.",
            walkingStatusText: "경로·영역 기록 중",
            endAlertMessage: "저장 후 종료하면 이번 경로와 영역이 산책 기록으로 남고, 홈 목표와 시즌 진행에 이어집니다. 계속 걷기를 누르면 산책을 이어갈 수 있어요."
        )
    }
}
