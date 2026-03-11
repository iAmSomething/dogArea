//
//  WalkListViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import Combine
import CoreLocation

final class WalkListViewModel: ObservableObject {
    @Published var walkingDatas: [WalkDataModel] = []
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPetName: String = "강아지"
    @Published private(set) var isShowingAllRecordsOverride: Bool = false
    @Published private(set) var overviewModel: WalkListOverviewModel = .placeholder
    @Published private(set) var calendarModel: WalkListCalendarPresentationModel = .placeholder
    @Published private(set) var sectionModels: [WalkListSectionModel] = []
    @Published private(set) var stateCardModel: WalkListStateCardModel? = nil

    private var allWalkingDatas: [WalkDataModel] = []
    private var scopedWalkingDatas: [WalkDataModel] = []
    private var selectedCalendarDate: Date?
    private var displayedCalendarMonth: Date
    private var hasUserAdjustedCalendarMonth = false
    private var cancellables: Set<AnyCancellable> = []
    private let walkRepository: WalkRepositoryProtocol
    private let presentationService: WalkListPresentationServicing
    private let calendarPresentationService: WalkListCalendarPresentationServicing

    var pets: [PetInfo] {
        if Self.shouldUseUITestLongMetricPreview() {
            return [Self.makeUITestPreviewPetInfo()]
        }
        let activePets = userInfo?.pet.filter(\.isActive) ?? []
        return activePets
    }

    var shouldShowSelectedPetEmptyState: Bool {
        guard isShowingAllRecordsOverride == false else { return false }
        guard selectedPetId.isEmpty == false else { return false }
        guard allWalkingDatas.isEmpty == false else { return false }
        let tagged = allWalkingDatas.filter { ($0.petId?.isEmpty == false) }
        guard tagged.isEmpty == false else { return false }
        let selected = tagged.filter { $0.petId == selectedPetId }
        return selected.isEmpty
    }

    init(
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        presentationService: WalkListPresentationServicing = WalkListPresentationService(),
        calendarPresentationService: WalkListCalendarPresentationServicing = WalkListCalendarPresentationService()
    ) {
        self.walkRepository = walkRepository
        self.presentationService = presentationService
        self.calendarPresentationService = calendarPresentationService
        self.displayedCalendarMonth = calendarPresentationService.recommendedDisplayedMonth(
            records: [],
            reference: Date(),
            calendar: Self.currentCalendar
        )
        bindSelectedPetSync()
        bindTimeBoundaryRefresh()
        synchronizeSelectedPetContext()
    }

    /// 저장소 또는 UI 테스트 preview source에서 산책 기록을 다시 불러옵니다.
    /// 현재 선택 반려견과 선택 날짜 상태를 유지한 채 상단 허브/캘린더/리스트 섹션을 재계산합니다.
    func fetchModel() {
        allWalkingDatas = loadWalkRecords()
        synchronizeSelectedPetContext()
        applySelectedPetFilter()
    }

