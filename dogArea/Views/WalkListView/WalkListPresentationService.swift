import Foundation

protocol WalkListPresentationServicing {
    /// 산책 목록 상단 허브에 표시할 개요 모델을 생성합니다.
    /// - Parameters:
    ///   - visibleRecords: 현재 필터 기준으로 화면에 노출되는 산책 기록입니다.
    ///   - allRecords: 필터를 적용하기 전 전체 산책 기록입니다.
    ///   - selectedPetName: 현재 선택 반려견 이름입니다.
    ///   - selectedPetId: 현재 선택 반려견 식별자입니다.
    ///   - isShowingAllRecordsOverride: 선택 반려견 기준 대신 전체 기록 보기 모드인지 여부입니다.
    /// - Returns: 상단 허브 카드에 필요한 문맥/메트릭을 담은 개요 모델입니다.
    func makeOverview(
        visibleRecords: [WalkDataModel],
        allRecords: [WalkDataModel],
        selectedPetName: String,
        selectedPetId: String,
        isShowingAllRecordsOverride: Bool
    ) -> WalkListOverviewModel

    /// 현재 필터 기준 기록을 주간 섹션 구조로 분리합니다.
    /// - Parameters:
    ///   - visibleRecords: 현재 화면에 보여줄 산책 기록입니다.
    ///   - petNameById: 반려견 식별자별 이름 매핑입니다.
    ///   - selectedCalendarDate: 현재 선택된 날짜의 `startOfDay`입니다.
    ///   - calendar: 날짜 섹션 타이틀 계산에 사용할 로컬 캘린더입니다.
    /// - Returns: 이번 주/이전 기록으로 분류된 섹션 목록입니다.
    func makeSections(
        visibleRecords: [WalkDataModel],
        petNameById: [String: String],
        selectedCalendarDate: Date?,
        calendar: Calendar
    ) -> [WalkListSectionModel]

    /// 목록 비어 있음 상태에 대응하는 안내 카드 모델을 생성합니다.
    /// - Parameters:
    ///   - allRecords: 전체 산책 기록입니다.
    ///   - selectedPetName: 현재 선택 반려견 이름입니다.
    ///   - shouldShowSelectedPetEmptyState: 선택 반려견 기준 0건 상태인지 여부입니다.
    /// - Returns: 비어 있음 상태 카드 모델. 표시할 카드가 없으면 `nil`입니다.
    func makeStateCard(
        allRecords: [WalkDataModel],
        selectedPetName: String,
        shouldShowSelectedPetEmptyState: Bool
    ) -> WalkListStateCardModel?
}

