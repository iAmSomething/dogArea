//
//  HomeViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

enum QuestMotionEventType: String, Equatable {
    case progress
    case completed
    case failed
    case alreadyCompleted
}

struct QuestMotionEvent: Identifiable, Equatable {
    let id = UUID()
    let missionId: String
    let missionTitle: String
    let type: QuestMotionEventType
    let progress: Double
}

struct QuestCompletionPresentation: Identifiable, Equatable {
    let id = UUID()
    let missionId: String
    let missionTitle: String
    let rewardPoint: Int
}

enum SeasonMotionEventType: String, Equatable {
    case scoreIncreased
    case rankUp
    case shieldApplied
    case seasonReset
}

struct SeasonMotionEvent: Identifiable, Equatable {
    let id = UUID()
    let type: SeasonMotionEventType
    let scoreDelta: Double
    let rankTier: SeasonRankTier
    let shieldApplied: Bool
}

struct SeasonMotionSummary: Equatable {
    let weekKey: String
    let score: Double
    let targetScore: Double
    let progress: Double
    let rankTier: SeasonRankTier
    let todayScoreDelta: Int
    let contributionCount: Int
    let weatherShieldActive: Bool
    let weatherShieldApplyCount: Int

    static let empty = SeasonMotionSummary(
        weekKey: "",
        score: 0,
        targetScore: 520,
        progress: 0,
        rankTier: .rookie,
        todayScoreDelta: 0,
        contributionCount: 0,
        weatherShieldActive: false,
        weatherShieldApplyCount: 0
    )
}

struct SeasonResultPresentation: Identifiable, Equatable {
    let id = UUID()
    let weekKey: String
    let rankTier: SeasonRankTier
    let totalScore: Int
    let contributionCount: Int
    let shieldApplyCount: Int
}

enum SeasonRewardClaimStatus: String, Codable, Equatable {
    case pending
    case claimed
    case failed
}

struct WeatherMissionStatusSummary: Equatable {
    let badgeText: String
    let title: String
    let reasonText: String
    let appliedAtText: String
    let shieldUsageText: String
    let fallbackNotice: String?
    let accessibilityText: String
    let isFallback: Bool
    let riskLevel: IndoorWeatherRiskLevel

    static let empty = WeatherMissionStatusSummary(
        badgeText: "정상",
        title: "오늘 날씨 연동 상태",
        reasonText: "기본 퀘스트 진행",
        appliedAtText: "적용 시점 -",
        shieldUsageText: "보호 사용 0회",
        fallbackNotice: nil,
        accessibilityText: "오늘 날씨 연동 상태. 기본 퀘스트 진행.",
        isFallback: false,
        riskLevel: .clear
    )
}

struct WeatherShieldDailySummary: Equatable {
    let dayKey: String
    let applyCount: Int
    let lastAppliedAtText: String
}

private enum QuestReminderApplyResult: Equatable {
    case enabled
    case disabled
    case permissionDenied
    case requiresPermission
}

private protocol QuestReminderScheduling {
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        hour: Int,
        minute: Int
    ) async -> QuestReminderApplyResult
}

private final class QuestReminderPreferenceStore {
    private let defaults = UserDefaults.standard
    private let key = "home.quest.reminder.enabled.v1"

    /// 저장된 퀘스트 리마인드 on/off 상태를 반환합니다.
    var isEnabled: Bool {
        defaults.object(forKey: key) as? Bool ?? false
    }

    /// 퀘스트 리마인드 on/off 상태를 저장합니다.
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
    }
}

private final class LocalQuestReminderScheduler: QuestReminderScheduling {
    private let center: UNUserNotificationCenter
    private let requestId = "home.quest.daily.reminder.v1"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 하루 1회 퀘스트 리마인드 알림을 설정하거나 해제합니다.
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        hour: Int,
        minute: Int
    ) async -> QuestReminderApplyResult {
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [requestId])
            center.removeDeliveredNotifications(withIdentifiers: [requestId])
            return .disabled
        }

        let authorization = await ensureAuthorization(allowPrompt: allowAuthorizationPrompt)
        switch authorization {
        case .enabled:
            break
        case .permissionDenied:
            return .permissionDenied
        case .requiresPermission:
            return .requiresPermission
        case .disabled:
            return .permissionDenied
        }

        center.removePendingNotificationRequests(withIdentifiers: [requestId])

        let content = UNMutableNotificationContent()
        content.title = "오늘 산책 퀘스트 확인할 시간이에요"
        content.body = "홈에서 오늘 미션을 확인하고, 짧게 기록해 진행도를 올려보세요."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil ? .enabled : .permissionDenied)
            }
        }
    }

    /// 알림 권한 상태를 확인하고 필요 시 사용자 권한 요청을 실행합니다.
    private func ensureAuthorization(allowPrompt: Bool) async -> QuestReminderApplyResult {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .denied:
            return .permissionDenied
        case .notDetermined:
            guard allowPrompt else { return .requiresPermission }
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted ? .enabled : .permissionDenied)
                }
            }
        @unknown default:
            return .permissionDenied
        }
    }
}

