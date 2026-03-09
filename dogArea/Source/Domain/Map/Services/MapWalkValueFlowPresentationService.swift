import Foundation

protocol MapWalkTopHUDPresenting {
    /// safe area 아래 slim HUD에서 사용할 산책 상태 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    ///   - hasCompetingTopChrome: 배너/상세 카드 등 상단 chrome 경쟁 요소 존재 여부입니다.
    /// - Returns: 상단 slim HUD 렌더링에 사용할 프레젠테이션입니다.
    func makePresentation(
        petName: String,
        routePointCount: Int,
        areaText: String,
        hasCompetingTopChrome: Bool
    ) -> MapWalkTopHUDPresentation
}

protocol MapWalkValueFlowPresenting {
    /// 산책 진행 중 helper 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - durationText: 현재까지 누적된 산책 시간 문자열입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    /// - Returns: 진행 중 현재형 설명 카드에 사용할 프레젠테이션입니다.
    func makeActiveValuePresentation(
        petName: String,
        routePointCount: Int,
        durationText: String,
        areaText: String
    ) -> MapWalkActiveValuePresentation

    /// 산책 저장 직후 후속 행동 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 저장한 산책에 연결된 반려견 이름입니다.
    ///   - pointCount: 저장한 세션의 포인트 수입니다.
    ///   - areaText: 저장한 세션의 영역 문자열입니다.
    /// - Returns: 저장 후 무엇을 다시 볼지 설명하는 후속 카드 프레젠테이션입니다.
    func makeSavedOutcomePresentation(
        petName: String,
        pointCount: Int,
        areaText: String
    ) -> MapWalkSavedOutcomePresentation

    /// 산책 종료 직전 확인 시트에서 사용할 가치 설명 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 종료할 산책에 연결된 반려견 이름입니다.
    ///   - durationText: 종료할 산책의 시간 문자열입니다.
    ///   - areaText: 종료할 산책의 영역 문자열입니다.
    ///   - pointCount: 종료할 산책의 포인트 수입니다.
    /// - Returns: 저장 후 이어질 결과를 설명하는 확인 카드 프레젠테이션입니다.
    func makeCompletionValuePresentation(
        petName: String,
        durationText: String,
        areaText: String,
        pointCount: Int
    ) -> WalkCompletionValuePresentation
}

struct MapWalkTopHUDPresentationService: MapWalkTopHUDPresenting {
    /// safe area 아래 slim HUD에서 사용할 산책 상태 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    ///   - hasCompetingTopChrome: 배너/상세 카드 등 상단 chrome 경쟁 요소 존재 여부입니다.
    /// - Returns: 상단 slim HUD 렌더링에 사용할 프레젠테이션입니다.
    func makePresentation(
        petName: String,
        routePointCount: Int,
        areaText: String,
        hasCompetingTopChrome: Bool
    ) -> MapWalkTopHUDPresentation {
        let resolvedPetName = petName.isEmpty ? "현재 반려견" : petName
        return MapWalkTopHUDPresentation(
            title: "\(resolvedPetName)와 산책 중",
            statusText: hasCompetingTopChrome ? "기록 상태" : "경로·영역·포인트를 계속 누적하고 있어요",
            metrics: [
                .init(id: "duration", title: "시간", value: "0분"),
                .init(id: "area", title: "영역", value: areaText),
                .init(id: "points", title: "포인트", value: "\(routePointCount)개")
            ],
            displayMode: hasCompetingTopChrome ? .compact : .regular,
            guideAffordanceTitle: hasCompetingTopChrome ? nil : "설명 보기"
        )
    }
}

struct MapWalkValueFlowPresentationService: MapWalkValueFlowPresenting {
    /// 산책 진행 중 helper 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - durationText: 현재까지 누적된 산책 시간 문자열입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    /// - Returns: 진행 중 현재형 설명 카드에 사용할 프레젠테이션입니다.
    func makeActiveValuePresentation(
        petName: String,
        routePointCount: Int,
        durationText: String,
        areaText: String
    ) -> MapWalkActiveValuePresentation {
        MapWalkActiveValuePresentation(
            title: "지금 \(petName)와 산책 기록을 쌓는 중이에요",
            summary: "경로와 시간은 계속 누적되고, 포인트를 더할수록 영역 기록도 또렷해집니다.",
            metrics: [
                .init(id: "duration", title: "시간", value: durationText),
                .init(id: "area", title: "영역", value: areaText),
                .init(id: "points", title: "포인트", value: "\(routePointCount)개")
            ],
            footer: "마칠 때 저장하면 이 세션이 목록, 목표, 미션 해석으로 이어집니다."
        )
    }

    /// 산책 저장 직후 후속 행동 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 저장한 산책에 연결된 반려견 이름입니다.
    ///   - pointCount: 저장한 세션의 포인트 수입니다.
    ///   - areaText: 저장한 세션의 영역 문자열입니다.
    /// - Returns: 저장 후 무엇을 다시 볼지 설명하는 후속 카드 프레젠테이션입니다.
    func makeSavedOutcomePresentation(
        petName: String,
        pointCount: Int,
        areaText: String
    ) -> MapWalkSavedOutcomePresentation {
        MapWalkSavedOutcomePresentation(
            title: "이번 산책이 기록으로 저장됐어요",
            summary: "\(petName)와 남긴 \(pointCount)개 포인트, \(areaText) 영역 기록을 이제 다른 화면에서도 이어서 볼 수 있어요.",
            followUpItems: [
                .init(id: "history", title: "목록에서 다시 보기", body: "방금 저장한 산책을 기록 목록과 상세에서 다시 읽을 수 있어요."),
                .init(id: "goal", title: "목표 반영 확인", body: "영역 목표와 시즌 해석은 방금 저장한 기록을 기준으로 갱신됩니다."),
                .init(id: "mission", title: "미션 진행 연결", body: "산책 기반 미션과 오늘 행동 해석에도 같은 기록이 이어집니다.")
            ],
            primaryActionTitle: "목록에서 보기"
        )
    }

    /// 산책 종료 직전 확인 시트에서 사용할 가치 설명 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 종료할 산책에 연결된 반려견 이름입니다.
    ///   - durationText: 종료할 산책의 시간 문자열입니다.
    ///   - areaText: 종료할 산책의 영역 문자열입니다.
    ///   - pointCount: 종료할 산책의 포인트 수입니다.
    /// - Returns: 저장 후 이어질 결과를 설명하는 확인 카드 프레젠테이션입니다.
    func makeCompletionValuePresentation(
        petName: String,
        durationText: String,
        areaText: String,
        pointCount: Int
    ) -> WalkCompletionValuePresentation {
        WalkCompletionValuePresentation(
            title: "저장하면 무엇이 남는지 확인하고 마칠게요",
            summary: "이번 산책은 \(petName) 기준 기록으로 저장되고, 경로·영역·시간이 한 세션으로 남습니다.",
            items: [
                .init(id: "session", title: "저장될 기록", body: "시간 \(durationText), 영역 \(areaText), 포인트 \(pointCount)개가 한 번의 산책으로 저장됩니다."),
                .init(id: "history", title: "다시 볼 곳", body: "산책 목록과 상세에서 방금 세션을 다시 볼 수 있어요."),
                .init(id: "systems", title: "이어지는 결과", body: "홈 목표, 미션 진행, 시즌 해석이 이 기록을 기준으로 연결됩니다.")
            ],
            footnote: "사진 저장과 공유는 보조 흐름이고, 이 화면의 핵심 행동은 산책 기록 저장입니다."
        )
    }
}
