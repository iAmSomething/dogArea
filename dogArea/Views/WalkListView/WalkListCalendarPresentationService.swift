import Foundation

protocol WalkListCalendarPresentationServicing {
    /// 현재 산책 범위와 선택 상태를 기반으로 월별 캘린더 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - records: 현재 반려견/전체 기준으로 스코프가 정해진 산책 기록입니다.
    ///   - displayedMonth: 화면에 렌더링할 월 기준 날짜입니다.
    ///   - selectedDate: 사용자가 선택한 날짜의 `startOfDay`입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 로컬 캘린더입니다.
    /// - Returns: 월 캘린더 표현 모델과 날짜별 기록 매핑입니다.
    func makeSnapshot(
        records: [WalkDataModel],
        displayedMonth: Date,
        selectedDate: Date?,
        calendar: Calendar
    ) -> WalkListCalendarSnapshot

    /// 월 캘린더가 사용할 기준 월 시작 시각을 계산합니다.
    /// - Parameters:
    ///   - records: 현재 범위에 속한 산책 기록입니다.
    ///   - reference: 현재 시각 기준 참조 날짜입니다.
    ///   - calendar: 월 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 캘린더가 처음 보여줄 월의 시작 시각입니다.
    func recommendedDisplayedMonth(records: [WalkDataModel], reference: Date, calendar: Calendar) -> Date

    /// 월 이동 버튼에 맞춰 다음/이전 월의 시작 시각을 계산합니다.
    /// - Parameters:
    ///   - month: 현재 표시 중인 월의 시작 시각입니다.
    ///   - value: 이동할 월 단위 offset입니다.
    ///   - calendar: 월 덧셈 계산에 사용할 캘린더입니다.
    /// - Returns: 이동 후 월의 시작 시각입니다.
    func shiftedMonth(from month: Date, by value: Int, calendar: Calendar) -> Date
}

struct WalkListCalendarPresentationService: WalkListCalendarPresentationServicing {
    private let weeklyStatisticsService: HomeWeeklyStatisticsServicing

    init(weeklyStatisticsService: HomeWeeklyStatisticsServicing = HomeWeeklyStatisticsService()) {
        self.weeklyStatisticsService = weeklyStatisticsService
    }

    /// 현재 산책 범위와 선택 상태를 기반으로 월별 캘린더 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - records: 현재 반려견/전체 기준으로 스코프가 정해진 산책 기록입니다.
    ///   - displayedMonth: 화면에 렌더링할 월 기준 날짜입니다.
    ///   - selectedDate: 사용자가 선택한 날짜의 `startOfDay`입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 로컬 캘린더입니다.
    /// - Returns: 월 캘린더 표현 모델과 날짜별 기록 매핑입니다.
    func makeSnapshot(
        records: [WalkDataModel],
        displayedMonth: Date,
        selectedDate: Date?,
        calendar: Calendar
    ) -> WalkListCalendarSnapshot {
        let monthStart = normalizedMonth(for: displayedMonth, calendar: calendar)
        let recordsByDayStart = makeRecordsByDayStart(records: records, calendar: calendar)
        let monthTitle = monthTitle(for: monthStart, calendar: calendar)
        let weekdaySymbols = orderedWeekdaySymbols(calendar: calendar)

        guard records.isEmpty == false else {
            return WalkListCalendarSnapshot(
                model: WalkListCalendarPresentationModel(
                    monthTitle: monthTitle,
                    helperMessage: "첫 산책을 저장하면 날짜에 점과 숫자가 채워져요.",
                    weekdaySymbols: weekdaySymbols,
                    dayCells: [],
                    selectionSummary: nil,
                    clearSelectionTitle: nil,
                    emptyTitle: "아직 표시할 산책 날짜가 없어요",
                    emptyMessage: "첫 산책을 시작하면 이 달력에 산책한 날짜가 채워지고, 날짜를 눌러 바로 그날 기록만 볼 수 있어요."
                ),
                recordsByDayStart: recordsByDayStart
            )
        }

        let dayCells = makeDayCells(
            monthStart: monthStart,
            selectedDate: selectedDate,
            recordsByDayStart: recordsByDayStart,
            calendar: calendar
        )
        let monthHasMarkedDay = dayCells.contains { $0.walkCount > 0 }
        let helperMessage: String
        if selectedDate != nil {
            helperMessage = "같은 날짜를 한 번 더 누르거나 월 전체 보기로 돌아가면 전체 목록을 다시 볼 수 있어요."
        } else if monthHasMarkedDay {
            helperMessage = "산책한 날에는 점이, 두 번 이상 걸은 날에는 숫자 배지가 표시돼요. 날짜를 누르면 그날 기록만 바로 좁혀서 볼 수 있어요."
        } else {
            helperMessage = "이 달에는 표시할 산책이 없어요. 월을 바꾸면 이전 산책 리듬도 바로 훑어볼 수 있어요."
        }

        return WalkListCalendarSnapshot(
            model: WalkListCalendarPresentationModel(
                monthTitle: monthTitle,
                helperMessage: helperMessage,
                weekdaySymbols: weekdaySymbols,
                dayCells: dayCells,
                selectionSummary: selectedDate.flatMap { selectionSummary(for: $0, recordsByDayStart: recordsByDayStart, calendar: calendar) },
                clearSelectionTitle: selectedDate == nil ? nil : "월 전체 보기",
                emptyTitle: nil,
                emptyMessage: nil
            ),
            recordsByDayStart: recordsByDayStart
        )
    }