final class HomeViewModel: ObservableObject {
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
    @Published var weatherMissionStatusSummary: WeatherMissionStatusSummary = .empty
    @Published var weatherShieldDailySummary: WeatherShieldDailySummary? = nil
    @Published var seasonCatchupBuffStatusMessage: String? = nil
    @Published var seasonCatchupBuffStatusWarning: Bool = false
    @Published private(set) var isShowingAllRecordsOverride: Bool = false
    @Published private(set) var areaReferenceSections: [AreaReferenceSection] = []
    @Published private(set) var areaReferenceSourceLabel: String = "로컬 비교군"
    @Published private(set) var featuredAreaCount: Int = 0
    @Published var questMotionEvent: QuestMotionEvent? = nil
    @Published var questCompletionPresentation: QuestCompletionPresentation? = nil
    @Published var questReminderEnabled: Bool
    @Published var questAlternativeActionSuggestion: String? = nil
    @Published var seasonMotionSummary: SeasonMotionSummary = .empty
    @Published var seasonMotionEvent: SeasonMotionEvent? = nil
    @Published var seasonResultPresentation: SeasonResultPresentation? = nil
    @Published var seasonResetTransitionToken: UUID? = nil
    @Published var seasonRemainingTimeText: String = "-"
    @Published var lastSeasonResultPresentation: SeasonResultPresentation? = nil

    private var allPolygons: [Polygon] = []
    private var cancellables: Set<AnyCancellable> = []
    private var lastIndoorMissionExposureTrackKey: String = ""
    private var lastIndoorMissionExtensionTrackKey: String = ""
    private var lastIndoorMissionDifficultyTrackKey: String = ""
    private let indoorMissionStore = IndoorMissionStore()
    private let metricTracker = AppMetricTracker.shared
    private let areaReferenceRepository: AreaReferenceRepository
    private let walkRepository: WalkRepositoryProtocol
    private let userSessionStore: UserSessionStoreProtocol
    private let eventCenter: AppEventCenterProtocol
    private let seasonMotionStore = SeasonMotionStore()
    private let questReminderScheduler: QuestReminderScheduling
    private let questReminderPreferenceStore = QuestReminderPreferenceStore()
    private var featuredGoalAreas: [AreaMeter] = []
    private var areaReferenceTask: Task<Void, Never>? = nil
    private static let questReminderHour = 20
    private static let questReminderMinute = 0
    private static let catchupExpiryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
    private static let weatherAppliedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
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

    private func localizedCopy(ko: String, en: String) -> String {
        let languageCode = Locale.preferredLanguages.first?.lowercased() ?? "ko"
        return languageCode.hasPrefix("en") ? en : ko
    }

    init(
        areaReferenceRepository: AreaReferenceRepository = SupabaseAreaReferenceRepository.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        eventCenter: AppEventCenterProtocol = DefaultAppEventCenter.shared
    ) {
        self.areaReferenceRepository = areaReferenceRepository
        self.walkRepository = walkRepository
        self.userSessionStore = userSessionStore
        self.eventCenter = eventCenter
        self.questReminderScheduler = LocalQuestReminderScheduler()
        self.questReminderEnabled = false
        self.questReminderEnabled = questReminderPreferenceStore.isEnabled
        bindSelectedPetSync()
        bindTimeBoundaryNotifications()
        bindSeasonCatchupBuffStatusNotifications()
        bindQuestProgressNotifications()
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus()
        fetchData()
        Task { [weak self] in
            await self?.syncQuestReminderOnLaunch()
        }
    }

    deinit {
        areaReferenceTask?.cancel()
    }

