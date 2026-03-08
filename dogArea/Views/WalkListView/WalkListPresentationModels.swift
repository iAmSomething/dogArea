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
        subtitle: "산책이 기록으로 쌓이고 다음 행동을 정하는 허브예요.",
        primaryLoopBadge: "기본 행동",
        primaryLoopTitle: "산책이 기록의 시작점이에요",
        primaryLoopMessage: "한 번 저장한 산책은 경로, 영역, 시간 기록이 되어 다시 보는 기준이 됩니다.",
        primaryLoopSecondaryFlowText: "실내 미션은 산책이 어려운 날의 보조 흐름입니다.",
        modeBadge: "전체 기록 기준",
        contextTitle: "최근 산책 기록을 한곳에 모았어요",
        contextMessage: "반려견을 선택하면 해당 기준으로 기록을 바로 좁혀서 볼 수 있어요.",
        helperMessage: "기록이 쌓이면 이번 주와 이전 기록이 자동으로 나뉘어 표시됩니다.",
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
