import Foundation

struct HomeWeatherGuidanceBadgePresentation: Identifiable, Equatable {
    let id: String
    let title: String
}

struct HomeWeatherGuidancePrimaryActionPresentation: Equatable {
    let eyebrow: String
    let title: String
    let body: String
    let emphasisText: String
    let accessibilityText: String
}

enum HomeWeatherGuidanceDecisionFactorTone: String, Equatable {
    case weather
    case pet
    case fallback
}

struct HomeWeatherGuidanceDecisionFactorPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let tone: HomeWeatherGuidanceDecisionFactorTone
}

struct HomeWeatherGuidanceItemPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct HomeWeatherGuidanceSectionPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let items: [HomeWeatherGuidanceItemPresentation]
}

struct HomeWeatherGuidancePresentation: Equatable {
    let title: String
    let subtitle: String
    let observedSummaryText: String
    let primaryActionTitle: String
    let primaryAction: HomeWeatherGuidancePrimaryActionPresentation
    let decisionFactorsTitle: String
    let decisionFactorsSubtitle: String
    let decisionFactors: [HomeWeatherGuidanceDecisionFactorPresentation]
    let profileTitle: String
    let profileBadges: [HomeWeatherGuidanceBadgePresentation]
    let profileFallbackNotice: String?
    let sections: [HomeWeatherGuidanceSectionPresentation]
    let footerText: String
    let accessibilityText: String

    static let placeholder = HomeWeatherGuidancePresentation(
        title: "오늘 산책 가이드",
        subtitle: "날씨와 반려견 상태를 함께 보고 오늘의 산책 방식을 정리해드릴게요.",
        observedSummaryText: "관측값을 준비하는 동안 기본 안전 기준으로 안내해요.",
        primaryActionTitle: "오늘 추천",
        primaryAction: .init(
            eyebrow: "기본 안전 기준",
            title: "짧은 확인 산책부터 시작하세요",
            body: "관측값이 비어 있을 때는 5~10분 확인 산책으로 반응을 보고, 괜찮을 때만 거리를 조금 늘리세요.",
            emphasisText: "짧게 시작",
            accessibilityText: "오늘 추천. 짧은 확인 산책부터 시작하세요. 관측값이 비어 있을 때는 5에서 10분 확인 산책으로 반응을 보고, 괜찮을 때만 거리를 조금 늘리세요."
        ),
        decisionFactorsTitle: "이렇게 판단했어요",
        decisionFactorsSubtitle: "날씨 관측과 반려견 문맥이 부족할 때도 안전한 기준부터 적용합니다.",
        decisionFactors: [
            .init(id: "factor.defaultWeather", title: "관측값 준비 중", tone: .fallback),
            .init(id: "factor.defaultProfile", title: "프로필 보완 전", tone: .fallback),
            .init(id: "factor.defaultBaseline", title: "기본 안전 기준 적용", tone: .fallback)
        ],
        profileTitle: "기본 안전 기준",
        profileBadges: [
            .init(id: "profile.default", title: "프로필 보완 전")
        ],
        profileFallbackNotice: "나이와 견종 정보가 아직 없어 기본 안전 기준으로 정리했어요.",
        sections: [
            .init(
                id: "caution",
                title: "오늘 산책 시 주의",
                subtitle: "데이터가 없을 때도 먼저 확인해야 하는 기본 기준입니다.",
                items: [
                    .init(
                        id: "caution.default.surface",
                        title: "출발 전 노면과 컨디션을 먼저 확인하세요",
                        body: "바닥 온도, 젖은 노면, 떨림·헐떡임 같은 이상 반응이 보이면 바로 산책 시간을 줄이세요."
                    )
                ]
            ),
            .init(
                id: "walkStyle",
                title: "산책 권장 방식",
                subtitle: "무리하지 않고 오늘 컨디션을 확인하는 기본 패턴입니다.",
                items: [
                    .init(
                        id: "walkStyle.default.short",
                        title: "짧게 시작하고 반응을 보세요",
                        body: "처음 5분은 속도를 올리지 말고 걷는 리듬, 호흡, 발걸음을 확인한 뒤 코스를 늘리세요."
                    )
                ]
            ),
            .init(
                id: "indoorAlternative",
                title: "실내 대체 추천",
                subtitle: "실외가 애매할 때 바로 바꿔 탈 수 있는 안전한 대안입니다.",
                items: [
                    .init(
                        id: "indoor.default.routine",
                        title: "실내 루틴을 먼저 준비해두세요",
                        body: "노즈워크, 간단한 기다려 훈련, 짧은 놀이를 준비해두면 날씨가 나쁠 때 바로 대체할 수 있어요."
                    )
                ]
            )
        ],
        footerText: "이 안내는 제품 안전 기준을 정리한 행동 가이드예요. 의료 판단 대신 오늘 산책 방식을 정리하는 용도로 사용해 주세요.",
        accessibilityText: "오늘 산책 가이드. 기본 안전 기준으로 안내합니다."
    )
}
