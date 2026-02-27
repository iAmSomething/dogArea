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
    @Published var seasonCatchupBuffStatusMessage: String? = nil
    @Published var seasonCatchupBuffStatusWarning: Bool = false
    @Published private(set) var isShowingAllRecordsOverride: Bool = false
    @Published private(set) var areaReferenceSections: [AreaReferenceSection] = []
    @Published private(set) var areaReferenceSourceLabel: String = "로컬 비교군"
    @Published private(set) var featuredAreaCount: Int = 0

    private var allPolygons: [Polygon] = []
    private var cancellables: Set<AnyCancellable> = []
    private var lastIndoorMissionExposureTrackKey: String = ""
    private var lastIndoorMissionExtensionTrackKey: String = ""
    private var lastIndoorMissionDifficultyTrackKey: String = ""
    private let indoorMissionStore = IndoorMissionStore()
    private let metricTracker = AppMetricTracker.shared
    private let areaReferenceRepository: AreaReferenceRepository
    private var featuredGoalAreas: [AreaMeter] = []
    private var areaReferenceTask: Task<Void, Never>? = nil
    private static let catchupExpiryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    var selectedPetNameWithYi: String {
        (selectedPet?.petName ?? "강아지").addYi()
    }

    var selectedPetName: String {
        selectedPet?.petName ?? "강아지"
    }

    var shouldShowSelectedPetEmptyState: Bool {
        guard isShowingAllRecordsOverride == false else { return false }
        guard let selectedPetId = selectedPet?.petId, selectedPetId.isEmpty == false else { return false }
        guard allPolygons.isEmpty == false else { return false }
        let taggedPolygons = allPolygons.filter { ($0.petId?.isEmpty == false) }
        guard taggedPolygons.isEmpty == false else { return false }
        let selectedCount = taggedPolygons.filter { $0.petId == selectedPetId }.count
        return selectedCount == 0
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

    init(areaReferenceRepository: AreaReferenceRepository = SupabaseAreaReferenceRepository.shared) {
        self.areaReferenceRepository = areaReferenceRepository
        bindSelectedPetSync()
        bindTimeBoundaryNotifications()
        bindSeasonCatchupBuffStatusNotifications()
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus()
        fetchData()
    }

    deinit {
        areaReferenceTask?.cancel()
    }

    func fetchData() {
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus()
        allPolygons = fetchPolygons()
        applySelectedPetStatistics(shouldUpdateMeter: true)
        myAreaList = fetchArea()
        refreshAreaReferenceCatalogs()
        refreshGuestDataUpgradeReport()
        refreshIndoorMissions()
    }

    func refreshAreaReferenceCatalogs() {
        areaReferenceTask?.cancel()
        areaReferenceTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await areaReferenceRepository.fetchSnapshot()
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self.krAreas = AreaMeterCollection(areas: snapshot.allAreas)
                self.featuredGoalAreas = snapshot.featuredAreas.sorted { $0.area > $1.area }
                self.featuredAreaCount = self.featuredGoalAreas.count
                self.areaReferenceSections = snapshot.sections
                self.areaReferenceSourceLabel = snapshot.source == .remote ? "DB 비교군" : "로컬 비교군 (Fallback)"
                self.updateCurrentMeter()
                self.refreshAreaList()
            }
        }
    }

    func reloadUserInfo() {
        userInfo = UserdefaultSetting.shared.getValue()
        selectedPet = UserdefaultSetting.shared.selectedPet(from: userInfo)
        selectedPetId = selectedPet?.petId ?? ""
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        isShowingAllRecordsOverride = false
        UserdefaultSetting.shared.setSelectedPetId(petId, source: "home")
        reloadUserInfo()
        applySelectedPetStatistics()
    }

    func showAllRecordsTemporarily() {
        guard allPolygons.isEmpty == false else { return }
        isShowingAllRecordsOverride = true
        applySelectedPetStatistics()
    }

    func showSelectedPetRecords() {
        isShowingAllRecordsOverride = false
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

    private func bindSeasonCatchupBuffStatusNotifications() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.seasonCatchupBuffDidUpdateNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSeasonCatchupBuffStatus()
            }
            .store(in: &cancellables)
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isShowingAllRecordsOverride = false
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

    private func reloadSeasonCatchupBuffStatus(now: Date = Date()) {
        guard let snapshot = UserdefaultSetting.shared.seasonCatchupBuffSnapshot() else {
            seasonCatchupBuffStatusMessage = nil
            seasonCatchupBuffStatusWarning = false
            return
        }

        let nowTs = now.timeIntervalSince1970
        let expiresAt = snapshot.expiresAt

        if snapshot.isActive, let expiresAt, expiresAt > nowTs {
            let expiryText = Self.catchupExpiryTimeFormatter.string(from: Date(timeIntervalSince1970: expiresAt))
            seasonCatchupBuffStatusMessage = "복귀 버프 적용 중(+20%): \(expiryText)까지 신규 타일 점수 강화"
            seasonCatchupBuffStatusWarning = false
            return
        }

        if snapshot.status == .blocked {
            seasonCatchupBuffStatusMessage = "복귀 버프 미적용: \(catchupBlockReasonText(snapshot.blockReason))"
            seasonCatchupBuffStatusWarning = true
            return
        }

        if let expiresAt, expiresAt <= nowTs, nowTs - expiresAt <= 86_400 {
            seasonCatchupBuffStatusMessage = "복귀 버프 만료: 조건 충족 시 다음 주기에 다시 지급돼요."
            seasonCatchupBuffStatusWarning = false
            return
        }

        seasonCatchupBuffStatusMessage = nil
        seasonCatchupBuffStatusWarning = false
    }

    private func catchupBlockReasonText(_ reason: String?) -> String {
        switch reason {
        case "season_end_window":
            return "시즌 종료 24시간 전에는 지급되지 않아요."
        case "weekly_limit_reached":
            return "이번 주 지급 한도(1회)를 이미 사용했어요."
        case "insufficient_inactivity":
            return "최근 활동 간격이 72시간 미만이에요."
        case "no_prior_activity":
            return "이전 활동 기록이 없어 복귀 판정이 보류됐어요."
        default:
            return "운영 정책 조건을 만족하지 않았어요."
        }
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
        if isShowingAllRecordsOverride {
            return polygons
        }
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
        if let featuredNext = featuredGoalAreas.last(where: { $0.area > myArea.area }) {
            return featuredNext
        }
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
        let missionContext = makeIndoorMissionPetContext(reference: now)
        indoorMissionBoard = indoorMissionStore.buildBoard(now: now, context: missionContext)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(now: now)
        if indoorMissionBoard.isIndoorReplacementActive {
            let exposureKey = "\(indoorMissionBoard.dayKey)|\(indoorMissionBoard.riskLevel.rawValue)"
            if exposureKey != lastIndoorMissionExposureTrackKey {
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
        }

        let extensionTrackKey = "\(indoorMissionBoard.dayKey)|\(indoorMissionBoard.extensionState.rawValue)"
        if extensionTrackKey != lastIndoorMissionExtensionTrackKey {
            lastIndoorMissionExtensionTrackKey = extensionTrackKey

            switch indoorMissionBoard.extensionState {
            case .active:
                metricTracker.track(
                    .indoorMissionExtensionApplied,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey,
                        "rewardScale": String(format: "%.2f", indoorMissionStore.extensionRewardScale)
                    ]
                )
            case .expired:
                indoorMissionStatusMessage = indoorMissionBoard.extensionMessage
                metricTracker.track(
                    .indoorMissionExtensionExpired,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey
                    ]
                )
            case .cooldown:
                indoorMissionStatusMessage = indoorMissionBoard.extensionMessage
                metricTracker.track(
                    .indoorMissionExtensionBlocked,
                    userKey: userInfo?.id,
                    payload: [
                        "dayKey": indoorMissionBoard.dayKey,
                        "reason": "consecutive_limit"
                    ]
                )
            case .consumed, .none:
                break
            }
        }

        if let difficulty = indoorMissionBoard.difficultySummary {
            let difficultyKey = "\(indoorMissionBoard.dayKey)|\(difficulty.petId ?? "none")|\(String(format: "%.2f", difficulty.appliedMultiplier))|\(difficulty.easyDayState.rawValue)"
            if difficultyKey != lastIndoorMissionDifficultyTrackKey {
                lastIndoorMissionDifficultyTrackKey = difficultyKey
                metricTracker.track(
                    .indoorMissionDifficultyAdjusted,
                    userKey: userInfo?.id,
                    payload: [
                        "petId": difficulty.petId ?? "",
                        "multiplier": String(format: "%.2f", difficulty.appliedMultiplier),
                        "easyDay": difficulty.easyDayState == .active ? "true" : "false",
                        "ageBand": difficulty.ageBand.rawValue,
                        "activityLevel": difficulty.activityLevel.rawValue,
                        "walkFrequency": difficulty.walkFrequency.rawValue
                    ]
                )
            }
        }
    }

    func recordIndoorMissionAction(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        indoorMissionStore.incrementActionCount(
            missionId: mission.trackingMissionId,
            dayKey: mission.dayKey
        )
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)
        metricTracker.track(
            .indoorMissionActionLogged,
            userKey: userInfo?.id,
            payload: [
                "missionId": mission.trackingMissionId,
                "actionCount": "\(mission.progress.actionCount)",
                "isExtension": mission.isExtension ? "true" : "false"
            ]
        )
    }

    func finalizeIndoorMission(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        let result = indoorMissionStore.confirmCompletion(
            missionId: mission.trackingMissionId,
            dayKey: mission.dayKey,
            minimumActionCount: mission.minimumActionCount
        )
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)

        switch result {
        case .completed:
            if mission.isExtension {
                _ = indoorMissionStore.markExtensionConsumedIfNeeded(mission)
                indoorMissionStatusMessage = "\(mission.title) 연장 미션 완료! 감액 보상 \(mission.rewardPoint)pt"
                metricTracker.track(
                    .indoorMissionExtensionConsumed,
                    userKey: userInfo?.id,
                    payload: [
                        "missionId": mission.trackingMissionId,
                        "reward": "\(mission.rewardPoint)",
                        "rewardScale": String(format: "%.2f", mission.extensionRewardScale)
                    ]
                )
            } else {
                indoorMissionStatusMessage = "\(mission.title) 완료! 보상 \(mission.rewardPoint)pt"
            }
            metricTracker.track(
                .indoorMissionCompleted,
                userKey: userInfo?.id,
                payload: [
                    "missionId": mission.trackingMissionId,
                    "reward": "\(mission.rewardPoint)",
                    "risk": indoorMissionBoard.riskLevel.rawValue,
                    "isExtension": mission.isExtension ? "true" : "false"
                ]
            )
            refreshIndoorMissions()
        case .insufficientAction(let actionCount, let required):
            indoorMissionStatusMessage = "완료 기준 미달: \(actionCount)/\(required) 행동"
            metricTracker.track(
                .indoorMissionCompletionRejected,
                userKey: userInfo?.id,
                payload: [
                    "missionId": mission.trackingMissionId,
                    "actionCount": "\(actionCount)",
                    "required": "\(required)",
                    "isExtension": mission.isExtension ? "true" : "false"
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

    func activateEasyDayMode(now: Date = Date()) {
        guard let difficulty = indoorMissionBoard.difficultySummary else {
            indoorMissionStatusMessage = "선택된 반려견 정보가 없어 쉬운 날 모드를 사용할 수 없어요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "no_pet_context"
                ]
            )
            return
        }

        let outcome = indoorMissionStore.activateEasyDayMode(
            petId: difficulty.petId,
            now: now
        )
        switch outcome {
        case .activated:
            indoorMissionStatusMessage = "쉬운 날 모드를 적용했어요. 오늘 보상은 20% 감액돼요."
            metricTracker.track(
                .indoorMissionEasyDayActivated,
                userKey: userInfo?.id,
                payload: [
                    "petId": difficulty.petId ?? "",
                    "dayKey": indoorMissionBoard.dayKey,
                    "rewardScale": "0.80"
                ]
            )
            refreshIndoorMissions(now: now)
        case .alreadyUsed:
            indoorMissionStatusMessage = "쉬운 날 모드는 하루에 한 번만 사용할 수 있어요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "petId": difficulty.petId ?? "",
                    "reason": "daily_limit"
                ]
            )
        case .missingPet:
            indoorMissionStatusMessage = "선택 반려견을 먼저 지정한 뒤 다시 시도해주세요."
            metricTracker.track(
                .indoorMissionEasyDayRejected,
                userKey: userInfo?.id,
                payload: [
                    "reason": "missing_pet"
                ]
            )
        }
    }

    private func makeIndoorMissionPetContext(reference: Date) -> IndoorMissionPetContext {
        let fourteenDaysAgo = reference.addingTimeInterval(-14 * 24 * 3600)
        let twentyEightDaysAgo = reference.addingTimeInterval(-28 * 24 * 3600)
        let recentPolygons = polygonList.filter { Date(timeIntervalSince1970: $0.createdAt) >= fourteenDaysAgo }
        let monthlyPolygons = polygonList.filter { Date(timeIntervalSince1970: $0.createdAt) >= twentyEightDaysAgo }
        let totalRecentMinutes = recentPolygons.reduce(0.0) { partial, polygon in
            partial + max(0, polygon.walkingTime) / 60.0
        }
        let recentDailyMinutes = totalRecentMinutes / 14.0
        let averageWeeklyWalkCount = Double(monthlyPolygons.count) / 4.0

        return .init(
            petId: selectedPet?.petId,
            petName: selectedPet?.petName ?? "강아지",
            ageYears: selectedPet?.ageYears,
            recentDailyMinutes: recentDailyMinutes,
            averageWeeklyWalkCount: averageWeeklyWalkCount
        )
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

enum IndoorMissionPetAgeBand: String, Codable, Equatable {
    case puppy
    case adult
    case senior
    case unknown

    var title: String {
        switch self {
        case .puppy: return "유년기"
        case .adult: return "성견"
        case .senior: return "노령기"
        case .unknown: return "연령 미지정"
        }
    }
}

enum IndoorMissionActivityLevel: String, Codable, Equatable {
    case low
    case moderate
    case high

    var title: String {
        switch self {
        case .low: return "저활동"
        case .moderate: return "보통 활동"
        case .high: return "고활동"
        }
    }
}

enum IndoorMissionWalkFrequencyBand: String, Codable, Equatable {
    case sparse
    case steady
    case frequent

    var title: String {
        switch self {
        case .sparse: return "산책 빈도 낮음"
        case .steady: return "산책 빈도 보통"
        case .frequent: return "산책 빈도 높음"
        }
    }
}

enum IndoorMissionEasyDayState: String, Codable, Equatable {
    case unavailable
    case available
    case active
}

struct IndoorMissionPetContext: Equatable {
    let petId: String?
    let petName: String
    let ageYears: Int?
    let recentDailyMinutes: Double
    let averageWeeklyWalkCount: Double
}

struct IndoorMissionDifficultyHistoryEntry: Identifiable, Equatable {
    var id: String {
        "\(dayKey)|\(petId)"
    }

    let dayKey: String
    let petId: String
    let petName: String
    let multiplier: Double
    let ageBand: IndoorMissionPetAgeBand
    let activityLevel: IndoorMissionActivityLevel
    let walkFrequency: IndoorMissionWalkFrequencyBand
    let easyDayApplied: Bool
}

struct IndoorMissionDifficultySummary: Equatable {
    let petId: String?
    let petName: String
    let ageBand: IndoorMissionPetAgeBand
    let activityLevel: IndoorMissionActivityLevel
    let walkFrequency: IndoorMissionWalkFrequencyBand
    let appliedMultiplier: Double
    let adjustmentDescription: String
    let reasons: [String]
    let easyDayState: IndoorMissionEasyDayState
    let easyDayMessage: String
    let history: [IndoorMissionDifficultyHistoryEntry]
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
    let trackingMissionId: String
    let dayKey: String
    let isExtension: Bool
    let extensionSourceDayKey: String?
    let extensionRewardScale: Double
    let progress: IndoorMissionProgress
}

enum IndoorMissionExtensionState: String, Codable, Equatable {
    case none
    case active
    case consumed
    case expired
    case cooldown

    var shouldDisplayCard: Bool {
        switch self {
        case .none:
            return false
        case .active, .consumed, .expired, .cooldown:
            return true
        }
    }
}

struct IndoorMissionBoard: Equatable {
    let riskLevel: IndoorWeatherRiskLevel
    let dayKey: String
    let missions: [IndoorMissionCardModel]
    let extensionState: IndoorMissionExtensionState
    let extensionMessage: String?
    let difficultySummary: IndoorMissionDifficultySummary?

    var isIndoorReplacementActive: Bool {
        riskLevel != .clear && missions.isEmpty == false
    }

    var shouldDisplayCard: Bool {
        missions.isEmpty == false || extensionState.shouldDisplayCard || difficultySummary != nil
    }

    static let empty = IndoorMissionBoard(
        riskLevel: .clear,
        dayKey: "",
        missions: [],
        extensionState: .none,
        extensionMessage: nil,
        difficultySummary: nil
    )

    func updated(_ mission: IndoorMissionCardModel) -> IndoorMissionBoard {
        let replaced = missions.map { existing in
            existing.id == mission.id ? mission : existing
        }
        return .init(
            riskLevel: riskLevel,
            dayKey: dayKey,
            missions: replaced,
            extensionState: extensionState,
            extensionMessage: extensionMessage,
            difficultySummary: difficultySummary
        )
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
    private struct IndoorMissionExtensionEntry: Codable, Equatable {
        let dayKey: String
        let sourceDayKey: String?
        let missionId: String?
        let rewardScale: Double
        var state: IndoorMissionExtensionState

        var hasAllocation: Bool {
            guard let sourceDayKey, sourceDayKey.isEmpty == false,
                  let missionId, missionId.isEmpty == false else {
                return false
            }
            return true
        }
    }

    private struct IndoorMissionDifficultyLedgerEntry: Codable, Equatable {
        let dayKey: String
        let petId: String
        let petName: String
        let ageBand: IndoorMissionPetAgeBand
        let activityLevel: IndoorMissionActivityLevel
        let walkFrequency: IndoorMissionWalkFrequencyBand
        let multiplier: Double
        let reasons: [String]
        let easyDayApplied: Bool
        let updatedAt: TimeInterval
    }

    enum EasyDayActivationOutcome {
        case activated
        case alreadyUsed
        case missingPet
    }

    private enum DefaultsKey {
        static let weatherRiskOverride = "weather.risk.level.v1"
        static let actionCounts = "indoor.mission.actionCounts.v1"
        static let completionFlags = "indoor.mission.completed.v1"
        static let exposureHistory = "indoor.mission.exposureHistory.v1"
        static let weatherFeedbackTimestamps = "weather.feedback.timestamps.v1"
        static let weatherFeedbackDailyAdjustment = "weather.feedback.dailyAdjustment.v1"
        static let extensionLedger = "indoor.mission.extensionLedger.v1"
        static let easyDayUsage = "indoor.mission.easyDayUsage.v1"
        static let difficultyLedger = "indoor.mission.difficultyLedger.v1"
    }

    let weeklyFeedbackLimit = 2
    let extensionRewardScale = 0.70
    let easyDayRewardScale = 0.80
    let maxDailyDifficultyDelta = 0.15

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
        buildBoard(now: now, context: nil)
    }

    func buildBoard(now: Date, context: IndoorMissionPetContext?) -> IndoorMissionBoard {
        let riskLevel = resolveRiskLevel(now: now)
        let dayKey = dayStamp(for: now)
        let difficultySummary = resolveDifficultySummary(
            context: context,
            dayKey: dayKey,
            now: now
        )
        let easyDayRewardMultiplier = difficultySummary?.easyDayState == .active ? easyDayRewardScale : 1.0
        let selectedTemplates: [IndoorMissionTemplate]
        if riskLevel.replacementMissionCount > 0 {
            selectedTemplates = selectedTemplatesForToday(riskLevel: riskLevel, dayKey: dayKey)
        } else {
            selectedTemplates = []
        }
        let missions = selectedTemplates.map { template in
            makeCardModel(
                template: template,
                riskLevel: riskLevel,
                dayKey: dayKey,
                difficultyMultiplier: difficultySummary?.appliedMultiplier ?? 1.0,
                rewardScale: easyDayRewardMultiplier
            )
        }
        let extensionEntry = resolveExtensionEntry(dayKey: dayKey)
        var combinedMissions = missions
        if let extensionMission = makeExtensionCardModel(
            entry: extensionEntry,
            riskLevel: riskLevel,
            difficultyMultiplier: difficultySummary?.appliedMultiplier ?? 1.0,
            easyDayRewardScale: easyDayRewardMultiplier
        ) {
            combinedMissions.insert(extensionMission, at: 0)
        }

        if combinedMissions.isEmpty,
           extensionEntry.state == .none,
           difficultySummary == nil {
            return .init(
                riskLevel: riskLevel,
                dayKey: dayKey,
                missions: [],
                extensionState: .none,
                extensionMessage: nil,
                difficultySummary: nil
            )
        }

        return .init(
            riskLevel: riskLevel,
            dayKey: dayKey,
            missions: combinedMissions,
            extensionState: extensionEntry.state,
            extensionMessage: extensionMessage(for: extensionEntry),
            difficultySummary: difficultySummary
        )
    }

    func activateEasyDayMode(petId: String?, now: Date = Date()) -> EasyDayActivationOutcome {
        guard let petId, petId.isEmpty == false else { return .missingPet }
        let dayKey = dayStamp(for: now)
        let key = easyDayKey(dayKey: dayKey, petId: petId)
        var map = easyDayUsageMap()
        if map[key] != nil {
            return .alreadyUsed
        }
        map[key] = now.timeIntervalSince1970
        persistEasyDayUsageMap(map, currentDayKey: dayKey)
        return .activated
    }

    func incrementActionCount(missionId: String, dayKey: String) {
        let key = actionKey(missionId: missionId, dayKey: dayKey)
        var counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: DefaultsKey.actionCounts)
    }

    func confirmCompletion(
        missionId: String,
        dayKey: String,
        minimumActionCount: Int,
        now: Date = Date()
    ) -> IndoorMissionCompletionResult {
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

    @discardableResult
    func markExtensionConsumedIfNeeded(_ mission: IndoorMissionCardModel, now: Date = Date()) -> Bool {
        guard mission.isExtension else { return false }
        let dayKey = dayStamp(for: now)
        var ledger = extensionLedger()
        guard var entry = ledger[dayKey], entry.hasAllocation else { return false }
        guard entry.missionId == mission.trackingMissionId else { return false }
        guard entry.state == .active else { return false }
        entry.state = .consumed
        ledger[dayKey] = entry
        persistExtensionLedger(ledger)
        return true
    }

    func updatedMissionState(_ mission: IndoorMissionCardModel) -> IndoorMissionCardModel {
        let key = actionKey(missionId: mission.trackingMissionId, dayKey: mission.dayKey)
        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]

        return .init(
            id: mission.id,
            category: mission.category,
            title: mission.title,
            description: mission.description,
            minimumActionCount: mission.minimumActionCount,
            rewardPoint: mission.rewardPoint,
            streakEligible: mission.streakEligible,
            trackingMissionId: mission.trackingMissionId,
            dayKey: mission.dayKey,
            isExtension: mission.isExtension,
            extensionSourceDayKey: mission.extensionSourceDayKey,
            extensionRewardScale: mission.extensionRewardScale,
            progress: .init(
                actionCount: counts[key] ?? 0,
                minimumActionCount: mission.minimumActionCount,
                isCompleted: completed[key] != nil
            )
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
        dayKey: String,
        displayId: String? = nil,
        trackingMissionId: String? = nil,
        isExtension: Bool = false,
        extensionSourceDayKey: String? = nil,
        difficultyMultiplier: Double = 1.0,
        rewardScale: Double = 1.0,
        extensionScale: Double = 1.0,
        streakEligibleOverride: Bool? = nil
    ) -> IndoorMissionCardModel {
        let trackingId = trackingMissionId ?? template.id
        let key = actionKey(missionId: trackingId, dayKey: dayKey)
        let counts = UserDefaults.standard.dictionary(forKey: DefaultsKey.actionCounts) as? [String: Int] ?? [:]
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        let actionCount = counts[key] ?? 0
        let isCompleted = completed[key] != nil
        let adjustedMinimumAction = max(
            1,
            Int((Double(template.minimumActionCount) * difficultyMultiplier).rounded())
        )
        let reward = Int((Double(template.baseRewardPoint) * riskLevel.rewardScale * rewardScale * extensionScale).rounded())

        return .init(
            id: displayId ?? template.id,
            category: template.category,
            title: template.title,
            description: template.description,
            minimumActionCount: adjustedMinimumAction,
            rewardPoint: max(1, reward),
            streakEligible: streakEligibleOverride ?? template.streakEligible,
            trackingMissionId: trackingId,
            dayKey: dayKey,
            isExtension: isExtension,
            extensionSourceDayKey: extensionSourceDayKey,
            extensionRewardScale: extensionScale,
            progress: .init(
                actionCount: actionCount,
                minimumActionCount: adjustedMinimumAction,
                isCompleted: isCompleted
            )
        )
    }

    private func makeExtensionCardModel(
        entry: IndoorMissionExtensionEntry,
        riskLevel: IndoorWeatherRiskLevel,
        difficultyMultiplier: Double,
        easyDayRewardScale: Double
    ) -> IndoorMissionCardModel? {
        guard entry.state == .active || entry.state == .consumed else { return nil }
        guard let sourceDayKey = entry.sourceDayKey,
              let missionId = entry.missionId,
              let template = template(for: missionId) else {
            return nil
        }

        let displayId = "\(missionId)|extension|\(sourceDayKey)"
        return makeCardModel(
            template: template,
            riskLevel: riskLevel,
            dayKey: sourceDayKey,
            displayId: displayId,
            trackingMissionId: missionId,
            isExtension: true,
            extensionSourceDayKey: sourceDayKey,
            difficultyMultiplier: difficultyMultiplier,
            rewardScale: easyDayRewardScale,
            extensionScale: entry.rewardScale,
            streakEligibleOverride: false
        )
    }

    private func template(for missionId: String) -> IndoorMissionTemplate? {
        templates.first(where: { $0.id == missionId })
    }

    private func extensionMessage(for entry: IndoorMissionExtensionEntry) -> String? {
        switch entry.state {
        case .none:
            return nil
        case .active:
            return "전일 미션 1개를 자동 연장했어요. 완료 시 보상은 기본의 70%만 지급돼요."
        case .consumed:
            return "연장 슬롯 사용 완료. 연장 미션은 시즌 점수/연속 보상에서 제외돼요."
        case .expired:
            return "전일 연장 미션이 미완료로 소멸되어 오늘은 자동 연장이 제공되지 않아요."
        case .cooldown:
            return "연장 슬롯은 연속 2일 이상 자동 적용되지 않아요. 오늘은 쿨다운 상태예요."
        }
    }

    private func resolveExtensionEntry(dayKey: String) -> IndoorMissionExtensionEntry {
        var ledger = extensionLedger()
        if var existing = ledger[dayKey] {
            if existing.state == .active,
               let sourceDayKey = existing.sourceDayKey,
               let missionId = existing.missionId,
               isMissionCompleted(missionId: missionId, dayKey: sourceDayKey) {
                existing.state = .consumed
                ledger[dayKey] = existing
                persistExtensionLedger(ledger)
            }
            return existing
        }

        let previousDayKey = previousDayStamps(from: dayKey, count: 1).first
        guard let previousDayKey, previousDayKey.isEmpty == false else {
            let none = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: nil,
                missionId: nil,
                rewardScale: extensionRewardScale,
                state: .none
            )
            ledger[dayKey] = none
            persistExtensionLedger(ledger)
            return none
        }

        if let previousEntry = ledger[previousDayKey], previousEntry.hasAllocation {
            let wasCompleted: Bool
            if let sourceDayKey = previousEntry.sourceDayKey, let missionId = previousEntry.missionId {
                wasCompleted = isMissionCompleted(missionId: missionId, dayKey: sourceDayKey)
            } else {
                wasCompleted = false
            }
            let state: IndoorMissionExtensionState = wasCompleted ? .cooldown : .expired
            let blocked = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: nil,
                missionId: nil,
                rewardScale: extensionRewardScale,
                state: state
            )
            ledger[dayKey] = blocked
            persistExtensionLedger(ledger)
            return blocked
        }

        if let missionId = unresolvedMissionCandidate(from: previousDayKey) {
            let active = IndoorMissionExtensionEntry(
                dayKey: dayKey,
                sourceDayKey: previousDayKey,
                missionId: missionId,
                rewardScale: extensionRewardScale,
                state: .active
            )
            ledger[dayKey] = active
            persistExtensionLedger(ledger)
            return active
        }

        let none = IndoorMissionExtensionEntry(
            dayKey: dayKey,
            sourceDayKey: nil,
            missionId: nil,
            rewardScale: extensionRewardScale,
            state: .none
        )
        ledger[dayKey] = none
        persistExtensionLedger(ledger)
        return none
    }

    private func unresolvedMissionCandidate(from dayKey: String) -> String? {
        let history = UserDefaults.standard.dictionary(forKey: DefaultsKey.exposureHistory) as? [String: [String]] ?? [:]
        let missionIds = history[dayKey] ?? []
        guard missionIds.isEmpty == false else { return nil }
        return missionIds.first(where: { isMissionCompleted(missionId: $0, dayKey: dayKey) == false })
    }

    private func isMissionCompleted(missionId: String, dayKey: String) -> Bool {
        let key = actionKey(missionId: missionId, dayKey: dayKey)
        let completed = UserDefaults.standard.dictionary(forKey: DefaultsKey.completionFlags) as? [String: TimeInterval] ?? [:]
        return completed[key] != nil
    }

    private func extensionLedger() -> [String: IndoorMissionExtensionEntry] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.extensionLedger) else { return [:] }
        do {
            return try JSONDecoder().decode([String: IndoorMissionExtensionEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistExtensionLedger(_ ledger: [String: IndoorMissionExtensionEntry]) {
        let sortedKeys = ledger.keys.sorted()
        let keysToKeep = Set(sortedKeys.suffix(21))
        let pruned = ledger.filter { keysToKeep.contains($0.key) }
        guard let encoded = try? JSONEncoder().encode(pruned) else { return }
        UserDefaults.standard.set(encoded, forKey: DefaultsKey.extensionLedger)
    }

    private func resolveDifficultySummary(
        context: IndoorMissionPetContext?,
        dayKey: String,
        now: Date
    ) -> IndoorMissionDifficultySummary? {
        guard let context,
              let petId = context.petId,
              petId.isEmpty == false else {
            return nil
        }

        let ageBand = petAgeBand(for: context.ageYears)
        let activityLevel = activityLevel(for: context.recentDailyMinutes)
        let walkFrequency = walkFrequencyBand(for: context.averageWeeklyWalkCount)

        var multiplier = 1.0
        var reasons: [String] = []

        switch ageBand {
        case .puppy:
            multiplier -= 0.08
            reasons.append("유년기 반려견이라 목표를 소폭 완화했어요.")
        case .senior:
            multiplier -= 0.12
            reasons.append("노령기 반려견 컨디션을 고려해 목표를 완화했어요.")
        case .adult, .unknown:
            break
        }

        switch activityLevel {
        case .low:
            multiplier -= 0.12
            reasons.append("최근 활동량이 낮아 완료 경험 안정화를 위해 목표를 낮췄어요.")
        case .high:
            multiplier += 0.10
            reasons.append("최근 활동량이 높아 목표를 조금 높였어요.")
        case .moderate:
            break
        }

        switch walkFrequency {
        case .sparse:
            multiplier -= 0.08
            reasons.append("최근 산책 빈도가 낮아 목표를 완화했어요.")
        case .frequent:
            multiplier += 0.08
            reasons.append("최근 산책 빈도가 높아 목표를 상향했어요.")
        case .steady:
            break
        }

        multiplier = min(max(0.75, multiplier), 1.25)
        if let previous = previousDifficultyMultiplier(petId: petId, beforeDayKey: dayKey) {
            let lowerBound = previous - maxDailyDifficultyDelta
            let upperBound = previous + maxDailyDifficultyDelta
            let clamped = min(max(lowerBound, multiplier), upperBound)
            if abs(clamped - multiplier) > 0.001 {
                reasons.append("급격한 변동을 막기 위해 일일 변동폭 제한을 적용했어요.")
            }
            multiplier = clamped
        }
        multiplier = min(max(0.75, multiplier), 1.25)

        let easyDayApplied = isEasyDayActive(dayKey: dayKey, petId: petId)
        upsertDifficultyLedgerEntry(
            dayKey: dayKey,
            petId: petId,
            petName: context.petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            multiplier: multiplier,
            reasons: reasons,
            easyDayApplied: easyDayApplied,
            now: now
        )

        let adjustmentPercent = Int(((multiplier - 1.0) * 100).rounded())
        let adjustmentDescription: String
        if adjustmentPercent == 0 {
            adjustmentDescription = "기본 난이도 유지"
        } else if adjustmentPercent > 0 {
            adjustmentDescription = "기본 대비 +\(adjustmentPercent)%"
        } else {
            adjustmentDescription = "기본 대비 \(adjustmentPercent)%"
        }

        let easyDayState: IndoorMissionEasyDayState = easyDayApplied ? .active : .available
        let easyDayMessage: String = easyDayApplied
            ? "오늘 쉬운 날 모드가 적용되어 보상이 20% 감액돼요."
            : "쉬운 날 모드(일 1회) 사용 시 오늘 목표를 더 쉽게 진행하고 보상은 20% 감액돼요."

        return .init(
            petId: petId,
            petName: context.petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            appliedMultiplier: multiplier,
            adjustmentDescription: adjustmentDescription,
            reasons: reasons,
            easyDayState: easyDayState,
            easyDayMessage: easyDayMessage,
            history: difficultyHistory(for: petId)
        )
    }

    private func petAgeBand(for ageYears: Int?) -> IndoorMissionPetAgeBand {
        guard let ageYears else { return .unknown }
        if ageYears <= 1 { return .puppy }
        if ageYears >= 10 { return .senior }
        return .adult
    }

    private func activityLevel(for recentDailyMinutes: Double) -> IndoorMissionActivityLevel {
        if recentDailyMinutes < 20 { return .low }
        if recentDailyMinutes > 65 { return .high }
        return .moderate
    }

    private func walkFrequencyBand(for averageWeeklyWalkCount: Double) -> IndoorMissionWalkFrequencyBand {
        if averageWeeklyWalkCount < 3 { return .sparse }
        if averageWeeklyWalkCount > 10 { return .frequent }
        return .steady
    }

    private func difficultyLedger() -> [String: IndoorMissionDifficultyLedgerEntry] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.difficultyLedger) else { return [:] }
        do {
            return try JSONDecoder().decode([String: IndoorMissionDifficultyLedgerEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistDifficultyLedger(_ ledger: [String: IndoorMissionDifficultyLedgerEntry], dayKey: String) {
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 42) + [dayKey])
        let filtered = ledger.filter { keysToKeep.contains($0.value.dayKey) }
        guard let encoded = try? JSONEncoder().encode(filtered) else { return }
        UserDefaults.standard.set(encoded, forKey: DefaultsKey.difficultyLedger)
    }

    private func upsertDifficultyLedgerEntry(
        dayKey: String,
        petId: String,
        petName: String,
        ageBand: IndoorMissionPetAgeBand,
        activityLevel: IndoorMissionActivityLevel,
        walkFrequency: IndoorMissionWalkFrequencyBand,
        multiplier: Double,
        reasons: [String],
        easyDayApplied: Bool,
        now: Date
    ) {
        let key = difficultyKey(dayKey: dayKey, petId: petId)
        var ledger = difficultyLedger()
        ledger[key] = .init(
            dayKey: dayKey,
            petId: petId,
            petName: petName,
            ageBand: ageBand,
            activityLevel: activityLevel,
            walkFrequency: walkFrequency,
            multiplier: multiplier,
            reasons: reasons,
            easyDayApplied: easyDayApplied,
            updatedAt: now.timeIntervalSince1970
        )
        persistDifficultyLedger(ledger, dayKey: dayKey)
    }

    private func previousDifficultyMultiplier(petId: String, beforeDayKey dayKey: String) -> Double? {
        let ledger = difficultyLedger()
        let previousKeys = previousDayStamps(from: dayKey, count: 7)
        for key in previousKeys {
            let lookup = difficultyKey(dayKey: key, petId: petId)
            if let entry = ledger[lookup] {
                return entry.multiplier
            }
        }
        return nil
    }

    private func difficultyHistory(for petId: String) -> [IndoorMissionDifficultyHistoryEntry] {
        let entries = difficultyLedger().values
            .filter { $0.petId == petId }
            .sorted { lhs, rhs in
                if lhs.dayKey == rhs.dayKey {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.dayKey > rhs.dayKey
            }
            .prefix(5)

        return entries.map { entry in
            .init(
                dayKey: entry.dayKey,
                petId: entry.petId,
                petName: entry.petName,
                multiplier: entry.multiplier,
                ageBand: entry.ageBand,
                activityLevel: entry.activityLevel,
                walkFrequency: entry.walkFrequency,
                easyDayApplied: entry.easyDayApplied
            )
        }
    }

    private func easyDayUsageMap() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.easyDayUsage) as? [String: TimeInterval] ?? [:]
    }

    private func persistEasyDayUsageMap(_ map: [String: TimeInterval], currentDayKey: String) {
        let keysToKeep = Set(previousDayStamps(from: currentDayKey, count: 14) + [currentDayKey])
        let filtered = map.filter { key, _ in
            let dayKey = key.components(separatedBy: "|").first ?? ""
            return keysToKeep.contains(dayKey)
        }
        UserDefaults.standard.set(filtered, forKey: DefaultsKey.easyDayUsage)
    }

    private func easyDayKey(dayKey: String, petId: String) -> String {
        "\(dayKey)|\(petId)"
    }

    private func isEasyDayActive(dayKey: String, petId: String) -> Bool {
        let key = easyDayKey(dayKey: dayKey, petId: petId)
        return easyDayUsageMap()[key] != nil
    }

    private func difficultyKey(dayKey: String, petId: String) -> String {
        "\(dayKey)|\(petId)"
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
