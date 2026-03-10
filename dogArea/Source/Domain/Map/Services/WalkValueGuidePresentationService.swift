import Foundation

protocol WalkValueGuidePresentationProviding {
    /// 산책 가치 설명 가이드 시트에 바인딩할 프레젠테이션을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 첫 산책 이해 Step1과 핵심 설정 Step2를 담은 가이드 프레젠테이션입니다.
    func makePresentation(for context: WalkValueGuideEntryContext) -> WalkValueGuidePresentation
}

final class WalkValueGuidePresentationService: WalkValueGuidePresentationProviding {
    /// 산책 가치 설명 가이드 시트에 바인딩할 프레젠테이션을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 첫 산책 이해 Step1과 핵심 설정 Step2를 담은 가이드 프레젠테이션입니다.
    func makePresentation(for context: WalkValueGuideEntryContext) -> WalkValueGuidePresentation {
        WalkValueGuidePresentation(
            context: context,
            badgeText: badgeText(for: context),
            title: title(for: context),
            subtitle: subtitle(for: context),
            understandingCards: understandingCards(),
            stepTwoTitle: "이제 시작 전에 딱 두 가지만 정할게요",
            stepTwoSubtitle: "기록 방식은 바로 저장되고, 공유는 안전하게 비공개로 시작해요.",
            recordModeOptions: recordModeOptions(),
            defaultPointRecordModeRawValue: "manual",
            recordModeFootnote: "처음에는 수동이 더 예측 가능해요.",
            sharingDefaultTitle: "공유는 기본적으로 비공개로 시작해요",
            sharingDefaultBody: "공유 기능은 동의 후에만 켤 수 있고, 권한 요청도 실제로 공유를 시작할 때 따로 안내돼요.",
            sharingDefaultFootnote: "나중에 설정 탭의 프라이버시 센터에서 다시 바꿀 수 있어요.",
            revisitLine: "지도 도움말과 설정 탭에서 언제든 다시 열 수 있어요."
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
            return "지도에서 다시 보기"
        case .settingsReentry:
            return "설정에서 다시 보기"
        }
    }

    /// 가이드 시트 제목을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: 산책 기본 루프를 설명하는 제목 문자열입니다.
    private func title(for context: WalkValueGuideEntryContext) -> String {
        switch context {
        case .firstWalkVisit:
            return "첫 산책 전에 이것만 보면 돼요"
        case .mapHelperReentry:
            return "산책 기록이 어디로 이어지는지 다시 볼게요"
        case .settingsReentry:
            return "설정에서 첫 산책 흐름을 다시 확인할게요"
        }
    }

    /// 가이드 시트 부제목을 생성합니다.
    /// - Parameter context: 사용자가 가이드를 연 진입 맥락입니다.
    /// - Returns: Step1과 Step2의 목적을 짧게 요약한 설명 문자열입니다.
    private func subtitle(for context: WalkValueGuideEntryContext) -> String {
        switch context {
        case .firstWalkVisit:
            return "산책 기록이 어디로 이어지는지 먼저 이해하고, 핵심 설정은 짧게 정할게요."
        case .mapHelperReentry:
            return "기록 -> 영역 -> 시즌 -> 미션 순서와 기본 설정을 다시 확인할 수 있어요."
        case .settingsReentry:
            return "설정 값을 바꾸기 전에 이 앱의 기본 산책 루프를 다시 정리해드릴게요."
        }
    }

    /// Step1에서 노출할 핵심 이해 카드 4장을 생성합니다.
    /// - Returns: 기록, 영역, 시즌, 미션 순서를 유지한 카드 배열입니다.
    private func understandingCards() -> [WalkValueGuideUnderstandingCardPresentation] {
        [
            WalkValueGuideUnderstandingCardPresentation(
                id: "record",
                badgeText: "1. 기록",
                title: "산책을 시작하면 경로와 시간이 기록돼요",
                body: "이동 경로, 산책 시간, 포인트가 한 번의 산책 기록으로 쌓여요."
            ),
            WalkValueGuideUnderstandingCardPresentation(
                id: "territory",
                badgeText: "2. 영역",
                title: "기록은 우리집 영역으로 이어져요",
                body: "저장한 산책이 홈 목표와 다음 영역 계산에 바로 이어져요."
            ),
            WalkValueGuideUnderstandingCardPresentation(
                id: "season",
                badgeText: "3. 시즌",
                title: "자주 걷는 칸일수록 시즌 지도에 더 또렷하게 남아요",
                body: "시즌은 별도 게임이 아니라 산책 기록이 누적된 결과예요."
            ),
            WalkValueGuideUnderstandingCardPresentation(
                id: "mission",
                badgeText: "4. 미션",
                title: "미션은 산책 위에 얹히는 보조 흐름이에요",
                body: "기본은 산책 기록이고, 미션은 그 위에서 추가 보상과 행동 해석을 더해줘요."
            )
        ]
    }

    /// Step2에서 사용할 기록 방식 옵션을 생성합니다.
    /// - Returns: 수동/자동 포인트 기록 옵션 배열입니다.
    private func recordModeOptions() -> [WalkValueGuideRecordModeOptionPresentation] {
        [
            WalkValueGuideRecordModeOptionPresentation(
                id: "manual",
                title: "수동으로 포인트 남기기",
                body: "필요할 때만 직접 찍어 영역을 남겨요."
            ),
            WalkValueGuideRecordModeOptionPresentation(
                id: "auto",
                title: "걸을 때 자동으로 포인트 남기기",
                body: "걷는 동안 포인트가 자동으로 쌓여요."
            )
        ]
    }
}
