import Foundation

enum WalkListCalendarSemanticTone: String {
    case weekday
    case saturday
    case sunday
    case holiday
}

struct WalkListCalendarWeekdayHeaderModel: Identifiable {
    let id: String
    let symbol: String
    let tone: WalkListCalendarSemanticTone
    let accessibilityIdentifier: String
    let accessibilityLabel: String
}

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
    let semanticTone: WalkListCalendarSemanticTone
    let holidayName: String?
}

struct WalkListCalendarPresentationModel {
    let monthTitle: String
    let helperMessage: String
    let weekdayHeaders: [WalkListCalendarWeekdayHeaderModel]
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
        weekdayHeaders: [
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.1",
                symbol: "일",
                tone: .sunday,
                accessibilityIdentifier: "walklist.calendar.weekday.1",
                accessibilityLabel: "일요일, 주말 강조"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.2",
                symbol: "월",
                tone: .weekday,
                accessibilityIdentifier: "walklist.calendar.weekday.2",
                accessibilityLabel: "월요일"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.3",
                symbol: "화",
                tone: .weekday,
                accessibilityIdentifier: "walklist.calendar.weekday.3",
                accessibilityLabel: "화요일"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.4",
                symbol: "수",
                tone: .weekday,
                accessibilityIdentifier: "walklist.calendar.weekday.4",
                accessibilityLabel: "수요일"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.5",
                symbol: "목",
                tone: .weekday,
                accessibilityIdentifier: "walklist.calendar.weekday.5",
                accessibilityLabel: "목요일"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.6",
                symbol: "금",
                tone: .weekday,
                accessibilityIdentifier: "walklist.calendar.weekday.6",
                accessibilityLabel: "금요일"
            ),
            WalkListCalendarWeekdayHeaderModel(
                id: "walklist.calendar.weekday.7",
                symbol: "토",
                tone: .saturday,
                accessibilityIdentifier: "walklist.calendar.weekday.7",
                accessibilityLabel: "토요일, 주말 강조"
            )
        ],
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