struct WalkListPresentationService: WalkListPresentationServicing {
    /// 산책 목록 상단 허브에 표시할 개요 모델을 생성합니다.
    /// - Parameters:
    ///   - visibleRecords: 현재 필터 기준으로 화면에 노출되는 산책 기록입니다.
    ///   - allRecords: 필터를 적용하기 전 전체 산책 기록입니다.
    ///   - selectedPetName: 현재 선택 반려견 이름입니다.
    ///   - selectedPetId: 현재 선택 반려견 식별자입니다.
    ///   - isShowingAllRecordsOverride: 선택 반려견 기준 대신 전체 기록 보기 모드인지 여부입니다.
    /// - Returns: 상단 허브 카드에 필요한 문맥/메트릭을 담은 개요 모델입니다.
    func makeOverview(
        visibleRecords: [WalkDataModel],
        allRecords: [WalkDataModel],
        selectedPetName: String,
        selectedPetId: String,
        isShowingAllRecordsOverride: Bool
    ) -> WalkListOverviewModel {
        let visibleArea = visibleRecords.reduce(0) { partialResult, record in
            partialResult + record.walkArea
        }
        let visibleWeeklyCount = visibleRecords.thisWeekList.count

        if isShowingAllRecordsOverride {
            return WalkListOverviewModel(
                title: "산책 기록",
                subtitle: "저장된 산책 기록을 다시 보며 다음 행동을 정하는 허브예요.",
                primaryLoopBadge: "기본 행동",
                primaryLoopTitle: "산책이 기록의 시작점이에요",
                primaryLoopMessage: "저장한 산책은 경로, 영역, 시간, 포인트 기록으로 남고 홈 목표와 시즌 흐름을 다시 읽는 기준이 됩니다.",
                primaryLoopSecondaryFlowText: "실내 미션은 산책이 어려운 날의 보조 흐름입니다.",
                modeBadge: "전체 기록 보기",
                contextTitle: "선택 기준 밖의 기록까지 함께 보고 있어요",
                contextMessage: "\(selectedPetName) 기준으로는 기록이 없어 전체 기록으로 전환했습니다. 상단에서 언제든 선택 반려견 기준으로 돌아갈 수 있어요.",
                helperMessage: "왜 0건이었는지 헷갈릴 때는 반려견 칩을 바꿔 보며 기록 범위를 비교해 보세요.",
                restoreActionTitle: "기준으로 돌아가기",
                metrics: [
                    makeMetric(id: "all", title: "전체 기록", value: "\(visibleRecords.count)건", detail: "현재 보고 있는 기록"),
                    makeMetric(id: "weekly", title: "이번 주", value: "\(visibleWeeklyCount)건", detail: "최근 7일 안의 기록"),
                    makeMetric(id: "area", title: "누적 영역", value: areaValue(visibleArea), detail: "현재 보이는 기준"),
                ]
            )
        }

        if selectedPetId.isEmpty == false {
            return WalkListOverviewModel(
                title: "산책 기록",
                subtitle: "산책이 남긴 기록을 날짜와 반려견 기준으로 다시 읽는 공간이에요.",
                primaryLoopBadge: "기본 행동",
                primaryLoopTitle: "산책이 기록의 시작점이에요",
                primaryLoopMessage: "한 번의 산책이 경로, 영역, 시간, 포인트 기록으로 쌓이고 이후 목표와 미션, 시즌 해석의 기준이 됩니다.",
                primaryLoopSecondaryFlowText: "실내 미션은 악천후나 예외 상황에서만 여는 보조 흐름입니다.",
                modeBadge: "선택 반려견 기준",
                contextTitle: "\(selectedPetName) 기록을 먼저 보여주고 있어요",
                contextMessage: "현재 선택한 반려견 기준으로 기록을 좁혀서 보고 있습니다. 반려견을 바꾸면 화면 전체가 같은 기준으로 갱신됩니다.",
                helperMessage: "기록이 없으면 전체 기록 보기로 전환해 다른 반려견 기록도 바로 탐색할 수 있어요.",
                restoreActionTitle: nil,
                metrics: [
                    makeMetric(id: "selected", title: "선택 기준", value: "\(visibleRecords.count)건", detail: "\(selectedPetName) 기록"),
                    makeMetric(id: "weekly", title: "이번 주", value: "\(visibleWeeklyCount)건", detail: "이번 주 산책"),
                    makeMetric(id: "area", title: "누적 영역", value: areaValue(visibleArea), detail: "현재 반려견 기준"),
                ]
            )
        }

        return WalkListOverviewModel(
            title: "산책 기록",
            subtitle: "산책이 기록으로 쌓이고 다음 행동을 정하는 허브예요.",
            primaryLoopBadge: "기본 행동",
            primaryLoopTitle: "산책이 기록의 시작점이에요",
            primaryLoopMessage: "한 번 저장한 산책은 경로, 영역, 시간, 포인트 기록이 되고 다시 보는 기준이 됩니다.",
            primaryLoopSecondaryFlowText: "실내 미션은 산책이 어려운 날의 보조 흐름입니다.",
            modeBadge: "전체 반려견 기준",
            contextTitle: "최근 산책 기록을 한곳에 모았어요",
            contextMessage: "반려견을 선택하면 해당 기준으로만 기록을 좁혀서 볼 수 있고, 전체 기록 보기로 다시 돌아와 비교할 수도 있어요.",
            helperMessage: "날짜, 시간, 영역, 포인트, 반려견 기준으로 세션 성격을 한눈에 파악할 수 있게 구성했습니다.",
            restoreActionTitle: nil,
            metrics: [
                makeMetric(id: "all", title: "총 기록", value: "\(allRecords.count)건", detail: "저장된 전체 기록"),
                makeMetric(id: "weekly", title: "이번 주", value: "\(visibleWeeklyCount)건", detail: "이번 주 산책"),
                makeMetric(id: "area", title: "누적 영역", value: areaValue(visibleArea), detail: "현재 보이는 기준"),
            ]
        )
    }

