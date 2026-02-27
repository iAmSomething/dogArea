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
    @Published var indoorMissionBoard: IndoorMissionBoard = .empty
    @Published var indoorMissionStatusMessage: String? = nil
    @Published var weatherFeedbackRemainingCount: Int = 2
    @Published var weatherFeedbackResultMessage: String? = nil

    private var allPolygons: [Polygon] = []
    private var cancellables: Set<AnyCancellable> = []
    private var lastIndoorMissionExposureTrackKey: String = ""
    private let indoorMissionStore = IndoorMissionStore()
    private let metricTracker = AppMetricTracker.shared

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    var selectedPetNameWithYi: String {
        (selectedPet?.petName ?? "강아지").addYi()
    }

    var nextGoalArea: AreaMeter? {
        nearlistMore()
    }

    var weatherFeedbackWeeklyLimit: Int {
        indoorMissionStore.weeklyFeedbackLimit
    }

    var canSubmitWeatherMismatchFeedback: Bool {
        indoorMissionBoard.riskLevel != .clear && weatherFeedbackRemainingCount > 0
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
        refreshIndoorMissions()
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

    func clearIndoorMissionStatusMessage() {
        indoorMissionStatusMessage = nil
    }

    func clearWeatherFeedbackResultMessage() {
        weatherFeedbackResultMessage = nil
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
        refreshIndoorMissions()

        guard didTimeZoneChange || name == .NSSystemTimeZoneDidChange else { return }
        aggregationStatusMessage = "타임존이 변경되어 통계를 현재 시간대 기준으로 다시 계산했어요."
    }

    private func applySelectedPetStatistics(shouldUpdateMeter: Bool = false) {
        polygonList = filteredPolygons(from: allPolygons)
        totalArea = polygonList.map(\.walkingArea).reduce(0.0, +)
        totalTime = polygonList.map(\.walkingTime).reduce(0.0, +)
        myArea = .init("\(selectedPetNameWithYi)의 영역", totalArea)
        boundarySplitContribution = makeDayBoundarySplitContribution(reference: Date())
        refreshIndoorMissions()
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

    func refreshIndoorMissions(now: Date = Date()) {
        indoorMissionBoard = indoorMissionStore.buildBoard(now: now)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(now: now)
        guard indoorMissionBoard.isIndoorReplacementActive else { return }
        let exposureKey = "\(indoorMissionBoard.dayKey)|\(indoorMissionBoard.riskLevel.rawValue)"
        guard exposureKey != lastIndoorMissionExposureTrackKey else { return }
        lastIndoorMissionExposureTrackKey = exposureKey
        metricTracker.track(
            .indoorMissionReplacementApplied,
            userKey: userInfo?.id,
            payload: [
                "risk": indoorMissionBoard.riskLevel.rawValue,
                "missionCount": "\(indoorMissionBoard.missions.count)"
            ]
        )
    }

    func recordIndoorMissionAction(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        indoorMissionStore.incrementActionCount(missionId: missionId)
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)
        metricTracker.track(
            .indoorMissionActionLogged,
            userKey: userInfo?.id,
            payload: [
                "missionId": missionId,
                "actionCount": "\(mission.progress.actionCount)"
            ]
        )
    }

    func finalizeIndoorMission(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        let result = indoorMissionStore.confirmCompletion(missionId: missionId, minimumActionCount: mission.minimumActionCount)
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)

        switch result {
        case .completed:
            indoorMissionStatusMessage = "\(mission.title) 완료! 보상 \(mission.rewardPoint)pt"
            metricTracker.track(
                .indoorMissionCompleted,
                userKey: userInfo?.id,
                payload: [
                    "missionId": missionId,
                    "reward": "\(mission.rewardPoint)",
                    "risk": indoorMissionBoard.riskLevel.rawValue
                ]
            )
        case .insufficientAction(let actionCount, let required):
            indoorMissionStatusMessage = "완료 기준 미달: \(actionCount)/\(required) 행동"
            metricTracker.track(
                .indoorMissionCompletionRejected,
                userKey: userInfo?.id,
                payload: [
                    "missionId": missionId,
                    "actionCount": "\(actionCount)",
                    "required": "\(required)"
                ]
            )
        case .alreadyCompleted:
            indoorMissionStatusMessage = "이미 완료한 미션입니다."
        }
    }

    func submitWeatherMismatchFeedback(now: Date = Date()) {
        let outcome = indoorMissionStore.submitWeatherMismatchFeedback(now: now)
        weatherFeedbackRemainingCount = outcome.remainingWeeklyQuota

        if outcome.accepted {
            let hasRiskChanged = outcome.originalRisk != outcome.adjustedRisk
            weatherFeedbackResultMessage = hasRiskChanged
                ? "체감 피드백 반영: \(outcome.originalRisk.displayTitle) → \(outcome.adjustedRisk.displayTitle)"
                : "피드백을 반영했지만 안전 기준상 오늘 판정은 \(outcome.adjustedRisk.displayTitle)로 유지돼요."
            metricTracker.track(
                .weatherFeedbackSubmitted,
                userKey: userInfo?.id,
                payload: [
                    "fromRisk": outcome.originalRisk.rawValue,
                    "toRisk": outcome.adjustedRisk.rawValue,
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)"
                ]
            )
            metricTracker.track(
                .weatherRiskReevaluated,
                userKey: userInfo?.id,
                payload: [
                    "fromRisk": outcome.originalRisk.rawValue,
                    "toRisk": outcome.adjustedRisk.rawValue,
                    "changed": hasRiskChanged ? "true" : "false"
                ]
            )
        } else {
            weatherFeedbackResultMessage = outcome.message
            metricTracker.track(
                .weatherFeedbackRateLimited,
                userKey: userInfo?.id,
                payload: [
                    "remainingQuota": "\(outcome.remainingWeeklyQuota)"
                ]
            )
        }

        indoorMissionStatusMessage = weatherFeedbackResultMessage
        refreshIndoorMissions(now: now)
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