    /// 월 캘린더가 사용할 기준 월 시작 시각을 계산합니다.
    /// - Parameters:
    ///   - records: 현재 범위에 속한 산책 기록입니다.
    ///   - reference: 현재 시각 기준 참조 날짜입니다.
    ///   - calendar: 월 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 캘린더가 처음 보여줄 월의 시작 시각입니다.
    func recommendedDisplayedMonth(records: [WalkDataModel], reference: Date, calendar: Calendar) -> Date {
        let referenceMonth = normalizedMonth(for: reference, calendar: calendar)
        guard records.isEmpty == false else {
            return referenceMonth
        }

        let recordsByDayStart = makeRecordsByDayStart(records: records, calendar: calendar)
        if monthContainsMarkedDay(monthStart: referenceMonth, recordsByDayStart: recordsByDayStart, calendar: calendar) {
            return referenceMonth
        }

        let latestRecordDate = records
            .map { Date(timeIntervalSince1970: $0.createdAt) }
            .max() ?? reference
        return normalizedMonth(for: latestRecordDate, calendar: calendar)
    }

    /// 월 이동 버튼에 맞춰 다음/이전 월의 시작 시각을 계산합니다.
    /// - Parameters:
    ///   - month: 현재 표시 중인 월의 시작 시각입니다.
    ///   - value: 이동할 월 단위 offset입니다.
    ///   - calendar: 월 덧셈 계산에 사용할 캘린더입니다.
    /// - Returns: 이동 후 월의 시작 시각입니다.
    func shiftedMonth(from month: Date, by value: Int, calendar: Calendar) -> Date {
        let normalized = normalizedMonth(for: month, calendar: calendar)
        let shifted = calendar.date(byAdding: .month, value: value, to: normalized) ?? normalized
        return normalizedMonth(for: shifted, calendar: calendar)
    }