    /// 현재 필터 기준 기록을 주간 섹션 구조로 분리합니다.
    /// - Parameters:
    ///   - visibleRecords: 현재 화면에 보여줄 산책 기록입니다.
    ///   - petNameById: 반려견 식별자별 이름 매핑입니다.
    ///   - selectedCalendarDate: 현재 선택된 날짜의 `startOfDay`입니다.
    ///   - calendar: 날짜 섹션 타이틀 계산에 사용할 로컬 캘린더입니다.
    /// - Returns: 이번 주/이전 기록으로 분류된 섹션 목록입니다.
    func makeSections(
        visibleRecords: [WalkDataModel],
        petNameById: [String: String],
        selectedCalendarDate: Date?,
        calendar: Calendar
    ) -> [WalkListSectionModel] {
        if let selectedCalendarDate, visibleRecords.isEmpty == false {
            return [
                makeSection(
                    id: "selectedDate",
                    title: selectedDateTitle(for: selectedCalendarDate, calendar: calendar),
                    subtitle: "이 날짜에 걸친 산책 \(visibleRecords.count)건",
                    accessibilityIdentifier: "walklist.section.filtered",
                    records: visibleRecords.sorted { lhs, rhs in
                        lhs.createdAt > rhs.createdAt
                    },
                    petNameById: petNameById
                )
            ]
        }

        let thisWeekRecords = visibleRecords.thisWeekList.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
        let previousRecords = visibleRecords.exceptThisWeek.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }

        var sections: [WalkListSectionModel] = []
        if thisWeekRecords.isEmpty == false {
            sections.append(
                makeSection(
                    id: "thisWeek",
                    title: "이번 주 산책",
                    subtitle: "가장 최근에 저장한 \(thisWeekRecords.count)건",
                    accessibilityIdentifier: "walklist.section.thisWeek",
                    records: thisWeekRecords,
                    petNameById: petNameById
                )
            )
        }
        if previousRecords.isEmpty == false {
            sections.append(
                makeSection(
                    id: "previous",
                    title: "이전 기록",
                    subtitle: "이번 주 이전에 저장한 \(previousRecords.count)건",
                    accessibilityIdentifier: "walklist.section.previous",
                    records: previousRecords,
                    petNameById: petNameById
                )
            )
        }
        return sections
    }

    /// 목록 비어 있음 상태에 대응하는 안내 카드 모델을 생성합니다.
    /// - Parameters:
    ///   - allRecords: 전체 산책 기록입니다.
    ///   - selectedPetName: 현재 선택 반려견 이름입니다.
    ///   - shouldShowSelectedPetEmptyState: 선택 반려견 기준 0건 상태인지 여부입니다.
    /// - Returns: 비어 있음 상태 카드 모델. 표시할 카드가 없으면 `nil`입니다.
    func makeStateCard(
        allRecords: [WalkDataModel],
        selectedPetName: String,
        shouldShowSelectedPetEmptyState: Bool
    ) -> WalkListStateCardModel? {
        if shouldShowSelectedPetEmptyState {
            return WalkListStateCardModel(
                accessibilityIdentifier: "walklist.empty.filtered",
                badge: "선택 반려견 기준",
                title: "\(selectedPetName) 기록이 아직 없어요",
                message: "현재 선택 기준으로는 0건입니다. 전체 기록 보기로 전환하면 다른 반려견 기록을 바로 확인할 수 있어요.",
                footnote: "다음 행동: 전체 기록으로 전환해 다른 반려견 기록을 비교해 보세요.",
                primaryActionTitle: "전체 기록 보기",
                symbolName: "line.3.horizontal.decrease.circle"
            )
        }

        guard allRecords.isEmpty else {
            return nil
        }

        return WalkListStateCardModel(
            accessibilityIdentifier: "walklist.empty",
            badge: "기록 없음",
            title: "첫 산책 기록을 남겨보세요",
            message: "지도 탭에서 산책을 시작하고 저장하면 날짜, 시간, 영역, 포인트 정보가 이곳에 쌓입니다.",
            footnote: "다음 행동: 지도 탭에서 산책을 시작해 첫 기록을 만들어 보세요.",
            primaryActionTitle: nil,
            symbolName: "figure.walk.motion"
        )
    }

    /// 요약 메트릭 한 개를 생성합니다.
    /// - Parameters:
    ///   - id: 메트릭 식별자입니다.
    ///   - title: 메트릭 제목입니다.
    ///   - value: 메트릭 값입니다.
    ///   - detail: 값 해석을 돕는 보조 설명입니다.
    /// - Returns: 상단 요약 카드에 표시할 메트릭 모델입니다.
    private func makeMetric(id: String, title: String, value: String, detail: String) -> WalkListOverviewMetric {
        WalkListOverviewMetric(id: id, title: title, value: value, detail: detail)
    }

    /// 영역 수치를 목록 상단 요약용 텍스트로 변환합니다.
    /// - Parameter area: 제곱미터 단위 영역 값입니다.
    /// - Returns: `㎡`, `만 ㎡`, `k㎡` 규칙이 적용된 문자열입니다.
    private func areaValue(_ area: Double) -> String {
        if area <= 0 {
            return "0㎡"
        }
        return area.calculatedAreaString
    }

    /// 주간 섹션 한 개를 생성합니다.
    /// - Parameters:
    ///   - id: 섹션 식별자입니다.
    ///   - title: 섹션 제목입니다.
    ///   - subtitle: 섹션 보조 설명입니다.
    ///   - accessibilityIdentifier: 섹션 헤더 접근성 식별자입니다.
    ///   - records: 섹션에 포함할 산책 기록입니다.
    ///   - petNameById: 반려견 식별자별 이름 매핑입니다.
    /// - Returns: 셀 프레젠테이션 정보가 채워진 섹션 모델입니다.
    private func makeSection(
        id: String,
        title: String,
        subtitle: String,
        accessibilityIdentifier: String?,
        records: [WalkDataModel],
        petNameById: [String: String]
    ) -> WalkListSectionModel {
        WalkListSectionModel(
            id: id,
            title: title,
            subtitle: subtitle,
            accessibilityIdentifier: accessibilityIdentifier,
            items: records.map { record in
                WalkListSectionItem(
                    walkData: record,
                    petName: record.petId.flatMap { petNameById[$0] },
                    accessibilityIdentifier: "walklist.cell.\(record.id.uuidString.lowercased())"
                )
            }
        )
    }

    /// 선택된 날짜 필터에 표시할 섹션 타이틀을 생성합니다.
    /// - Parameters:
    ///   - date: 사용자가 탭한 날짜의 `startOfDay`입니다.
    ///   - calendar: 날짜 포맷 계산에 사용할 로컬 캘린더입니다.
    /// - Returns: `M월 d일 (E) 기록` 형식의 문자열입니다.
    private func selectedDateTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일 (E) 기록"
        return formatter.string(from: date)
    }
}
