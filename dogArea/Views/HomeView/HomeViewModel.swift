//
//  HomeViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import Foundation
import SwiftUI
import Combine

final class HomeViewModel: ObservableObject, CoreDataProtocol {
    @Published var polygonList: [Polygon] = []
    @Published var totalArea: Double = 0.0
    @Published var totalTime: Double = 0.0
    @Published var krAreas: AreaMeterCollection = .init()
    @Published var myArea: AreaMeter = .init("", 0.0)
    @Published var myAreaList: [AreaMeterDTO] = []
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    @Published var guestDataUpgradeReport: GuestDataUpgradeReport? = nil
    @Published var boundarySplitContribution: DayBoundarySplitContribution? = nil
    @Published var aggregationStatusMessage: String? = nil
    @Published private(set) var aggregationTimeZoneIdentifier: String = TimeZone.current.identifier

    private var allPolygons: [Polygon] = []
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    var selectedPetNameWithYi: String {
        (selectedPet?.petName ?? "강아지").addYi()
    }

    var nextGoalArea: AreaMeter? {
        nearlistMore()
    }

    var remainingAreaToGoal: Double {
        guard let nextGoalArea else { return 0 }
        return max(0, nextGoalArea.area - myArea.area)
    }

    var goalProgressRatio: Double {
        guard let nextGoalArea, nextGoalArea.area > 0 else { return 1.0 }
        return min(1.0, max(0.0, myArea.area / nextGoalArea.area))
    }

    init() {
        bindSelectedPetSync()
        bindTimeBoundaryNotifications()
        reloadUserInfo()
        fetchData()
    }

    func fetchData() {
        reloadUserInfo()
        allPolygons = fetchPolygons()
        applySelectedPetStatistics(shouldUpdateMeter: true)
        myAreaList = fetchArea()
        refreshGuestDataUpgradeReport()
    }

    func reloadUserInfo() {
        userInfo = UserdefaultSetting.shared.getValue()
        selectedPet = UserdefaultSetting.shared.selectedPet(from: userInfo)
        selectedPetId = selectedPet?.petId ?? ""
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        UserdefaultSetting.shared.setSelectedPetId(petId, source: "home")
        reloadUserInfo()
        applySelectedPetStatistics()
    }