enum IndoorWeatherRiskLevel: String, CaseIterable {
    case clear
    case caution
    case bad
    case severe

    var displayTitle: String {
        switch self {
        case .clear: return "날씨 안정"
        case .caution: return "기상 주의"
        case .bad: return "악천후"
        case .severe: return "고위험 악천후"
        }
    }

    var replacementMissionCount: Int {
        switch self {
        case .clear: return 0
        case .caution: return 1
        case .bad: return 2
        case .severe: return 3
        }
    }

    var rewardScale: Double {
        switch self {
        case .clear: return 1.0
        case .caution: return 0.92
        case .bad: return 0.88
        case .severe: return 0.84
        }
    }
}

enum IndoorMissionCategory: String, CaseIterable {
    case recordCleanup
    case petCareCheck
    case trainingCheck
}

struct IndoorMissionTemplate: Identifiable, Equatable {
    let id: String
    let category: IndoorMissionCategory
    let title: String
    let description: String
    let minimumActionCount: Int
    let baseRewardPoint: Int
    let streakEligible: Bool
}

struct IndoorMissionProgress: Equatable {
    let actionCount: Int
    let minimumActionCount: Int
    let isCompleted: Bool

    var progressRatio: Double {
        guard minimumActionCount > 0 else { return 1.0 }
        return min(1.0, Double(actionCount) / Double(minimumActionCount))
    }
}

struct IndoorMissionCardModel: Identifiable, Equatable {
    let id: String
    let category: IndoorMissionCategory
    let title: String
    let description: String
    let minimumActionCount: Int
    let rewardPoint: Int
    let streakEligible: Bool
    let dayKey: String
    let progress: IndoorMissionProgress
}

struct IndoorMissionBoard: Equatable {
    let riskLevel: IndoorWeatherRiskLevel
    let dayKey: String
    let missions: [IndoorMissionCardModel]

    var isIndoorReplacementActive: Bool {
        riskLevel != .clear && missions.isEmpty == false
    }

    static let empty = IndoorMissionBoard(riskLevel: .clear, dayKey: "", missions: [])

    func updated(_ mission: IndoorMissionCardModel) -> IndoorMissionBoard {
        let replaced = missions.map { existing in
            existing.id == mission.id ? mission : existing
        }
        return .init(riskLevel: riskLevel, dayKey: dayKey, missions: replaced)
    }
}

struct WeatherFeedbackOutcome: Equatable {
    let accepted: Bool
    let message: String
    let originalRisk: IndoorWeatherRiskLevel
    let adjustedRisk: IndoorWeatherRiskLevel
    let remainingWeeklyQuota: Int
}

