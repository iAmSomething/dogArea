import Foundation

struct WalkListCalendarDayCellModel: Identifiable {
    let id: String
    let date: Date?
    let dayText: String
    let walkCount: Int
    let accessibilityIdentifier: String?
    let accessibilityLabel: String
    let isInteractive: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
}

struct WalkListCalendarPresentationModel {
    let monthTitle: String
    let helperMessage: String
    let weekdaySymbols: [String]
    let dayCells: [WalkListCalendarDayCellModel]
    let selectionSummary: String?
    let clearSelectionTitle: String?
    let emptyTitle: String?
    let emptyMessage: String?

    var isEmptyState: Bool {
        emptyTitle != nil && emptyMessage != nil
    }

    static let placeholder = WalkListCalendarPresentationModel(
        monthTitle: "이번 달 산책 캘린더",
        helperMessage: "날짜를 누르면 그날의 산책 기록만 바로 좁혀서 볼 수 있어요.",
        weekdaySymbols: ["일", "월", "화", "수", "목", "금", "토"],
        dayCells: [],
        selectionSummary: nil,
        clearSelectionTitle: nil,
        emptyTitle: nil,
        emptyMessage: nil
    )
}

struct WalkListCalendarSnapshot {
    let model: WalkListCalendarPresentationModel
    let recordsByDayStart: [TimeInterval: [WalkDataModel]]
}
