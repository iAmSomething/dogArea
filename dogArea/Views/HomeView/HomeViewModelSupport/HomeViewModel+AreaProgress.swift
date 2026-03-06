import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension HomeViewModel {
    func applySelectedPetStatistics(shouldUpdateMeter: Bool = false) {
        polygonList = areaAggregationService.filteredPolygons(
            from: allPolygons,
            selectedPetId: selectedPet?.petId,
            showsAllRecords: isShowingAllRecordsOverride
        )
        totalArea = polygonList.map(\.walkingArea).reduce(0.0, +)
        totalTime = polygonList.map(\.walkingTime).reduce(0.0, +)
        myArea = areaAggregationService.makeCurrentArea(
            totalArea: totalArea,
            selectedPetNameWithYi: selectedPetNameWithYi
        )
        boundarySplitContribution = makeDayBoundarySplitContribution(reference: Date())
        refreshIndoorMissions()
        evaluateAreaMilestones()
        if shouldUpdateMeter {
            updateCurrentMeter()
        }
    }

    func refreshAreaList() {
        myAreaList = walkRepository.fetchAreas()
    }

    func combinedAreas() -> [AreaMeter] {
        areaAggregationService.combinedAreas(
            currentArea: myArea,
            areaCollection: krAreas
        )
    }

    func nearlistLess() -> AreaMeter? {
        areaAggregationService.previousReferenceArea(
            currentArea: myArea,
            areaCollection: krAreas
        )
    }

    func nearlistMore() -> AreaMeter? {
        areaAggregationService.nextReferenceArea(
            currentArea: myArea,
            areaCollection: krAreas,
            featuredGoalAreas: featuredGoalAreas
        )
    }

    func shouldUpdateMeter() -> Bool {
        areaAggregationService.shouldPersistCurrentMeter(
            currentArea: myArea,
            areaCollection: krAreas,
            persistedAreas: walkRepository.fetchAreas()
        )
    }

    func updateCurrentMeter() {
        guard shouldUpdateMeter() else { return }
        let currents = krAreas.nearistArea(since: walkRepository.fetchAreas().last, from: myArea.area)
        for current in currents {
            _ = walkRepository.saveArea(
                .init(
                    areaName: current.areaName,
                    area: current.area,
                    createdAt: Date().timeIntervalSince1970
                )
            )
        }
    }

    /// 현재 누적 영역을 기준으로 새로 달성한 영역 마일스톤을 감지하고 UI/알림 큐에 반영합니다.
    /// - Parameter now: 마일스톤 달성 시각 계산 기준입니다.
    func evaluateAreaMilestones(now: Date = Date()) {
        guard let ownerUserId = userInfo?.id, ownerUserId.isEmpty == false else { return }
        let candidates = milestoneCandidates()
        guard candidates.isEmpty == false else { return }

        let events = areaMilestoneDetector.detectNewMilestones(
            currentArea: myArea.area,
            ownerUserId: ownerUserId,
            candidates: candidates,
            source: areaReferenceSourceLabel,
            achievedAt: now
        )
        guard events.isEmpty == false else { return }

        enqueueAreaMilestones(events)

        let appIsActive = isApplicationActive()
        for event in events {
            Task { [areaMilestoneNotificationScheduler] in
                await areaMilestoneNotificationScheduler.scheduleFallbackNotificationIfNeeded(
                    for: event,
                    appIsActive: appIsActive,
                    now: now
                )
            }
        }
    }

    /// 마일스톤 감지에 사용할 비교군 후보를 계산합니다.
    /// - Returns: featured 우선 정책이 적용된 마일스톤 후보 목록입니다.
    func milestoneCandidates() -> [AreaMilestoneCandidate] {
        areaAggregationService.milestoneCandidates(
            featuredGoalAreas: featuredGoalAreas,
            fallbackAreas: krAreas.areas
        )
    }

    /// 새 마일스톤 이벤트를 큐에 누적하고 즉시 표시 가능한 경우 팝업을 노출합니다.
    /// - Parameter events: 이번 계산에서 새로 달성한 마일스톤 이벤트 목록입니다.
    func enqueueAreaMilestones(_ events: [AreaMilestoneEvent]) {
        let ordered = events.sorted { lhs, rhs in
            if lhs.thresholdArea == rhs.thresholdArea {
                return lhs.landmarkName < rhs.landmarkName
            }
            return lhs.thresholdArea < rhs.thresholdArea
        }
        areaMilestoneQueue.append(contentsOf: ordered)
        presentNextAreaMilestoneIfNeeded()
    }

    /// 표시 중인 배지가 없으면 큐의 첫 이벤트를 현재 프레젠테이션 상태로 승격합니다.
    func presentNextAreaMilestoneIfNeeded() {
        guard areaMilestonePresentation == nil else { return }
        guard areaMilestoneQueue.isEmpty == false else { return }
        areaMilestonePresentation = areaMilestoneQueue.removeFirst()
    }

    /// 앱 포그라운드 활성 상태 여부를 반환합니다.
    /// - Returns: 포그라운드 활성 상태면 `true`, 아니면 `false`입니다.
    func isApplicationActive() -> Bool {
        #if canImport(UIKit)
        return UIApplication.shared.applicationState == .active
        #else
        return true
        #endif
    }

    func walkedDates() -> [Date] {
        let calendar = currentCalendar()
        return weeklyStatisticsService.walkedDates(from: polygonList, calendar: calendar)
    }

    func walkedAreaforWeek(reference: Date = Date()) -> Double {
        let calendar = currentCalendar()
        return weeklyStatisticsService.walkedAreaForWeek(from: polygonList, reference: reference, calendar: calendar)
    }

    func walkedCountforWeek(reference: Date = Date()) -> Int {
        let calendar = currentCalendar()
        return weeklyStatisticsService.walkedCountForWeek(from: polygonList, reference: reference, calendar: calendar)
    }

    func currentCalendar() -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }

    func currentWeekInterval(reference: Date) -> DateInterval {
        let calendar = currentCalendar()
        return weeklyStatisticsService.currentWeekInterval(reference: reference, calendar: calendar)
    }

    func sessionInterval(for polygon: Polygon) -> DateInterval {
        weeklyStatisticsService.sessionInterval(for: polygon)
    }

    func weightedAreaContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        weeklyStatisticsService.weightedAreaContribution(for: polygon, in: bucket)
    }

    func weightedDurationContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        weeklyStatisticsService.weightedDurationContribution(for: polygon, in: bucket)
    }

    func sessionOverlaps(_ polygon: Polygon, with bucket: DateInterval) -> Bool {
        weeklyStatisticsService.sessionOverlaps(polygon, with: bucket)
    }

    func dayStartsCovered(by polygon: Polygon, calendar: Calendar) -> [Date] {
        weeklyStatisticsService.dayStartsCovered(by: polygon, calendar: calendar)
    }

    func makeDayBoundarySplitContribution(reference: Date) -> DayBoundarySplitContribution? {
        let calendar = currentCalendar()
        return weeklyStatisticsService.makeDayBoundarySplitContribution(
            from: polygonList,
            reference: reference,
            calendar: calendar
        )
    }
}