    func clearAggregationStatusMessage() {
        aggregationStatusMessage = nil
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reloadUserInfo()
                self.applySelectedPetStatistics()
            }
            .store(in: &cancellables)
    }

    private func bindTimeBoundaryNotifications() {
        let center = NotificationCenter.default
        let timezoneChanged = center.publisher(for: .NSSystemTimeZoneDidChange)
        let dayChanged = center.publisher(for: .NSCalendarDayChanged)

        Publishers.Merge(timezoneChanged, dayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleTimeBoundaryChange(notification.name)
            }
            .store(in: &cancellables)
    }

    private func handleTimeBoundaryChange(_ name: Notification.Name) {
        let newTimeZoneIdentifier = TimeZone.current.identifier
        let didTimeZoneChange = newTimeZoneIdentifier != aggregationTimeZoneIdentifier

        aggregationTimeZoneIdentifier = newTimeZoneIdentifier
        applySelectedPetStatistics()

        guard didTimeZoneChange || name == .NSSystemTimeZoneDidChange else { return }
        aggregationStatusMessage = "타임존이 변경되어 통계를 현재 시간대 기준으로 다시 계산했어요."
    }

    private func applySelectedPetStatistics(shouldUpdateMeter: Bool = false) {
        polygonList = filteredPolygons(from: allPolygons)
        totalArea = polygonList.map(\.walkingArea).reduce(0.0, +)
        totalTime = polygonList.map(\.walkingTime).reduce(0.0, +)
        myArea = .init("\(selectedPetNameWithYi)의 영역", totalArea)
        boundarySplitContribution = makeDayBoundarySplitContribution(reference: Date())
        if shouldUpdateMeter {
            updateCurrentMeter()
        }
    }

    private func filteredPolygons(from polygons: [Polygon]) -> [Polygon] {
        guard let selectedPetId = selectedPet?.petId, selectedPetId.isEmpty == false else {
            return polygons
        }

        let taggedPolygons = polygons.filter { ($0.petId?.isEmpty == false) }
        let selectedPetPolygons = polygons.filter { $0.petId == selectedPetId }

        // Legacy records created before session->pet tagging should remain visible.
        if selectedPetPolygons.isEmpty && taggedPolygons.isEmpty {
            return polygons
        }
        return selectedPetPolygons
    }

    func refreshGuestDataUpgradeReport() {
        guard let userId = userInfo?.id, userId.isEmpty == false else {
            guestDataUpgradeReport = nil
            return
        }
        guestDataUpgradeReport = GuestDataUpgradeService.shared.latestReport(for: userId)
    }

    func refreshAreaList() {
        myAreaList = fetchArea()
    }

    private func findIndex() -> Int {
        guard let i = krAreas.areas.firstIndex(where: {
            $0.area < myArea.area
        }) else { return krAreas.areas.count }
        return i
    }

    func combinedAreas() -> [AreaMeter] {
        let i = findIndex()
        var temp = krAreas.areas
        temp.insert(myArea, at: i)
        return temp
    }

    func nearlistLess() -> AreaMeter? {
        krAreas.nearistArea(of: myArea.area)
    }

    func nearlistMore() -> AreaMeter? {
        krAreas.closeArea(of: myArea.area)
    }

    private func shouldUpdateMeter() -> Bool {
        guard let last = fetchArea().last else { return true }
        guard let current = nearlistLess() else { return false }
        if (last.area == current.area && last.areaName == current.areaName) {
            return false
        } else if last.area > current.area {
            return false
        } else {
            return true
        }
    }

    private func updateCurrentMeter() {
        if shouldUpdateMeter() {
            let currents = krAreas.nearistArea(since: fetchArea().last, from: myArea.area)
            for c in currents.reversed() {
                if saveArea(area: .init(areaName: c.areaName, area: c.area, createdAt: Date().timeIntervalSince1970)) {
                }
            }
        }
    }

    func walkedDates() -> [Date] {
        let calendar = currentCalendar()
        var dayStarts: [TimeInterval: Date] = [:]
        for polygon in polygonList {
            for day in dayStartsCovered(by: polygon, calendar: calendar) {
                dayStarts[day.timeIntervalSince1970] = day
            }
        }
        return dayStarts.values.sorted()
    }

    func walkedAreaforWeek(reference: Date = Date()) -> Double {
        let weekInterval = currentWeekInterval(reference: reference)
        return polygonList.reduce(0.0) { partial, polygon in
            partial + weightedAreaContribution(for: polygon, in: weekInterval)
        }
    }

    func walkedCountforWeek(reference: Date = Date()) -> Int {
        let weekInterval = currentWeekInterval(reference: reference)
        return polygonList.filter { sessionOverlaps($0, with: weekInterval) }.count
    }

    private func currentCalendar() -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }

    private func currentWeekInterval(reference: Date) -> DateInterval {
        let calendar = currentCalendar()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: reference)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
        return DateInterval(start: start, end: end)
    }

    private func sessionInterval(for polygon: Polygon) -> DateInterval {
        let start = Date(timeIntervalSince1970: polygon.createdAt)
        let duration = max(0, polygon.walkingTime)
        if duration <= 0 {
            return DateInterval(start: start, end: start.addingTimeInterval(1))
        }
        return DateInterval(start: start, end: start.addingTimeInterval(duration))
    }

    private func overlapSeconds(_ lhs: DateInterval, _ rhs: DateInterval) -> TimeInterval {
        let overlapStart = max(lhs.start, rhs.start)
        let overlapEnd = min(lhs.end, rhs.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }

    private func weightedAreaContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        let duration = max(0, polygon.walkingTime)
        let area = max(0, polygon.walkingArea)
        if duration <= 0 {
            let point = Date(timeIntervalSince1970: polygon.createdAt)
            return bucket.contains(point) ? area : 0
        }

        let overlap = overlapSeconds(sessionInterval(for: polygon), bucket)
        guard overlap > 0 else { return 0 }
        let ratio = min(1, overlap / duration)
        return area * ratio
    }

    private func weightedDurationContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        let duration = max(0, polygon.walkingTime)
        if duration <= 0 {
            let point = Date(timeIntervalSince1970: polygon.createdAt)
            return bucket.contains(point) ? duration : 0
        }

        let overlap = overlapSeconds(sessionInterval(for: polygon), bucket)
        guard overlap > 0 else { return 0 }
        let ratio = min(1, overlap / duration)
        return duration * ratio
    }

    private func sessionOverlaps(_ polygon: Polygon, with bucket: DateInterval) -> Bool {
        if max(0, polygon.walkingTime) <= 0 {
            return bucket.contains(Date(timeIntervalSince1970: polygon.createdAt))
        }
        return overlapSeconds(sessionInterval(for: polygon), bucket) > 0
    }

    private func dayStartsCovered(by polygon: Polygon, calendar: Calendar) -> [Date] {
        let interval = sessionInterval(for: polygon)
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        dates.append(cursor)

        while let next = calendar.date(byAdding: .day, value: 1, to: cursor), next < interval.end {
            dates.append(next)
            cursor = next
        }

        return dates
    }

    private func makeDayBoundarySplitContribution(reference: Date) -> DayBoundarySplitContribution? {
        let calendar = currentCalendar()
        let todayStart = calendar.startOfDay(for: reference)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return nil
        }

        let previousInterval = DateInterval(start: yesterdayStart, end: todayStart)
        let currentInterval = DateInterval(start: todayStart, end: tomorrowStart)

        var previousArea = 0.0
        var currentArea = 0.0
        var previousDuration = 0.0
        var currentDuration = 0.0

        for polygon in polygonList {
            let session = sessionInterval(for: polygon)
            guard session.start < todayStart && session.end > todayStart else { continue }

            previousArea += weightedAreaContribution(for: polygon, in: previousInterval)
            currentArea += weightedAreaContribution(for: polygon, in: currentInterval)
            previousDuration += weightedDurationContribution(for: polygon, in: previousInterval)
            currentDuration += weightedDurationContribution(for: polygon, in: currentInterval)
        }

        guard previousArea > 0 || currentArea > 0 || previousDuration > 0 || currentDuration > 0 else {
            return nil
        }

        return DayBoundarySplitContribution(
            previousDay: yesterdayStart,
            currentDay: todayStart,
            previousArea: previousArea,
            currentArea: currentArea,
            previousDuration: previousDuration,
            currentDuration: currentDuration
        )
    }
}

struct DayBoundarySplitContribution {
    let previousDay: Date
    let currentDay: Date
    let previousArea: Double
    let currentArea: Double
    let previousDuration: Double
    let currentDuration: Double

    var previousDayLabel: String {
        Self.dayFormatter.string(from: previousDay)
    }

    var currentDayLabel: String {
        Self.dayFormatter.string(from: currentDay)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return formatter
    }()
}
