import Foundation

protocol WalkValueGuidePresentationProviding {
    /// 산책 가치 설명 가이드 시트에 바인딩할 프레젠테이션을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 시작 전/진행 중/저장 후 설명을 담은 가이드 프레젠테이션입니다.
    func makePresentation(for context: WalkValueGuideEntryContext) -> WalkValueGuidePresentation
}

final class WalkValueGuidePresentationService: WalkValueGuidePresentationProviding {
    /// 산책 가치 설명 가이드 시트에 바인딩할 프레젠테이션을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 시작 전/진행 중/저장 후 설명을 담은 가이드 프레젠테이션입니다.
    func makePresentation(for context: WalkValueGuideEntryContext) -> WalkValueGuidePresentation {
        WalkValueGuidePresentation(
            context: context,
            badgeText: badgeText(for: context),
            title: title(for: context),
            subtitle: subtitle(for: context),
            heroLine: "산책을 시작하면 경로, 영역, 시간 기록이 쌓이고 저장 후에는 목록·목표·미션 해석으로 이어집니다.",
            flowSteps: flowSteps(),
            compactPolicyLine: "시작 전과 진행 중에는 짧은 helper를 항상 보여주고, 저장 직후에는 다음에 볼 곳을 카드로 다시 알려드립니다.",
            revisitLine: "지도 시작 카드의 설명 보기 버튼에서 언제든 다시 열 수 있어요."
        )
    }

    /// 가이드 상단 배지 문구를 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 현재 가이드 진입 위치를 설명하는 짧은 배지 문구입니다.
    private func badgeText(for context: WalkValueGuideEntryContext) -> String {
        switch context {
        case .firstWalkVisit:
            return "첫 산책 가이드"
        case .mapHelperReentry:
            return "설명 다시 보기"
        }
    }

    /// 가이드 시트 제목을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 산책 가치 설명의 핵심을 보여주는 제목 문자열입니다.
    private func title(for context: WalkValueGuideEntryContext) -> String {
        switch context {
        case .firstWalkVisit:
            return "산책을 시작하면 무엇이 남는지 먼저 알려드릴게요"
        case .mapHelperReentry:
            return "산책 기록이 어떻게 이어지는지 다시 볼게요"
        }
    }

    /// 가이드 시트 부제목을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 시작 전, 진행 중, 저장 후 흐름을 요약하는 보조 설명입니다.
    private func subtitle(for context: WalkValueGuideEntryContext) -> String {
        switch context {
        case .firstWalkVisit:
            return "산책을 누르기 전부터 저장 후 어디서 다시 보는지까지, 한 번에 이해할 수 있게 정리했어요."
        case .mapHelperReentry:
            return "지도 helper, 산책 종료 화면, 목록/상세 설명이 같은 구조로 이어집니다."
        }
    }

    /// 산책 가치 설명의 3단계 흐름을 생성합니다.
    /// - Returns: 시작 전, 진행 중, 저장 후 단계를 순서대로 담은 프레젠테이션 배열입니다.
    private func flowSteps() -> [WalkValueGuideFlowStepPresentation] {
        [
            WalkValueGuideFlowStepPresentation(
                id: "before",
                badgeText: "시작 전",
                title: "경로·영역·시간이 기록돼요",
                body: "산책을 시작하면 어디를 걸었는지, 얼마나 오래 걸었는지, 얼마나 넓혔는지가 한 세션으로 묶여 저장 준비를 시작합니다."
            ),
            WalkValueGuideFlowStepPresentation(
                id: "during",
                badgeText: "진행 중",
                title: "지금 쌓이는 기록을 현재형으로 보여줘요",
                body: "산책 중 카드에서 시간, 영역, 포인트 수를 보며 지금 무엇이 기록되고 있는지 바로 이해할 수 있어요."
            ),
            WalkValueGuideFlowStepPresentation(
                id: "after",
                badgeText: "저장 후",
                title: "목록·목표·미션으로 이어져요",
                body: "저장한 산책은 목록과 상세에서 다시 볼 수 있고, 영역 목표와 오늘 행동 해석에도 같은 기록이 반영됩니다."
            )
        ]
    }
}
