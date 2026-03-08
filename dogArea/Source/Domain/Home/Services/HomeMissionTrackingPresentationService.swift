import Foundation

/// 홈 미션의 자동 추적형/직접 체크형 표현을 일관되게 생성하는 계약입니다.
protocol HomeMissionTrackingModePresenting {
    /// 홈 미션 카드 상단에서 보여줄 자동형/직접형 비교 프레젠테이션을 생성합니다.
    /// - Parameter localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 상단 비교 영역에서 사용할 추적 방식 프레젠테이션 목록입니다.
    func makeBoardTrackingModes(
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeMissionTrackingModePresentation]

    /// 개별 실내 미션 행에서 사용할 직접 체크형 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - mission: 현재 행이 설명할 실내 미션입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 행 단위에서 사용할 직접 체크형 프레젠테이션입니다.
    func makeManualRowTrackingMode(
        for mission: IndoorMissionCardModel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeMissionTrackingModePresentation

    /// 개별 실내 미션 행에서 보여줄 직접 체크 요약 문구를 생성합니다.
    /// - Parameters:
    ///   - mission: 현재 행이 설명할 실내 미션입니다.
    ///   - lifecycleState: 현재 미션의 완료 생명주기 상태입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 사용자가 버튼보다 먼저 읽어야 할 직접 체크 요약 문구입니다.
    func makeManualTrackingSummary(
        for mission: IndoorMissionCardModel,
        lifecycleState: HomeIndoorMissionLifecycleState,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String
}

final class HomeMissionTrackingPresentationService: HomeMissionTrackingModePresenting {
    /// 홈 미션 카드 상단에서 보여줄 자동형/직접형 비교 프레젠테이션을 생성합니다.
    /// - Parameter localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 상단 비교 영역에서 사용할 추적 방식 프레젠테이션 목록입니다.
    func makeBoardTrackingModes(
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeMissionTrackingModePresentation] {
        [
            .init(
                id: "auto",
                kind: .automatic,
                badgeText: localizedCopy("자동 기록", "Auto Tracked"),
                title: localizedCopy("산책 중 자동 반영", "Auto During Walks"),
                subtitle: localizedCopy("산책 데이터로 진행돼요", "Powered by walk data"),
                iconSystemName: "figure.walk.circle.fill",
                detailLines: [
                    localizedCopy(
                        "산책 시간, 이동 거리, 영역 변화 같은 기록으로 진행돼요.",
                        "Progress comes from walk time, distance, and territory changes."
                    ),
                    localizedCopy(
                        "앱을 계속 보고 있지 않아도 저장된 산책 데이터 기준으로 반영돼요.",
                        "It still updates from saved walk data even when the app is not on screen."
                    ),
                    localizedCopy(
                        "조건을 채우면 진행 상태가 자동으로 바뀌어요.",
                        "The state changes automatically once the requirement is met."
                    )
                ]
            ),
            .init(
                id: "manual",
                kind: .manual,
                badgeText: localizedCopy("직접 체크", "Self Logged"),
                title: localizedCopy("실내 행동 직접 기록", "Log Indoor Actions Yourself"),
                subtitle: localizedCopy("끝낸 행동만 직접 남겨요", "Only log what you finished"),
                iconSystemName: "hand.tap.fill",
                detailLines: [
                    localizedCopy(
                        "실제로 끝낸 행동만 `행동 +1 기록`으로 남겨야 해요.",
                        "Use `Log +1` only after a real completed action."
                    ),
                    localizedCopy(
                        "카드마다 필요한 횟수를 먼저 채워야 해요.",
                        "You need to fill the required count shown on the card."
                    ),
                    localizedCopy(
                        "횟수를 채운 뒤에도 `완료 확인`으로 한 번 더 확정해야 끝나요.",
                        "Even after filling the count, you still confirm once more to finish."
                    )
                ]
            )
        ]
    }

    /// 개별 실내 미션 행에서 사용할 직접 체크형 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - mission: 현재 행이 설명할 실내 미션입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 행 단위에서 사용할 직접 체크형 프레젠테이션입니다.
    func makeManualRowTrackingMode(
        for mission: IndoorMissionCardModel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeMissionTrackingModePresentation {
        .init(
            id: "\(mission.id).manual",
            kind: .manual,
            badgeText: localizedCopy("직접 체크", "Self Logged"),
            title: localizedCopy("실내 행동 직접 기록", "Log Indoor Actions Yourself"),
            subtitle: localizedCopy("끝낸 행동만 직접 남겨요", "Only log finished actions"),
            iconSystemName: "hand.tap.fill",
            detailLines: [
                localizedCopy(
                    "실제로 끝낸 행동만 1회씩 기록해 주세요.",
                    "Record only real completed actions, one at a time."
                ),
                localizedCopy(
                    "이 카드의 목표는 \(mission.minimumActionCount)회예요.",
                    "The target on this card is \(mission.minimumActionCount) logs."
                )
            ]
        )
    }

    /// 개별 실내 미션 행에서 보여줄 직접 체크 요약 문구를 생성합니다.
    /// - Parameters:
    ///   - mission: 현재 행이 설명할 실내 미션입니다.
    ///   - lifecycleState: 현재 미션의 완료 생명주기 상태입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 사용자가 버튼보다 먼저 읽어야 할 직접 체크 요약 문구입니다.
    func makeManualTrackingSummary(
        for mission: IndoorMissionCardModel,
        lifecycleState: HomeIndoorMissionLifecycleState,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        switch lifecycleState {
        case .actionRequired:
            return localizedCopy(
                "실제로 끝낸 행동만 직접 기록해 주세요. \(mission.minimumActionCount)회를 채운 뒤에야 완료 확인이 열려요.",
                "Log only real finished actions. The confirm step opens after \(mission.minimumActionCount) logs."
            )
        case .readyToFinalize:
            return localizedCopy(
                "직접 기록 횟수는 모두 채웠어요. 이제 완료 확인을 눌러야 보상이 확정돼요.",
                "The self-logged count is complete. Confirm once more to grant the reward."
            )
        case .completed:
            return localizedCopy(
                "직접 체크와 완료 확인이 모두 끝난 미션이에요.",
                "This mission already finished both self logging and confirmation."
            )
        }
    }
}