    /// 사용자가 상단 반려견 칩을 탭했을 때 선택 반려견 기준을 갱신합니다.
    /// - Parameter petId: 선택할 반려견 식별자입니다.
    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        isShowingAllRecordsOverride = false
        UserdefaultSetting.shared.setSelectedPetId(petId, source: "walk_list")
    }

    /// 반려견 기준이 비어 있을 때 전체 기록을 임시로 다시 보여줍니다.
    /// 선택 날짜는 유지하되 반려견 스코프만 전체 범위로 확장합니다.
    func showAllRecordsTemporarily() {
        guard allWalkingDatas.isEmpty == false else { return }
        isShowingAllRecordsOverride = true
        applySelectedPetFilter()
    }

    /// 전체 기록 보기 오버라이드를 해제하고 다시 선택 반려견 기준으로 돌아갑니다.
    func showSelectedPetRecords() {
        isShowingAllRecordsOverride = false
        applySelectedPetFilter()
    }

    /// 월별 캘린더에서 날짜를 선택하거나 같은 날짜를 다시 눌러 해제합니다.
    /// - Parameter date: 사용자가 탭한 날짜의 `startOfDay`입니다.
    func selectCalendarDate(_ date: Date) {
        let normalizedDate = Self.currentCalendar.startOfDay(for: date)
        if let selectedCalendarDate,
           Self.currentCalendar.isDate(selectedCalendarDate, inSameDayAs: normalizedDate) {
            self.selectedCalendarDate = nil
        } else {
            self.selectedCalendarDate = normalizedDate
        }
        refreshPresentation()
    }

    /// 월별 캘린더의 날짜 필터를 해제하고 현재 반려견 범위 전체 기록으로 복귀합니다.
    func clearCalendarSelection() {
        selectedCalendarDate = nil
        refreshPresentation()
    }

    /// 월별 캘린더를 이전 달로 이동시키고 날짜 필터는 해제합니다.
    func showPreviousCalendarMonth() {
        moveCalendarMonth(by: -1)
    }

    /// 월별 캘린더를 다음 달로 이동시키고 날짜 필터는 해제합니다.
    func showNextCalendarMonth() {
        moveCalendarMonth(by: 1)
    }

    /// 선택 반려견/전체 범위에 따라 현재 화면 스코프를 계산합니다.
    /// 필요하면 선택 날짜를 정리하고 상단 허브와 섹션을 다시 빌드합니다.
    private func applySelectedPetFilter() {
        scopedWalkingDatas = scopedRecords()
        if hasUserAdjustedCalendarMonth == false {
            displayedCalendarMonth = calendarPresentationService.recommendedDisplayedMonth(
                records: scopedWalkingDatas,
                reference: Date(),
                calendar: Self.currentCalendar
            )
        }
        refreshPresentation()
    }

    /// 현재 반려견 스코프와 선택 날짜를 기반으로 개요, 캘린더, 섹션, 상태 카드를 다시 계산합니다.
    /// 선택 날짜가 더 이상 유효하지 않으면 날짜 필터를 해제한 뒤 한 번 더 재계산합니다.
    private func refreshPresentation() {
        let calendarSnapshot = calendarPresentationService.makeSnapshot(
            records: scopedWalkingDatas,
            displayedMonth: displayedCalendarMonth,
            selectedDate: selectedCalendarDate,
            calendar: Self.currentCalendar
        )

        if let selectedCalendarDate,
           calendarSnapshot.recordsByDayStart[selectedCalendarDate.timeIntervalSince1970]?.isEmpty != false {
            self.selectedCalendarDate = nil
            refreshPresentation()
            return
        }

        calendarModel = calendarSnapshot.model
        walkingDatas = filteredRecords(using: calendarSnapshot.recordsByDayStart)

        let petNameById = Dictionary(uniqueKeysWithValues: pets.map { ($0.petId, $0.petName) })
        overviewModel = presentationService.makeOverview(
            visibleRecords: walkingDatas,
            allRecords: allWalkingDatas,
            selectedPetName: selectedPetName,
            selectedPetId: selectedPetId,
            isShowingAllRecordsOverride: isShowingAllRecordsOverride
        )
        sectionModels = presentationService.makeSections(
            visibleRecords: walkingDatas,
            petNameById: petNameById,
            selectedCalendarDate: selectedCalendarDate,
            calendar: Self.currentCalendar
        )
        stateCardModel = presentationService.makeStateCard(
            allRecords: allWalkingDatas,
            selectedPetName: selectedPetName,
            shouldShowSelectedPetEmptyState: shouldShowSelectedPetEmptyState
        )
    }

    /// 현재 저장된 사용자 정보와 선택 반려견 정보를 다시 동기화합니다.
    private func synchronizeSelectedPetContext() {
        userInfo = UserdefaultSetting.shared.getValue()
        if Self.shouldUseUITestLongMetricPreview() {
            let previewPet = Self.makeUITestPreviewPetInfo()
            selectedPetId = previewPet.petId
            selectedPetName = previewPet.petName
            return
        }

        let selected = UserdefaultSetting.shared.selectedPet(from: userInfo)
        if let selected {
            selectedPetId = selected.petId
            selectedPetName = selected.petName
            return
        }

        selectedPetId = ""
        selectedPetName = "강아지"
    }

    /// 선택 반려견 변경 알림을 구독해 산책 목록 스코프를 동기화합니다.
    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isShowingAllRecordsOverride = false
                self?.synchronizeSelectedPetContext()
                self?.applySelectedPetFilter()
            }
            .store(in: &cancellables)
    }

    /// 타임존/일자 경계 변경 시 월 캘린더 마킹과 섹션을 즉시 다시 계산하도록 바인딩합니다.
    private func bindTimeBoundaryRefresh() {
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .NSCalendarDayChanged))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPresentation()
            }
            .store(in: &cancellables)
    }

    /// 현재 반려견 선택과 전체 보기 오버라이드 상태에 맞는 산책 범위를 반환합니다.
    /// - Returns: 캘린더와 리스트가 공유할 현재 반려견 스코프 기준 산책 기록 배열입니다.
    private func scopedRecords() -> [WalkDataModel] {
        if isShowingAllRecordsOverride {
            return allWalkingDatas
        }
        guard selectedPetId.isEmpty == false else {
            return allWalkingDatas
        }

        let tagged = allWalkingDatas.filter { ($0.petId?.isEmpty == false) }
        let selected = allWalkingDatas.filter { $0.petId == selectedPetId }
        if selected.isEmpty && tagged.isEmpty {
            return allWalkingDatas
        }
        return selected
    }

    /// 날짜 필터가 활성화되어 있으면 그 날짜를 커버한 세션만 반환합니다.
    /// - Parameter recordsByDayStart: 캘린더 스냅샷이 계산한 날짜별 산책 기록 매핑입니다.
    /// - Returns: 최종 리스트에 노출할 산책 기록 배열입니다.
    private func filteredRecords(using recordsByDayStart: [TimeInterval: [WalkDataModel]]) -> [WalkDataModel] {
        guard let selectedCalendarDate else {
            return scopedWalkingDatas
        }
        return recordsByDayStart[selectedCalendarDate.timeIntervalSince1970] ?? []
    }

    /// 월 이동 버튼 정책에 맞춰 표시 월을 이동시키고 날짜 필터는 해제합니다.
    /// - Parameter value: 이동할 월 offset입니다. 이전 달은 음수, 다음 달은 양수입니다.
    private func moveCalendarMonth(by value: Int) {
        displayedCalendarMonth = calendarPresentationService.shiftedMonth(
            from: displayedCalendarMonth,
            by: value,
            calendar: Self.currentCalendar
        )
        hasUserAdjustedCalendarMonth = true
        selectedCalendarDate = nil
        refreshPresentation()
    }

    /// 저장소 또는 UI 테스트 preview source에서 산책 기록 목록을 읽어옵니다.
    /// - Returns: 최신순으로 정렬된 산책 기록 배열입니다.
    private func loadWalkRecords() -> [WalkDataModel] {
        let previewRecords = Self.makeUITestCalendarPreviewRecordsIfNeeded()
        let source = previewRecords ?? walkRepository.fetchPolygons().map { WalkDataModel(polygon: $0) }
        return source.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    /// UI 테스트 전용 월별 캘린더 샘플 산책 기록을 필요할 때만 생성합니다.
    /// - Returns: `-UITest.WalkListCalendarPreview` 인자가 있으면 고정 샘플 기록 배열, 아니면 `nil`입니다.
    private static func makeUITestCalendarPreviewRecordsIfNeeded() -> [WalkDataModel]? {
        guard ProcessInfo.processInfo.arguments.contains("-UITest.WalkListCalendarPreview") else {
            return nil
        }

        let referenceDate = Date()
        let currentWeekStart = currentCalendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? currentCalendar.startOfDay(for: referenceDate)
        let usesLongMetricPreview = shouldUseUITestLongMetricPreview()
        let previewPetId = usesLongMetricPreview ? makeUITestPreviewPetInfo().petId : nil

        return [
            makePreviewRecord(
                id: "11111111-aaaa-bbbb-cccc-111111111111",
                start: makeUITestPreviewRecordDate(
                    fromWeekAnchor: currentWeekStart,
                    dayOffset: 0,
                    hour: 9,
                    minute: 20
                ),
                duration: usesLongMetricPreview ? 54_060 : 1_260,
                area: usesLongMetricPreview ? 123_456.78 : 7_420,
                coordinateSeed: (37.5665, 126.9780),
                pointCount: usesLongMetricPreview ? 16 : 3,
                petId: previewPetId
            ),
            makePreviewRecord(
                id: "22222222-aaaa-bbbb-cccc-222222222222",
                start: makeUITestPreviewRecordDate(
                    fromWeekAnchor: currentWeekStart,
                    dayOffset: -2,
                    hour: 18,
                    minute: 10
                ),
                duration: 1_800,
                area: 5_860,
                coordinateSeed: (37.5658, 126.9771),
                pointCount: 4,
                petId: previewPetId
            ),
            makePreviewRecord(
                id: "33333333-aaaa-bbbb-cccc-333333333333",
                start: makeUITestPreviewRecordDate(
                    fromWeekAnchor: currentWeekStart,
                    dayOffset: -5,
                    hour: 7,
                    minute: 40
                ),
                duration: 980,
                area: 4_240,
                coordinateSeed: (37.5649, 126.9761),
                pointCount: 3,
                petId: previewPetId
            )
        ]
    }

    /// UI 테스트용 산책 기록 샘플 날짜를 현재 주차 기준으로 계산합니다.
    /// - Parameters:
    ///   - weekAnchor: 현재 주차의 시작 시각입니다.
    ///   - dayOffset: 주 시작 기준으로 이동할 일 수입니다. 음수면 이전 주 기록을 만듭니다.
    ///   - hour: 생성할 샘플 시각의 시(hour) 값입니다.
    ///   - minute: 생성할 샘플 시각의 분(minute) 값입니다.
    /// - Returns: 현재 달력 기준으로 안정적인 주차 섹션을 만들 수 있는 샘플 날짜입니다.
    private static func makeUITestPreviewRecordDate(
        fromWeekAnchor weekAnchor: Date,
        dayOffset: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        let shiftedDay = currentCalendar.date(byAdding: .day, value: dayOffset, to: weekAnchor) ?? weekAnchor
        let components = currentCalendar.dateComponents([.year, .month, .day], from: shiftedDay)
        return DateComponents(
            calendar: currentCalendar,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: hour,
            minute: minute
        ).date ?? shiftedDay
    }

    /// UI 테스트용 샘플 산책 기록 한 건을 생성합니다.
    /// - Parameters:
    ///   - id: 샘플 polygon 식별자입니다.
    ///   - start: 산책 시작 시각입니다.
    ///   - duration: 산책 지속 시간(초)입니다.
    ///   - area: 산책 영역 넓이(㎡)입니다.
    ///   - coordinateSeed: 샘플 경로를 구성할 기준 좌표입니다.
    ///   - pointCount: 샘플 경로에 포함할 위치 포인트 수입니다.
    ///   - petId: 샘플 산책 기록에 연결할 반려견 식별자입니다.
    /// - Returns: 월별 캘린더/리스트 회귀 테스트에 사용할 산책 기록 모델입니다.
    private static func makePreviewRecord(
        id: String,
        start: Date,
        duration: Double,
        area: Double,
        coordinateSeed: (Double, Double),
        pointCount: Int,
        petId: String?
    ) -> WalkDataModel {
        let baseLatitude = coordinateSeed.0
        let baseLongitude = coordinateSeed.1
        let safePointCount = max(3, pointCount)
        let timeStep = duration / Double(max(1, safePointCount - 1))
        let locations = (0..<safePointCount).map { index in
            let latitudeStep = Double(index) * 0.0002
            let longitudeStep = Double(index) * 0.00018
            let createdAt = start.timeIntervalSince1970 + (Double(index) * timeStep)
            let role: WalkPointRole = index == 0 || index == safePointCount - 1 ? .mark : .route
            return Location(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLatitude + latitudeStep,
                    longitude: baseLongitude + longitudeStep
                ),
                id: UUID(),
                createdAt: createdAt,
                pointRole: role
            )
        }
        let polygon = Polygon(
            locations: locations,
            createdAt: start.timeIntervalSince1970,
            id: UUID(uuidString: id) ?? UUID(),
            walkingTime: duration,
            walkingArea: area,
            imgData: nil,
            petId: petId
        )
        return WalkDataModel(polygon: polygon)
    }

    /// 긴 값과 작은 화면 레이아웃 회귀를 검증할지 여부를 반환합니다.
    /// - Returns: `-UITest.WalkListLongMetricPreview` 인자가 있으면 `true`입니다.
    private static func shouldUseUITestLongMetricPreview() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.WalkListLongMetricPreview")
    }

    /// 긴 반려견 이름이 필요한 UI 테스트용 미리보기 반려견 정보를 생성합니다.
    /// - Returns: 목록 셀과 상단 허브의 줄바꿈 규칙을 검증할 수 있는 샘플 반려견 정보입니다.
    private static func makeUITestPreviewPetInfo() -> PetInfo {
        PetInfo(
            petId: "walklist-preview-long-pet",
            petName: "이름이 긴 반려견 산책 샘플",
            petProfile: nil
        )
    }

    private static var currentCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }
}