private enum IndoorMissionCompletionResult {
    case completed
    case insufficientAction(actionCount: Int, required: Int)
    case alreadyCompleted
}

private final class IndoorMissionStore {
    private enum DefaultsKey {
        static let weatherRiskOverride = "weather.risk.level.v1"
        static let actionCounts = "indoor.mission.actionCounts.v1"
        static let completionFlags = "indoor.mission.completed.v1"
        static let exposureHistory = "indoor.mission.exposureHistory.v1"
        static let weatherFeedbackTimestamps = "weather.feedback.timestamps.v1"
        static let weatherFeedbackDailyAdjustment = "weather.feedback.dailyAdjustment.v1"
    }

    let weeklyFeedbackLimit = 2

    private let calendar: Calendar = {
        var value = Calendar.autoupdatingCurrent
        value.timeZone = TimeZone.autoupdatingCurrent
        return value
    }()

    private let templates: [IndoorMissionTemplate] = [
        .init(
            id: "indoor.record.cleanup",
            category: .recordCleanup,
            title: "기록 정리 체크",
            description: "산책 기록/사진/메모 정리를 3회 진행해요.",
            minimumActionCount: 3,
            baseRewardPoint: 40,
            streakEligible: true
        ),
        .init(
            id: "indoor.petcare.check",
            category: .petCareCheck,
            title: "펫 케어 루틴 체크",
            description: "물/브러싱/컨디션 체크를 2회 진행해요.",
            minimumActionCount: 2,
            baseRewardPoint: 32,
            streakEligible: true
        ),
        .init(
            id: "indoor.training.check",
            category: .trainingCheck,
            title: "실내 훈련 체크",
            description: "기다려/손/하우스 훈련을 4회 수행해요.",
            minimumActionCount: 4,
            baseRewardPoint: 48,
            streakEligible: true
        ),
        .init(
            id: "indoor.record.photo_sort",
            category: .recordCleanup,
            title: "사진 정리 체크",
            description: "최근 산책 사진 분류/삭제/보관을 2회 진행해요.",
            minimumActionCount: 2,
            baseRewardPoint: 28,
            streakEligible: true
        ),
        .init(
            id: "indoor.training.focus",
            category: .trainingCheck,
            title: "집중 훈련 체크",
            description: "10초 집중 유지 훈련을 3회 진행해요.",
            minimumActionCount: 3,
            baseRewardPoint: 36,
            streakEligible: true
        )
    ]

    func buildBoard(now: Date) -> IndoorMissionBoard {
        let riskLevel = resolveRiskLevel(now: now)
        let dayKey = dayStamp(for: now)
        guard riskLevel.replacementMissionCount > 0 else {
            return .init(riskLevel: riskLevel, dayKey: dayKey, missions: [])
        }

        let selectedTemplates = selectedTemplatesForToday(riskLevel: riskLevel, dayKey: dayKey)
        let missions = selectedTemplates.map { template in
            makeCardModel(template: template, riskLevel: riskLevel, dayKey: dayKey)
        }
        return .init(riskLevel: riskLevel, dayKey: dayKey, missions: missions)
    }

