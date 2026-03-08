import Foundation

protocol SeasonGuidePresentationProviding {
    /// 시즌 시스템을 사용자 언어로 설명하는 가이드 시트 데이터를 만듭니다.
    /// - Parameter context: 사용자가 이 가이드를 연 진입 맥락입니다.
    /// - Returns: 시즌 설명 시트에 바로 바인딩할 프레젠테이션 데이터입니다.
    func makePresentation(for context: SeasonGuideEntryContext) -> SeasonGuidePresentation
}

final class SeasonGuidePresentationService: SeasonGuidePresentationProviding {
    /// 시즌 시스템을 사용자 언어로 설명하는 가이드 시트 데이터를 만듭니다.
    /// - Parameter context: 사용자가 이 가이드를 연 진입 맥락입니다.
    /// - Returns: 시즌 설명 시트에 바로 바인딩할 프레젠테이션 데이터입니다.
    func makePresentation(for context: SeasonGuideEntryContext) -> SeasonGuidePresentation {
        SeasonGuidePresentation(
            context: context,
            badgeText: badgeText(for: context),
            title: title(for: context),
            subtitle: subtitle(for: context),
            heroLine: "산책 경로가 작은 칸 단위로 반영되고, 새로운 칸을 넓히거나 이미 넓힌 칸을 지키면서 시즌 점수를 쌓아요.",
            conceptItems: conceptItems(),
            flowSteps: flowSteps(),
            repeatWalkRuleLine: "같은 자리만 짧은 시간 안에 반복하면 기여가 거의 늘지 않을 수 있어요. 새로운 길을 섞어 걸을수록 시즌 가치가 더 또렷해집니다.",
            revisitLine: "지도 시즌 요약과 홈 시즌 카드의 도움말 버튼에서 언제든 다시 볼 수 있어요."
        )
    }

    /// 가이드 시트 상단에 표시할 맥락 배지를 만듭니다.
    /// - Parameter context: 사용자가 이 가이드를 연 진입 맥락입니다.
    /// - Returns: 진입 위치를 사용자 언어로 요약한 짧은 배지 문구입니다.
    private func badgeText(for context: SeasonGuideEntryContext) -> String {
        switch context {
        case .firstSeasonVisit:
            return "처음 보는 시즌"
        case .mapSummary:
            return "지도에서 다시 보기"
        case .homeSeasonCard:
            return "홈에서 다시 보기"
        }
    }

    /// 진입 맥락에 맞는 가이드 시트 제목을 만듭니다.
    /// - Parameter context: 사용자가 이 가이드를 연 진입 맥락입니다.
    /// - Returns: 시트 상단에 노출할 제목입니다.
    private func title(for context: SeasonGuideEntryContext) -> String {
        switch context {
        case .firstSeasonVisit:
            return "시즌 점령 지도, 이렇게 읽어요"
        case .mapSummary:
            return "지도에서 보는 시즌 점령, 이렇게 쌓여요"
        case .homeSeasonCard:
            return "홈 시즌 점수, 산책과 이렇게 연결돼요"
        }
    }

    /// 진입 맥락에 맞는 가이드 시트 부제목을 만듭니다.
    /// - Parameter context: 사용자가 이 가이드를 연 진입 맥락입니다.
    /// - Returns: 제목 아래에 노출할 보조 설명 문구입니다.
    private func subtitle(for context: SeasonGuideEntryContext) -> String {
        switch context {
        case .firstSeasonVisit:
            return "산책이 어떻게 타일, 점령, 유지, 점수로 이어지는지 한 번에 정리했어요."
        case .mapSummary:
            return "지금 보이는 타일 색과 테두리가 어떤 행동을 뜻하는지 짧게 읽을 수 있어요."
        case .homeSeasonCard:
            return "홈에 보이는 시즌 점수와 랭크가 어떤 산책 행동에서 생기는지 알려드릴게요."
        }
    }

    /// 시즌 핵심 개념 카드 목록을 만듭니다.
    /// - Returns: 타일/점령/유지/신규 칸 가치 설명 카드 배열입니다.
    private func conceptItems() -> [SeasonGuideConceptPresentation] {
        [
            SeasonGuideConceptPresentation(
                id: "tile",
                iconName: "square.grid.3x3.fill",
                title: "시즌 타일",
                body: "지도 위 작은 칸 하나가 산책 기여 단위예요. 어떤 칸을 넓혔는지, 어느 칸을 지키고 있는지 이 기준으로 읽습니다."
            ),
            SeasonGuideConceptPresentation(
                id: "occupied",
                iconName: "flag.checkered.2.crossed",
                title: "점령",
                body: "처음 가는 칸을 넓히면 굵은 테두리로 바뀌고, 시즌 점수와 랭크에 더 큰 기여로 반영돼요."
            ),
            SeasonGuideConceptPresentation(
                id: "maintained",
                iconName: "shield.checkered",
                title: "유지",
                body: "이미 넓힌 칸을 다시 걸으면 점선 테두리로 남고, 내가 만든 영역을 지키는 산책으로 쌓여요."
            ),
            SeasonGuideConceptPresentation(
                id: "newTile",
                iconName: "sparkles",
                title: "새 타일 가치",
                body: "새로운 구역을 걸을수록 시즌에 더 또렷한 기여가 반영돼요. 같은 시간이라도 길의 다양성이 중요합니다."
            )
        ]
    }

    /// 산책에서 시즌 결과까지 이어지는 5단계 흐름을 만듭니다.
    /// - Returns: 사용자 행동-결과 흐름을 보여주는 단계 배열입니다.
    private func flowSteps() -> [SeasonGuideFlowStepPresentation] {
        [
            SeasonGuideFlowStepPresentation(stepNumber: 1, title: "산책 시작", body: "걷기 시작하면 경로가 기록됩니다."),
            SeasonGuideFlowStepPresentation(stepNumber: 2, title: "경로 반영", body: "경로가 시즌 타일과 영역 기여로 정리됩니다."),
            SeasonGuideFlowStepPresentation(stepNumber: 3, title: "새 칸 확장", body: "새로운 칸을 넓히면 점령 기여가 더 크게 쌓여요."),
            SeasonGuideFlowStepPresentation(stepNumber: 4, title: "영역 유지", body: "이미 넓힌 칸을 다시 걸으면 유지 기여가 반영돼요."),
            SeasonGuideFlowStepPresentation(stepNumber: 5, title: "시즌 결과", body: "이 기여가 시즌 점수, 랭크, 결과와 보상으로 이어집니다.")
        ]
    }
}