    func fetchData() {
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus()
        allPolygons = walkRepository.fetchPolygons()
        applySelectedPetStatistics(shouldUpdateMeter: true)
        myAreaList = walkRepository.fetchAreas()
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
                self.featuredGoalAreas = snapshot.featuredAreas.sorted { $0.area < $1.area }
                self.featuredAreaCount = self.featuredGoalAreas.count
                self.areaReferenceSections = snapshot.sections
                self.areaReferenceSourceLabel = snapshot.source == .remote ? "DB 비교군" : "로컬 비교군 (Fallback)"
                self.updateCurrentMeter()
                self.refreshAreaList()
            }
        }
    }

    func reloadUserInfo() {
        userInfo = userSessionStore.currentUserInfo()
        selectedPet = userSessionStore.selectedPet(from: userInfo)
        selectedPetId = selectedPet?.petId ?? ""
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        isShowingAllRecordsOverride = false
        userSessionStore.setSelectedPetId(petId, source: "home")
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

    func clearQuestCompletionPresentation() {
        questCompletionPresentation = nil
    }

    func clearSeasonResultPresentation() {
        seasonResultPresentation = nil
    }

    func clearSeasonResetTransitionToken() {
        seasonResetTransitionToken = nil
    }

    /// 퀘스트 리마인드 토글 상태를 저장하고 로컬 알림 스케줄을 반영합니다.
    func setQuestReminderEnabled(_ enabled: Bool) {
        guard questReminderEnabled != enabled else { return }
        questReminderEnabled = enabled
        questReminderPreferenceStore.setEnabled(enabled)

        Task { [weak self] in
            await self?.applyQuestReminderPreference(
                enabled: enabled,
                allowAuthorizationPrompt: true
            )
        }
    }

    func reopenLastSeasonResult() {
        guard let last = lastSeasonResultPresentation else { return }
        seasonResultPresentation = last
    }

    func seasonRewardStatus(for weekKey: String) -> SeasonRewardClaimStatus {
        seasonMotionStore.rewardClaimStatus(for: weekKey)
    }

    func retrySeasonRewardClaim(for weekKey: String, cloudSyncAllowed: Bool) {
        let claimResult = seasonMotionStore.claimReward(for: weekKey, cloudSyncAllowed: cloudSyncAllowed)
        indoorMissionStatusMessage = claimResult.message
    }

    private func bindSeasonCatchupBuffStatusNotifications() {
        eventCenter.publisher(for: UserdefaultSetting.seasonCatchupBuffDidUpdateNotification, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSeasonCatchupBuffStatus()
            }
            .store(in: &cancellables)
    }

    private func bindSelectedPetSync() {
        eventCenter.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isShowingAllRecordsOverride = false
                self.reloadUserInfo()
                self.applySelectedPetStatistics()
            }
            .store(in: &cancellables)
    }

    private func bindQuestProgressNotifications() {
        eventCenter.publisher(for: .walkPointRecordedForQuest, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIndoorMissions()
            }
            .store(in: &cancellables)
    }

    private func bindTimeBoundaryNotifications() {
        let timezoneChanged = eventCenter.publisher(for: .NSSystemTimeZoneDidChange, object: nil)
        let dayChanged = eventCenter.publisher(for: .NSCalendarDayChanged, object: nil)

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
        guard let snapshot = userSessionStore.seasonCatchupBuffSnapshot() else {
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

    /// 앱 진입 시 저장된 퀘스트 리마인드 설정을 로컬 알림 스케줄과 동기화합니다.
    private func syncQuestReminderOnLaunch() async {
        await applyQuestReminderPreference(
            enabled: questReminderEnabled,
            allowAuthorizationPrompt: false
        )
    }

    /// 퀘스트 리마인드 설정 변경을 로컬 알림 스케줄에 적용하고 상태 메시지를 갱신합니다.
    private func applyQuestReminderPreference(
        enabled: Bool,
        allowAuthorizationPrompt: Bool
    ) async {
        let result = await questReminderScheduler.applyDailyReminder(
            enabled: enabled,
            allowAuthorizationPrompt: allowAuthorizationPrompt,
            hour: Self.questReminderHour,
            minute: Self.questReminderMinute
        )

        await MainActor.run {
            switch result {
            case .enabled:
                if allowAuthorizationPrompt {
                    indoorMissionStatusMessage = "퀘스트 리마인드를 매일 \(Self.questReminderHour):\(String(format: "%02d", Self.questReminderMinute)) 1회로 설정했어요."
                }
            case .disabled:
                if allowAuthorizationPrompt {
                    indoorMissionStatusMessage = "퀘스트 리마인드를 껐어요."
                }
            case .permissionDenied:
                questReminderEnabled = false
                questReminderPreferenceStore.setEnabled(false)
                indoorMissionStatusMessage = "알림 권한이 꺼져 있어 리마인드를 설정할 수 없어요. 설정 앱에서 알림을 허용한 뒤 다시 시도해주세요."
            case .requiresPermission:
                break
            }
        }
    }

    /// 실패/만료 상황에서 사용자가 다음으로 시도할 행동을 안내하는 문구를 생성합니다.
    private func makeQuestAlternativeActionSuggestion(for board: IndoorMissionBoard) -> String? {
        switch board.extensionState {
        case .expired:
            return "연장 미션이 만료됐어요. 오늘 기본 미션 1개를 먼저 완료해 내일 자동 연장 조건을 회복하세요."
        case .cooldown:
            return "연장 슬롯은 하루 쿨다운이에요. 기본 미션 행동량을 채워 오늘 점수를 먼저 확보하세요."
        default:
            break
        }

        if board.riskLevel != .clear {
            return "악천후일 때는 실내 대체 미션을 우선 진행하세요. 완료 기준 미달이면 행동 +1을 먼저 채워보세요."
        }
        return nil
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
        myAreaList = walkRepository.fetchAreas()
    }

    private func findIndex() -> Int {
        guard let i = krAreas.areas.firstIndex(where: {
            $0.area > myArea.area
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
        let featuredNext = featuredGoalAreas.first(where: { $0.area > myArea.area })
        let defaultNext = krAreas.closeArea(of: myArea.area)
        if let featuredNext, let defaultNext {
            return featuredNext.area <= defaultNext.area ? featuredNext : defaultNext
        }
        return featuredNext ?? defaultNext
    }

    private func shouldUpdateMeter() -> Bool {
        guard let last = walkRepository.fetchAreas().last else { return true }
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
            let currents = krAreas.nearistArea(since: walkRepository.fetchAreas().last, from: myArea.area)
            for c in currents {
                if walkRepository.saveArea(.init(areaName: c.areaName, area: c.area, createdAt: Date().timeIntervalSince1970)) {
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
        questAlternativeActionSuggestion = makeQuestAlternativeActionSuggestion(for: indoorMissionBoard)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(now: now)
        let weatherStatus = indoorMissionStore.weatherStatus(now: now)
        weatherShieldDailySummary = indoorMissionStore.weatherShieldDailySummary(now: now)
        weatherMissionStatusSummary = makeWeatherMissionStatusSummary(
            board: indoorMissionBoard,
            status: weatherStatus,
            now: now
        )
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

        syncSeasonScoreWithWalkSessions(now: now)
        refreshSeasonMotion(now: now)
    }

    func recordIndoorMissionAction(_ missionId: String) {
        guard var mission = indoorMissionBoard.missions.first(where: { $0.id == missionId }) else { return }
        indoorMissionStore.incrementActionCount(
            missionId: mission.trackingMissionId,
            dayKey: mission.dayKey
        )
        mission = indoorMissionStore.updatedMissionState(mission)
        indoorMissionBoard = indoorMissionBoard.updated(mission)
        questMotionEvent = QuestMotionEvent(
            missionId: mission.id,
            missionTitle: mission.title,
            type: .progress,
            progress: mission.progress.progressRatio
        )
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
            questAlternativeActionSuggestion = nil
            let seasonUpdate = seasonMotionStore.recordMissionCompletion(
                rewardPoint: mission.rewardPoint,
                streakEligible: mission.streakEligible,
                riskLevel: indoorMissionBoard.riskLevel
            )
            if seasonUpdate.shieldApplied {
                indoorMissionStore.recordWeatherShieldUsage()
            }
            seasonMotionSummary = seasonUpdate.summary
            if let completedSeason = seasonUpdate.completedSeason {
                seasonResultPresentation = completedSeason
                seasonResetTransitionToken = UUID()
            }
            if seasonUpdate.scoreDelta > 0 || seasonUpdate.rankUp || seasonUpdate.shieldApplied {
                seasonMotionEvent = SeasonMotionEvent(
                    type: seasonUpdate.rankUp ? .rankUp : .scoreIncreased,
                    scoreDelta: seasonUpdate.scoreDelta,
                    rankTier: seasonUpdate.summary.rankTier,
                    shieldApplied: seasonUpdate.shieldApplied
                )
            } else if seasonUpdate.completedSeason != nil {
                seasonMotionEvent = SeasonMotionEvent(
                    type: .seasonReset,
                    scoreDelta: 0,
                    rankTier: seasonUpdate.summary.rankTier,
                    shieldApplied: false
                )
            }
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
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .completed,
                progress: 1.0
            )
            questCompletionPresentation = QuestCompletionPresentation(
                missionId: mission.id,
                missionTitle: mission.title,
                rewardPoint: mission.rewardPoint
            )
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
            questAlternativeActionSuggestion = "행동 +1을 더 누르거나 지도 탭에서 포인트 수동 기록 후 다시 완료를 눌러보세요."
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .failed,
                progress: mission.progress.progressRatio
            )
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
            questAlternativeActionSuggestion = "다른 미션 카드에서 행동량을 채운 뒤 즉시 수령 버튼으로 완료를 진행해보세요."
            questMotionEvent = QuestMotionEvent(
                missionId: mission.id,
                missionTitle: mission.title,
                type: .alreadyCompleted,
                progress: 1.0
            )
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

    /// 이번 주 완료된 산책 세션을 시즌 점수로 1회만 반영합니다.
    private func syncSeasonScoreWithWalkSessions(now: Date) {
        let weekInterval = currentWeekInterval(reference: now)
        let inputs: [SeasonWalkContributionInput] = polygonList.compactMap { polygon in
            guard sessionOverlaps(polygon, with: weekInterval) else { return nil }
            let interval = sessionInterval(for: polygon)
            return SeasonWalkContributionInput(
                sessionId: polygon.id.uuidString.lowercased(),
                areaM2: max(0, polygon.walkingArea),
                durationSec: max(0, polygon.walkingTime),
                eventAt: interval.end.timeIntervalSince1970
            )
        }

        guard let update = seasonMotionStore.recordWalkContributions(
            sessions: inputs,
            riskLevel: indoorMissionBoard.riskLevel,
            now: now
        ) else {
            return
        }

        seasonMotionSummary = update.summary
        if let completedSeason = update.completedSeason {
            seasonResultPresentation = completedSeason
            lastSeasonResultPresentation = completedSeason
            seasonResetTransitionToken = UUID()
        }
        if update.scoreDelta > 0 || update.rankUp {
            seasonMotionEvent = SeasonMotionEvent(
                type: update.rankUp ? .rankUp : .scoreIncreased,
                scoreDelta: update.scoreDelta,
                rankTier: update.summary.rankTier,
                shieldApplied: false
            )
        }
    }

    private func refreshSeasonMotion(now: Date) {
        let refresh = seasonMotionStore.refresh(
            now: now,
            riskLevel: indoorMissionBoard.riskLevel
        )
        seasonMotionSummary = refresh.summary
        seasonRemainingTimeText = seasonMotionStore.remainingTimeText(now: now)
        lastSeasonResultPresentation = seasonMotionStore.loadLastCompletedSeason()
        if let completedSeason = refresh.completedSeason {
            seasonResultPresentation = completedSeason
            lastSeasonResultPresentation = completedSeason
            seasonResetTransitionToken = UUID()
            seasonMotionEvent = SeasonMotionEvent(
                type: .seasonReset,
                scoreDelta: 0,
                rankTier: refresh.summary.rankTier,
                shieldApplied: false
            )
        }
    }

    private func makeWeatherMissionStatusSummary(
        board: IndoorMissionBoard,
        status: IndoorWeatherStatus,
        now: Date
    ) -> WeatherMissionStatusSummary {
        let badgeText: String
        if status.source == .fallback {
            badgeText = localizedCopy(ko: "기본 모드", en: "Base Mode")
        } else if board.riskLevel == .clear {
            badgeText = localizedCopy(ko: "정상", en: "Normal")
        } else {
            badgeText = localizedCopy(ko: "치환", en: "Replaced")
        }

        let reasonText: String
        if status.source == .fallback {
            reasonText = localizedCopy(
                ko: "날씨 연동이 아직 준비되지 않아 기본 퀘스트로 진행합니다.",
                en: "Weather integration is not ready yet. Running default quests."
            )
        } else if board.riskLevel == .clear {
            reasonText = localizedCopy(
                ko: "날씨 안정 단계로 기본 퀘스트를 진행합니다.",
                en: "Stable weather. Running default quests."
            )
        } else {
            reasonText = localizedCopy(
                ko: "\(board.riskLevel.displayTitle) 단계로 일부 실외 목표를 실내 미션으로 치환했어요.",
                en: "Risk \(board.riskLevel.rawValue) replaced some outdoor goals with indoor missions."
            )
        }

        let appliedTimestamp = status.lastUpdatedAt ?? now.timeIntervalSince1970
        let appliedTime = Self.weatherAppliedTimeFormatter.string(from: Date(timeIntervalSince1970: appliedTimestamp))
        let shieldCount = weatherShieldDailySummary?.applyCount ?? indoorMissionStore.weatherShieldDailySummary(now: now)?.applyCount ?? 0
        let shieldText = localizedCopy(
            ko: "보호 사용 \(shieldCount)회",
            en: "Shield used \(shieldCount)x"
        )
        let fallbackNotice: String?
        if status.source == .fallback {
            fallbackNotice = localizedCopy(
                ko: "연동 전에도 산책/기록/퀘스트는 정상적으로 계속됩니다.",
                en: "Walk, logs, and quests continue normally even before weather integration."
            )
        } else {
            fallbackNotice = nil
        }

        let appliedAtText = localizedCopy(
            ko: "적용 시점 \(appliedTime)",
            en: "Applied at \(appliedTime)"
        )
        let accessibilityText = "\(badgeText). \(reasonText). \(appliedAtText). \(shieldText)"

        return WeatherMissionStatusSummary(
            badgeText: badgeText,
            title: localizedCopy(ko: "오늘 날씨 연동 상태", en: "Today's Weather Status"),
            reasonText: reasonText,
            appliedAtText: appliedAtText,
            shieldUsageText: shieldText,
            fallbackNotice: fallbackNotice,
            accessibilityText: accessibilityText,
            isFallback: status.source == .fallback,
            riskLevel: board.riskLevel
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

enum IndoorWeatherRiskSource: String, Equatable {
    case environment
    case userOverride
    case fallback
}

struct IndoorWeatherStatus: Equatable {
    let source: IndoorWeatherRiskSource
    let baseRisk: IndoorWeatherRiskLevel
    let adjustedRisk: IndoorWeatherRiskLevel
    let lastUpdatedAt: TimeInterval?
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
        static let weatherShieldUsage = "weather.shield.usage.v1"
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

    func weatherStatus(now: Date = Date()) -> IndoorWeatherStatus {
        let base = resolveBaseRiskProfile()
        let dayKey = dayStamp(for: now)
        let adjustment = dailyAdjustmentMap()[dayKey] ?? 0
        let adjusted = adjustedRisk(from: base.risk, step: adjustment)
        return IndoorWeatherStatus(
            source: base.source,
            baseRisk: base.risk,
            adjustedRisk: adjusted,
            lastUpdatedAt: lastWeatherAdjustmentTimestamp(now: now)
        )
    }

    func recordWeatherShieldUsage(now: Date = Date()) {
        let dayKey = dayStamp(for: now)
        var map = weatherShieldUsageMap()
        var values = map[dayKey] ?? []
        values.append(now.timeIntervalSince1970)
        map[dayKey] = values
        let keysToKeep = Set(previousDayStamps(from: dayKey, count: 14) + [dayKey])
        map = map.filter { keysToKeep.contains($0.key) }
        UserDefaults.standard.set(map, forKey: DefaultsKey.weatherShieldUsage)
    }

    func weatherShieldDailySummary(now: Date = Date()) -> WeatherShieldDailySummary? {
        let dayKey = dayStamp(for: now)
        let values = weatherShieldUsageMap()[dayKey] ?? []
        guard values.isEmpty == false else { return nil }
        let lastApplied = values.max() ?? now.timeIntervalSince1970
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return WeatherShieldDailySummary(
            dayKey: dayKey,
            applyCount: values.count,
            lastAppliedAtText: formatter.string(from: Date(timeIntervalSince1970: lastApplied))
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

    private func resolveBaseRiskProfile() -> (risk: IndoorWeatherRiskLevel, source: IndoorWeatherRiskSource) {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let level = IndoorWeatherRiskLevel(rawValue: env.lowercased()) {
            return (level, .environment)
        }
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.weatherRiskOverride),
           let level = IndoorWeatherRiskLevel(rawValue: raw.lowercased()) {
            return (level, .userOverride)
        }
        return (.clear, .fallback)
    }

    private func resolveRiskLevel(now: Date = Date()) -> IndoorWeatherRiskLevel {
        weatherStatus(now: now).adjustedRisk
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

    private func weatherShieldUsageMap() -> [String: [TimeInterval]] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.weatherShieldUsage) as? [String: [TimeInterval]] ?? [:]
    }

    private func lastWeatherAdjustmentTimestamp(now: Date) -> TimeInterval? {
        let dayKey = dayStamp(for: now)
        return feedbackTimestamps().last { timestamp in
            let date = Date(timeIntervalSince1970: timestamp)
            return dayStamp(for: date) == dayKey
        }
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

enum SeasonRankTier: String, Codable, CaseIterable, Equatable {
    case rookie
    case bronze
    case silver
    case gold
    case platinum

    var title: String {
        switch self {
        case .rookie: return "Rookie"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var minimumScore: Double {
        switch self {
        case .rookie: return 0
        case .bronze: return 80
        case .silver: return 180
        case .gold: return 320
        case .platinum: return 520
        }
    }
}

private struct SeasonMotionRefreshResult {
    let summary: SeasonMotionSummary
    let completedSeason: SeasonResultPresentation?
}

private struct SeasonMotionRecordResult {
    let summary: SeasonMotionSummary
    let scoreDelta: Double
    let rankUp: Bool
    let shieldApplied: Bool
    let completedSeason: SeasonResultPresentation?
}

private struct SeasonWalkContributionInput: Equatable {
    let sessionId: String
    let areaM2: Double
    let durationSec: Double
    let eventAt: TimeInterval
}

private final class SeasonMotionStore {
    private struct State: Codable, Equatable {
        let weekKey: String
        var score: Double
        var contributionCount: Int
        var weatherShieldApplyCount: Int
        var updatedAt: TimeInterval
    }

    private struct LastCompletedSeasonState: Codable, Equatable {
        let weekKey: String
        let rankTierRawValue: String
        let totalScore: Int
        let contributionCount: Int
        let shieldApplyCount: Int
        let completedAt: TimeInterval
    }

    private struct RewardClaimState: Codable, Equatable {
        let weekKey: String
        let status: SeasonRewardClaimStatus
        let reason: String?
        let updatedAt: TimeInterval
    }

    private enum DefaultsKey {
        static let currentState = "season.motion.current.v1"
        static let lastCompletedSeason = "season.motion.lastCompletedSeason.v1"
        static let rewardClaimLedger = "season.motion.rewardClaimLedger.v1"
        static let dailyScoreLedger = "season.motion.dailyScoreLedger.v1"
        static let walkContributionLedger = "season.motion.walkContributionLedger.v1"
    }

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "YYYY-'W'ww"
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let targetScore: Double = 520
    private let defaults = UserDefaults.standard

    func refresh(now: Date, riskLevel: IndoorWeatherRiskLevel) -> SeasonMotionRefreshResult {
        let (state, completedSeason) = ensureCurrentState(now: now)
        return SeasonMotionRefreshResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            completedSeason: completedSeason
        )
    }

    func remainingTimeText(now: Date = Date()) -> String {
        let calendar = Calendar(identifier: .iso8601)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return "-"
        }
        let remaining = max(0, Int(weekInterval.end.timeIntervalSince(now)))
        if remaining <= 0 {
            return "시즌 종료"
        }
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        return "\(days)일 \(hours)시간 남음"
    }

    func loadLastCompletedSeason() -> SeasonResultPresentation? {
        guard let data = defaults.data(forKey: DefaultsKey.lastCompletedSeason),
              let decoded = try? JSONDecoder().decode(LastCompletedSeasonState.self, from: data),
              let rankTier = SeasonRankTier(rawValue: decoded.rankTierRawValue) else {
            return nil
        }

        return SeasonResultPresentation(
            weekKey: decoded.weekKey,
            rankTier: rankTier,
            totalScore: decoded.totalScore,
            contributionCount: decoded.contributionCount,
            shieldApplyCount: decoded.shieldApplyCount
        )
    }

    func rewardClaimStatus(for weekKey: String) -> SeasonRewardClaimStatus {
        rewardClaimLedger()[weekKey]?.status ?? .pending
    }

    @discardableResult
    func claimReward(for weekKey: String, cloudSyncAllowed: Bool, now: Date = Date()) -> (status: SeasonRewardClaimStatus, message: String) {
        if rewardClaimStatus(for: weekKey) == .claimed {
            return (.claimed, "이미 시즌 보상을 수령했어요.")
        }

        if cloudSyncAllowed == false {
            updateRewardClaimState(
                weekKey: weekKey,
                status: .failed,
                reason: "cloud_sync_disabled",
                now: now
            )
            return (.failed, "보상 수령 실패: 로그인/동기화 활성화 후 재수령해주세요.")
        }

        updateRewardClaimState(
            weekKey: weekKey,
            status: .claimed,
            reason: nil,
            now: now
        )
        return (.claimed, "시즌 보상 수령 완료")
    }

    func recordMissionCompletion(
        rewardPoint: Int,
        streakEligible: Bool,
        riskLevel: IndoorWeatherRiskLevel,
        now: Date = Date()
    ) -> SeasonMotionRecordResult {
        let ensured = ensureCurrentState(now: now)
        var state = ensured.0
        let completedSeason = ensured.1
        let beforeRank = rankTier(for: state.score)
        var scoreDelta = 0.0

        if streakEligible {
            scoreDelta = Double(max(1, rewardPoint))
            state.score += scoreDelta
            state.contributionCount += 1
            addDailyScore(scoreDelta, weekKey: state.weekKey, now: now)
        }

        let shieldApplied = riskLevel != .clear && streakEligible
        if shieldApplied {
            state.weatherShieldApplyCount += 1
        }

        state.updatedAt = now.timeIntervalSince1970
        persist(state)

        let afterRank = rankTier(for: state.score)
        return SeasonMotionRecordResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            scoreDelta: scoreDelta,
            rankUp: afterRank != beforeRank,
            shieldApplied: shieldApplied,
            completedSeason: completedSeason
        )
    }

    /// 이번 주 산책 세션 중 아직 반영되지 않은 항목을 시즌 점수로 누적합니다.
    func recordWalkContributions(
        sessions: [SeasonWalkContributionInput],
        riskLevel: IndoorWeatherRiskLevel,
        now: Date = Date()
    ) -> SeasonMotionRecordResult? {
        let ensured = ensureCurrentState(now: now)
        var state = ensured.0
        let completedSeason = ensured.1
        let beforeRank = rankTier(for: state.score)
        let weekKey = state.weekKey

        let sortedSessions = sessions.sorted { $0.eventAt < $1.eventAt }
        var ledger = walkContributionLedger()
        var processedIds = Set(ledger[weekKey] ?? [])
        var scoreDelta = 0.0
        var contributionDelta = 0

        for session in sortedSessions {
            let sessionId = session.sessionId.lowercased()
            guard sessionId.isEmpty == false else { continue }
            guard processedIds.contains(sessionId) == false else { continue }

            let reward = walkRewardPoint(
                areaM2: session.areaM2,
                durationSec: session.durationSec
            )
            processedIds.insert(sessionId)
            guard reward > 0 else { continue }

            let rewardAsDouble = Double(reward)
            scoreDelta += rewardAsDouble
            contributionDelta += 1
            state.score += rewardAsDouble
            state.contributionCount += 1
            addDailyScore(
                rewardAsDouble,
                weekKey: weekKey,
                now: Date(timeIntervalSince1970: session.eventAt)
            )
        }

        guard contributionDelta > 0 || completedSeason != nil else {
            return nil
        }

        state.updatedAt = now.timeIntervalSince1970
        persist(state)

        ledger[weekKey] = Array(processedIds).sorted()
        persistWalkContributionLedger(ledger)

        let afterRank = rankTier(for: state.score)
        return SeasonMotionRecordResult(
            summary: summary(from: state, riskLevel: riskLevel, now: now),
            scoreDelta: scoreDelta,
            rankUp: afterRank != beforeRank,
            shieldApplied: false,
            completedSeason: completedSeason
        )
    }

    private func summary(from state: State, riskLevel: IndoorWeatherRiskLevel, now: Date) -> SeasonMotionSummary {
        let score = max(0, state.score)
        let progress = min(1, max(0, score / targetScore))
        return SeasonMotionSummary(
            weekKey: state.weekKey,
            score: score,
            targetScore: targetScore,
            progress: progress,
            rankTier: rankTier(for: score),
            todayScoreDelta: dailyScore(for: state.weekKey, now: now),
            contributionCount: state.contributionCount,
            weatherShieldActive: riskLevel != .clear,
            weatherShieldApplyCount: state.weatherShieldApplyCount
        )
    }

    private func rankTier(for score: Double) -> SeasonRankTier {
        if score >= SeasonRankTier.platinum.minimumScore {
            return .platinum
        }
        if score >= SeasonRankTier.gold.minimumScore {
            return .gold
        }
        if score >= SeasonRankTier.silver.minimumScore {
            return .silver
        }
        if score >= SeasonRankTier.bronze.minimumScore {
            return .bronze
        }
        return .rookie
    }

    private func ensureCurrentState(now: Date) -> (State, SeasonResultPresentation?) {
        let weekKey = currentWeekKey(for: now)
        guard var current = loadCurrentState() else {
            let newState = State(
                weekKey: weekKey,
                score: 0,
                contributionCount: 0,
                weatherShieldApplyCount: 0,
                updatedAt: now.timeIntervalSince1970
            )
            persist(newState)
            return (newState, nil)
        }

        if current.weekKey == weekKey {
            return (current, nil)
        }

        let completedSeason = SeasonResultPresentation(
            weekKey: current.weekKey,
            rankTier: rankTier(for: current.score),
            totalScore: Int(current.score.rounded()),
            contributionCount: current.contributionCount,
            shieldApplyCount: current.weatherShieldApplyCount
        )
        if completedSeason.totalScore > 0 || completedSeason.contributionCount > 0 {
            persistLastCompletedSeason(completedSeason, completedAt: now)
            ensureRewardPending(weekKey: completedSeason.weekKey, now: now)
        }

        current = State(
            weekKey: weekKey,
            score: 0,
            contributionCount: 0,
            weatherShieldApplyCount: 0,
            updatedAt: now.timeIntervalSince1970
        )
        persist(current)
        return (current, completedSeason.totalScore > 0 || completedSeason.contributionCount > 0 ? completedSeason : nil)
    }

    private func currentWeekKey(for date: Date) -> String {
        Self.weekFormatter.string(from: date)
    }

    private func loadCurrentState() -> State? {
        guard let data = defaults.data(forKey: DefaultsKey.currentState),
              let decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func persist(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: DefaultsKey.currentState)
    }

    private func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func dailyLedgerEntryKey(weekKey: String, dayKey: String) -> String {
        "\(weekKey)|\(dayKey)"
    }

    private func walkContributionLedger() -> [String: [String]] {
        guard let data = defaults.data(forKey: DefaultsKey.walkContributionLedger),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistWalkContributionLedger(_ ledger: [String: [String]]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(16))
        let trimmed = ledger
            .filter { keysToKeep.contains($0.key) }
            .mapValues { Array(Set($0)).sorted() }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.walkContributionLedger)
    }

    /// 산책 1세션의 면적/시간을 점수로 환산합니다.
    private func walkRewardPoint(areaM2: Double, durationSec: Double) -> Int {
        let safeArea = max(0, areaM2)
        let safeDuration = max(0, durationSec)
        var score = 8
        if safeArea >= 2_000 { score += 4 }
        if safeArea >= 8_000 { score += 4 }
        if safeDuration >= 1_200 { score += 2 }    // 20분
        if safeDuration >= 2_400 { score += 2 }    // 40분
        return min(24, max(4, score))
    }

    private func dailyScoreLedger() -> [String: Double] {
        guard let data = defaults.data(forKey: DefaultsKey.dailyScoreLedger),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistDailyScoreLedger(_ ledger: [String: Double]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(84))
        let trimmed = ledger.filter { keysToKeep.contains($0.key) }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.dailyScoreLedger)
    }

    private func dailyScore(for weekKey: String, now: Date) -> Int {
        let key = dailyLedgerEntryKey(weekKey: weekKey, dayKey: dayKey(for: now))
        return Int((dailyScoreLedger()[key] ?? 0).rounded())
    }

    private func addDailyScore(_ delta: Double, weekKey: String, now: Date) {
        guard delta > 0 else { return }
        let key = dailyLedgerEntryKey(weekKey: weekKey, dayKey: dayKey(for: now))
        var ledger = dailyScoreLedger()
        ledger[key, default: 0] += delta
        persistDailyScoreLedger(ledger)
    }

    private func persistLastCompletedSeason(_ result: SeasonResultPresentation, completedAt: Date) {
        let encodedState = LastCompletedSeasonState(
            weekKey: result.weekKey,
            rankTierRawValue: result.rankTier.rawValue,
            totalScore: result.totalScore,
            contributionCount: result.contributionCount,
            shieldApplyCount: result.shieldApplyCount,
            completedAt: completedAt.timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(encodedState) else { return }
        defaults.set(data, forKey: DefaultsKey.lastCompletedSeason)
    }

    private func rewardClaimLedger() -> [String: RewardClaimState] {
        guard let data = defaults.data(forKey: DefaultsKey.rewardClaimLedger),
              let decoded = try? JSONDecoder().decode([String: RewardClaimState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistRewardClaimLedger(_ ledger: [String: RewardClaimState]) {
        let keys = ledger.keys.sorted()
        let keysToKeep = Set(keys.suffix(20))
        let trimmed = ledger.filter { keysToKeep.contains($0.key) }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: DefaultsKey.rewardClaimLedger)
    }

    private func ensureRewardPending(weekKey: String, now: Date) {
        let current = rewardClaimLedger()[weekKey]
        guard current == nil else { return }
        updateRewardClaimState(
            weekKey: weekKey,
            status: .pending,
            reason: nil,
            now: now
        )
    }

    private func updateRewardClaimState(
        weekKey: String,
        status: SeasonRewardClaimStatus,
        reason: String?,
        now: Date
    ) {
        var ledger = rewardClaimLedger()
        ledger[weekKey] = RewardClaimState(
            weekKey: weekKey,
            status: status,
            reason: reason,
            updatedAt: now.timeIntervalSince1970
        )
        persistRewardClaimLedger(ledger)
    }
}
