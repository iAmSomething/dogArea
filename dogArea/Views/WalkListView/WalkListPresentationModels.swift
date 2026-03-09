import Foundation

struct WalkListOverviewMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct WalkListOverviewModel {
    let title: String
    let subtitle: String
    let primaryLoopBadge: String
    let primaryLoopTitle: String
    let primaryLoopMessage: String
    let primaryLoopSecondaryFlowText: String
    let modeBadge: String
    let contextTitle: String
    let contextMessage: String
    let helperMessage: String
    let restoreActionTitle: String?
    let metrics: [WalkListOverviewMetric]

    static let placeholder = WalkListOverviewModel(
        title: "산책 기록",
        subtitle: "산책 기록을 빠르게 훑고 다시 찾는 화면이에요.",
        primaryLoopBadge: "기본 행동",
        primaryLoopTitle: "산책이 기록을 만듭니다",
        primaryLoopMessage: "저장한 산책이 경로, 영역, 시간 기록으로 남습니다.",
        primaryLoopSecondaryFlowText: "실내 미션은 보조 흐름입니다.",
        modeBadge: "전체 기록",
        contextTitle: "기록 기준을 바로 바꿀 수 있어요",
        contextMessage: "반려견을 고르면 같은 기준으로 목록과 달력이 함께 바뀝니다.",
        helperMessage: "기록이 없으면 전체 기록으로 바로 넓혀볼 수 있어요.",
        restoreActionTitle: nil,
        metrics: [
            WalkListOverviewMetric(id: "total", title: "총 기록", value: "0건", detail: "아직 기록이 없어요"),
            WalkListOverviewMetric(id: "weekly", title: "이번 주", value: "0건", detail: "이번 주 기록"),
            WalkListOverviewMetric(id: "area", title: "누적 영역", value: "0㎡", detail: "저장된 영역"),
        ]
    )
}

struct WalkListSectionModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String?
    let items: [WalkListSectionItem]
}

struct WalkListSectionItem: Identifiable {
    let walkData: WalkDataModel
    let petName: String?
    let accessibilityIdentifier: String

    var id: UUID {
        walkData.id
    }
}

struct WalkListStateCardModel {
    let accessibilityIdentifier: String
    let badge: String
    let title: String
    let message: String
    let footnote: String
    let primaryActionTitle: String?
    let symbolName: String
}