    /// 기준 월의 각 날짜 셀 모델을 생성합니다.
    /// - Parameters:
    ///   - monthStart: 렌더링할 월의 시작 시각입니다.
    ///   - selectedDate: 선택된 날짜의 `startOfDay`입니다.
    ///   - recordsByDayStart: 날짜 시작 시각별 산책 기록 매핑입니다.
    ///   - calendar: 날짜 계산에 사용할 캘린더입니다.
    /// - Returns: placeholder를 포함한 월 그리드 셀 모델 배열입니다.
    private func makeDayCells(
        monthStart: Date,
        selectedDate: Date?,
        recordsByDayStart: [TimeInterval: [WalkDataModel]],
        calendar: Calendar
    ) -> [WalkListCalendarDayCellModel] {
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [WalkListCalendarDayCellModel] = (0..<offset).map { _ in placeholderDayCellModel() }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let coveredRecords = recordsByDayStart[dayStart.timeIntervalSince1970] ?? []
            let identifierDate = dayIdentifier(for: dayStart, calendar: calendar)
            cells.append(
                WalkListCalendarDayCellModel(
                    id: identifierDate,
                    date: dayStart,
                    dayText: "\(day)",
                    walkCount: coveredRecords.count,
                    accessibilityIdentifier: "walklist.calendar.day.\(identifierDate)",
                    accessibilityLabel: accessibilityLabel(for: dayStart, count: coveredRecords.count, calendar: calendar),
                    isInteractive: coveredRecords.isEmpty == false,
                    isCurrentMonth: true,
                    isToday: calendar.isDateInToday(dayStart),
                    isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: dayStart) } ?? false
                )
            )
        }

        let trailingCount = cells.count % 7 == 0 ? 0 : 7 - (cells.count % 7)
        cells.append(contentsOf: (0..<trailingCount).map { _ in placeholderDayCellModel() })
        return cells
    }

    /// 월 시작 시각과 날짜별 기록 매핑을 기준으로 현재 월에 표시할 기록이 있는지 판단합니다.
    /// - Parameters:
    ///   - monthStart: 검사할 월의 시작 시각입니다.
    ///   - recordsByDayStart: 날짜 시작 시각별 산책 기록 매핑입니다.
    ///   - calendar: 월 종료 계산에 사용할 캘린더입니다.
    /// - Returns: 해당 월에 마킹할 날짜가 하나 이상 있으면 `true`입니다.
    private func monthContainsMarkedDay(
        monthStart: Date,
        recordsByDayStart: [TimeInterval: [WalkDataModel]],
        calendar: Calendar
    ) -> Bool {
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return false
        }
        return recordsByDayStart.keys.contains { key in
            let day = Date(timeIntervalSince1970: key)
            return day >= monthStart && day < monthEnd
        }
    }

    /// 반려견 스코프 기준 산책 기록을 날짜 시작 시각별로 집계합니다.
    /// - Parameters:
    ///   - records: 현재 화면 범위에 속한 산책 기록입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: `startOfDay` timestamp를 키로 갖는 산책 기록 배열 매핑입니다.
    private func makeRecordsByDayStart(
        records: [WalkDataModel],
        calendar: Calendar
    ) -> [TimeInterval: [WalkDataModel]] {
        var recordsByDayStart: [TimeInterval: [WalkDataModel]] = [:]
        for record in records.sorted(by: { $0.createdAt > $1.createdAt }) {
            for dayStart in weeklyStatisticsService.dayStartsCovered(by: record.toPolygon(), calendar: calendar) {
                recordsByDayStart[dayStart.timeIntervalSince1970, default: []].append(record)
            }
        }
        return recordsByDayStart
    }

    /// 달력 선택 상태에 표시할 요약 문구를 생성합니다.
    /// - Parameters:
    ///   - date: 현재 선택된 날짜의 `startOfDay`입니다.
    ///   - recordsByDayStart: 날짜 시작 시각별 산책 기록 매핑입니다.
    ///   - calendar: 날짜 포맷 계산에 사용할 캘린더입니다.
    /// - Returns: 선택 날짜와 그날에 걸친 세션 수를 설명하는 문구입니다.
    private func selectionSummary(
        for date: Date,
        recordsByDayStart: [TimeInterval: [WalkDataModel]],
        calendar: Calendar
    ) -> String {
        let count = recordsByDayStart[date.timeIntervalSince1970]?.count ?? 0
        return "\(selectionTitle(for: date, calendar: calendar))에 걸친 산책 \(count)건만 보고 있어요."
    }

    /// 월 타이틀 문자열을 생성합니다.
    /// - Parameters:
    ///   - month: 표시할 월의 시작 시각입니다.
    ///   - calendar: 포맷 계산에 사용할 캘린더입니다.
    /// - Returns: `yyyy년 M월` 형식의 문자열입니다.
    private func monthTitle(for month: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: month)
    }

    /// 선택 날짜 타이틀 문자열을 생성합니다.
    /// - Parameters:
    ///   - date: 선택된 날짜의 시작 시각입니다.
    ///   - calendar: 포맷 계산에 사용할 캘린더입니다.
    /// - Returns: `M월 d일 (E)` 형식의 문자열입니다.
    private func selectionTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }

    /// 날짜 셀 접근성 라벨을 생성합니다.
    /// - Parameters:
    ///   - date: 접근성 라벨을 생성할 날짜입니다.
    ///   - count: 해당 날짜에 걸친 세션 수입니다.
    ///   - calendar: 포맷 계산에 사용할 캘린더입니다.
    /// - Returns: 날짜와 기록 수를 함께 설명하는 접근성 문자열입니다.
    private func accessibilityLabel(for date: Date, count: Int, calendar: Calendar) -> String {
        let title = selectionTitle(for: date, calendar: calendar)
        if count <= 0 {
            return "\(title), 산책 기록 없음"
        }
        return "\(title), 산책 \(count)건"
    }

    /// 날짜 셀 식별자에 사용할 `yyyy-MM-dd` 문자열을 생성합니다.
    /// - Parameters:
    ///   - date: 식별자 문자열을 만들 날짜입니다.
    ///   - calendar: 포맷 계산에 사용할 캘린더입니다.
    /// - Returns: 접근성 식별자에 안전하게 사용할 날짜 문자열입니다.
    private func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 현재 캘린더 첫 요일 기준으로 weekday 심볼을 재정렬합니다.
    /// - Parameter calendar: 요일 시작 규칙을 가진 캘린더입니다.
    /// - Returns: 현재 첫 요일부터 시작하는 매우 짧은 요일 심볼 배열입니다.
    private func orderedWeekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return (0..<7).map { offset in
            symbols[(calendar.firstWeekday - 1 + offset) % 7]
        }
    }

    /// 날짜가 속한 월의 시작 시각을 계산합니다.
    /// - Parameters:
    ///   - date: 월 기준으로 정규화할 날짜입니다.
    ///   - calendar: 월 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 해당 월 1일 00:00 시각입니다.
    private func normalizedMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// placeholder용 빈 날짜 셀 모델을 생성합니다.
    /// - Returns: 레이아웃 정렬용 비어 있는 날짜 셀 모델입니다.
    private func placeholderDayCellModel() -> WalkListCalendarDayCellModel {
        WalkListCalendarDayCellModel(
            id: UUID().uuidString,
            date: nil,
            dayText: "",
            walkCount: 0,
            accessibilityIdentifier: nil,
            accessibilityLabel: "",
            isInteractive: false,
            isCurrentMonth: false,
            isToday: false,
            isSelected: false
        )
    }
}