    func incrementActionCount(missionId: String, now: Date = Date()) {
        let dayKey = dayStamp(for: now)
        let key = actionKey(missionId: missionId, dayKey: dayKey)
        var counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: DefaultsKey.actionCounts)
    }

    func confirmCompletion(
        missionId: String,
        minimumActionCount: Int,
        now: Date = Date()
    ) -> IndoorMissionCompletionResult {
        let dayKey = dayStamp(for: now)
        let completedKey = actionKey(missionId: missionId, dayKey: dayKey)
        var completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        if completed[completedKey] != nil {
            return .alreadyCompleted
        }

        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let actionCount = counts[completedKey] ?? 0
        guard actionCount >= minimumActionCount else {
            return .insufficientAction(actionCount: actionCount, required: minimumActionCount)
        }
        completed[completedKey] = now.timeIntervalSince1970
        UserDefaults.standard.set(completed, forKey: DefaultsKey.completionFlags)
        return .completed
    }

    func updatedMissionState(_ mission: IndoorMissionCardModel) -> IndoorMissionCardModel {
        makeCardModel(
            template: template(for: mission.id) ?? .init(
                id: mission.id,
                category: mission.category,
                title: mission.title,
                description: mission.description,
                minimumActionCount: mission.minimumActionCount,
                baseRewardPoint: mission.rewardPoint,
                streakEligible: mission.streakEligible
            ),
            riskLevel: resolvedRiskLevelFromBoard(),
            dayKey: mission.dayKey
        )
    }

    func weatherFeedbackRemainingCount(now: Date = Date()) -> Int {
        max(0, weeklyFeedbackLimit - feedbackCountInCurrentWeek(now: now))
    }

    func submitWeatherMismatchFeedback(now: Date = Date()) -> WeatherFeedbackOutcome {
        let originalRisk = resolveRiskLevel(now: now)
        let remainingBefore = weatherFeedbackRemainingCount(now: now)
        guard remainingBefore > 0 else {
            return .init(
                accepted: false,
                message: "체감 피드백은 주간 \(weeklyFeedbackLimit)회까지 반영할 수 있어요.",
                originalRisk: originalRisk,
                adjustedRisk: originalRisk,
                remainingWeeklyQuota: 0
            )
        }

        appendFeedbackTimestamp(now: now)
        let dayKey = dayStamp(for: now)

        let adjustedRisk: IndoorWeatherRiskLevel
        if originalRisk == .severe {
            adjustedRisk = .bad
        } else if originalRisk == .bad {
            adjustedRisk = .caution
        } else {
            adjustedRisk = originalRisk
        }

        let adjustmentStep = adjustmentStep(from: originalRisk, to: adjustedRisk)
        persistDailyAdjustment(dayKey: dayKey, step: adjustmentStep)

        let remainingAfter = weatherFeedbackRemainingCount(now: now)
        let message: String
        if originalRisk != adjustedRisk {
            message = "체감 피드백이 반영되어 오늘 판정을 \(adjustedRisk.displayTitle)로 재평가했어요."
        } else {
            message = "피드백은 반영했지만 안전 기준상 오늘 판정은 \(adjustedRisk.displayTitle)로 유지돼요."
        }

        return .init(
            accepted: true,
            message: message,
            originalRisk: originalRisk,
            adjustedRisk: adjustedRisk,
            remainingWeeklyQuota: remainingAfter
        )
    }

    private func makeCardModel(
        template: IndoorMissionTemplate,
        riskLevel: IndoorWeatherRiskLevel,
        dayKey: String
    ) -> IndoorMissionCardModel {
        let key = actionKey(missionId: template.id, dayKey: dayKey)
        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        let actionCount = counts[key] ?? 0
        let isCompleted = completed[key] != nil
        let reward = Int((Double(template.baseRewardPoint) * riskLevel.rewardScale).rounded())

        return .init(
            id: template.id,
            category: template.category,
            title: template.title,
            description: template.description,
            minimumActionCount: template.minimumActionCount,
            rewardPoint: max(1, reward),
            streakEligible: template.streakEligible,
            dayKey: dayKey,
            progress: .init(
                actionCount: actionCount,
                minimumActionCount: template.minimumActionCount,
                isCompleted: isCompleted
            )
        )
    }

    private func template(for missionId: String) -> IndoorMissionTemplate? {
        templates.first(where: { $0.id == missionId })
    }

    private func resolveBaseRiskLevel() -> IndoorWeatherRiskLevel {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let level = IndoorWeatherRiskLevel(rawValue: env.lowercased()) {
            return level
        }
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.weatherRiskOverride),
           let level = IndoorWeatherRiskLevel(rawValue: raw.lowercased()) {
            return level
        }
        return .caution
    }

    private func resolveRiskLevel(now: Date = Date()) -> IndoorWeatherRiskLevel {
        let baseRisk = resolveBaseRiskLevel()
        let dayKey = dayStamp(for: now)
        let adjustment = dailyAdjustmentMap()[dayKey] ?? 0
        return adjustedRisk(from: baseRisk, step: adjustment)
    }

    private func selectedTemplatesForToday(
        riskLevel: IndoorWeatherRiskLevel,
        dayKey: String
    ) -> [IndoorMissionTemplate] {
        let recentMissionIds = recentPresentedMissionIds(dayKey: dayKey)
        let ordered = templates.sorted { lhs, rhs in
            missionPriority(of: lhs, for: riskLevel) < missionPriority(of: rhs, for: riskLevel)
        }
        var filtered = ordered.filter { recentMissionIds.contains($0.id) == false }
        if filtered.count < riskLevel.replacementMissionCount {
            filtered = ordered
        }

        let selected = Array(filtered.prefix(riskLevel.replacementMissionCount))
        persistExposure(dayKey: dayKey, missionIds: selected.map(\.id))
        return selected
    }

    private func missionPriority(of template: IndoorMissionTemplate, for riskLevel: IndoorWeatherRiskLevel) -> Int {
        switch riskLevel {
        case .clear:
            return 99
        case .caution:
            switch template.category {
            case .petCareCheck: return 0
            case .recordCleanup: return 1
            case .trainingCheck: return 2
            }
        case .bad:
            switch template.category {
            case .recordCleanup: return 0
            case .petCareCheck: return 1
            case .trainingCheck: return 2
            }
        case .severe:
            switch template.category {
            case .petCareCheck: return 0
            case .trainingCheck: return 1
            case .recordCleanup: return 2
            }
        }
    }

    private func recentPresentedMissionIds(dayKey: String) -> Set<String> {
        let history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        let previousDayKeys = previousDayStamps(from: dayKey, count: 2)
        var ids: Set<String> = []
        for key in previousDayKeys {
            for id in history[key] ?? [] {
                ids.insert(id)
            }
        }
        return ids
    }

    private func persistExposure(dayKey: String, missionIds: [String]) {
        var history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        history[dayKey] = missionIds
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 7) + [dayKey])
        history = history.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(history, forKey: DefaultsKey.exposureHistory)
    }

    private func actionKey(missionId: String, dayKey: String) -> String {
        "\(dayKey)|\(missionId)"
    }

    private func dayStamp(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func previousDayStamps(from dayKey: String, count: Int) -> [String] {
        guard let current = Self.dayFormatter.date(from: dayKey) else { return [] }
        return (1...count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: current) else { return nil }
            return Self.dayFormatter.string(from: date)
        }
    }

    private func resolvedRiskLevelFromBoard() -> IndoorWeatherRiskLevel {
        resolveRiskLevel()
    }

    private func adjustedRisk(from risk: IndoorWeatherRiskLevel, step: Int) -> IndoorWeatherRiskLevel {
        guard step != 0 else { return risk }
        let allCases = IndoorWeatherRiskLevel.allCases
        guard let currentIndex = allCases.firstIndex(of: risk) else { return risk }
        let targetIndex = min(max(0, currentIndex + step), allCases.count - 1)
        let targetRisk = allCases[targetIndex]
        if risk != .clear && targetRisk == .clear {
            return .caution
        }
        return targetRisk
    }

    private func adjustmentStep(from originalRisk: IndoorWeatherRiskLevel, to adjustedRisk: IndoorWeatherRiskLevel) -> Int {
        guard let originalIndex = IndoorWeatherRiskLevel.allCases.firstIndex(of: originalRisk),
              let adjustedIndex = IndoorWeatherRiskLevel.allCases.firstIndex(of: adjustedRisk) else {
            return 0
        }
        return adjustedIndex - originalIndex
    }

    private func feedbackCountInCurrentWeek(now: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let events = feedbackTimestamps().filter { timestamp in
            let date = Date(timeIntervalSince1970: timestamp)
            return interval.contains(date)
        }
        return events.count
    }

    private func feedbackTimestamps() -> [TimeInterval] {
        let raw = UserDefaults.standard.array(forKey: DefaultsKey.weatherFeedbackTimestamps) as? [Double] ?? []
        return raw.sorted()
    }

    private func appendFeedbackTimestamp(now: Date) {
        let expiration = now.addingTimeInterval(-60 * 24 * 3600).timeIntervalSince1970
        var values = feedbackTimestamps().filter { $0 >= expiration }
        values.append(now.timeIntervalSince1970)
        UserDefaults.standard.set(values, forKey: DefaultsKey.weatherFeedbackTimestamps)
    }

    private func dailyAdjustmentMap() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.weatherFeedbackDailyAdjustment) as? [String: Int] ?? [:]
    }

    private func persistDailyAdjustment(dayKey: String, step: Int) {
        var map = dailyAdjustmentMap()
        if step == 0 {
            map.removeValue(forKey: dayKey)
        } else {
            map[dayKey] = step
        }
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 14) + [dayKey])
        map = map.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(map, forKey: DefaultsKey.weatherFeedbackDailyAdjustment)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
