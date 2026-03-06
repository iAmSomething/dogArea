//
//  HomeViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

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
    @Published var areaMilestonePresentation: AreaMilestoneEvent? = nil

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
    private let weeklyStatisticsService: HomeWeeklyStatisticsServicing
    private let weatherMissionStatusBuilder: HomeWeatherMissionStatusBuilding
    private let areaMilestoneDetector: AreaMilestoneDetecting
    private let areaMilestoneNotificationScheduler: AreaMilestoneNotificationScheduling
    private let seasonMotionStore = SeasonMotionStore()
    private let questReminderScheduler: QuestReminderScheduling
    private let questReminderPreferenceStore = QuestReminderPreferenceStore()
    private var featuredGoalAreas: [AreaMeter] = []
    private var areaMilestoneQueue: [AreaMilestoneEvent] = []
    private var areaReferenceTask: Task<Void, Never>? = nil
    private static let questReminderHour = 20
    private static let questReminderMinute = 0
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

    private func localizedCopy(ko: String, en: String) -> String {
        let languageCode = Locale.preferredLanguages.first?.lowercased() ?? "ko"
        return languageCode.hasPrefix("en") ? en : ko
    }

    init(
        areaReferenceRepository: AreaReferenceRepository = SupabaseAreaReferenceRepository.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        eventCenter: AppEventCenterProtocol = DefaultAppEventCenter.shared,
        weeklyStatisticsService: HomeWeeklyStatisticsServicing = HomeWeeklyStatisticsService(),
        weatherMissionStatusBuilder: HomeWeatherMissionStatusBuilding = HomeWeatherMissionStatusBuilder(),
        areaMilestoneDetector: AreaMilestoneDetecting = AreaMilestoneDetector(),
        areaMilestoneNotificationScheduler: AreaMilestoneNotificationScheduling = LocalAreaMilestoneNotificationScheduler()
    ) {
        self.areaReferenceRepository = areaReferenceRepository
        self.walkRepository = walkRepository
        self.userSessionStore = userSessionStore
        self.eventCenter = eventCenter
        self.weeklyStatisticsService = weeklyStatisticsService
        self.weatherMissionStatusBuilder = weatherMissionStatusBuilder
        self.areaMilestoneDetector = areaMilestoneDetector
        self.areaMilestoneNotificationScheduler = areaMilestoneNotificationScheduler
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
                self.evaluateAreaMilestones()
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

    /// 현재 표시 중인 영역 마일스톤 배지 팝업을 해제하고 다음 큐를 표시합니다.
    func clearAreaMilestonePresentation() {
        areaMilestonePresentation = nil
        presentNextAreaMilestoneIfNeeded()
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
        evaluateAreaMilestones()
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

    /// 현재 누적 영역을 기준으로 새로 달성한 영역 마일스톤을 감지하고 UI/알림 큐에 반영합니다.
    /// - Parameter now: 마일스톤 달성 시각 계산 기준입니다.
    private func evaluateAreaMilestones(now: Date = Date()) {
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
    private func milestoneCandidates() -> [AreaMilestoneCandidate] {
        let sourceAreas: [AreaMeter]
        if featuredGoalAreas.isEmpty {
            sourceAreas = Array(krAreas.areas.suffix(10))
        } else {
            sourceAreas = featuredGoalAreas
        }
        return sourceAreas.map { area in
            AreaMilestoneCandidate(
                landmarkName: area.areaName,
                thresholdArea: area.area
            )
        }
    }

    /// 새 마일스톤 이벤트를 큐에 누적하고 즉시 표시 가능한 경우 팝업을 노출합니다.
    /// - Parameter events: 이번 계산에서 새로 달성한 마일스톤 이벤트 목록입니다.
    private func enqueueAreaMilestones(_ events: [AreaMilestoneEvent]) {
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
    private func presentNextAreaMilestoneIfNeeded() {
        guard areaMilestonePresentation == nil else { return }
        guard areaMilestoneQueue.isEmpty == false else { return }
        areaMilestonePresentation = areaMilestoneQueue.removeFirst()
    }

    /// 앱 포그라운드 활성 상태 여부를 반환합니다.
    /// - Returns: 포그라운드 활성 상태면 `true`, 아니면 `false`입니다.
    private func isApplicationActive() -> Bool {
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

    func refreshIndoorMissions(now: Date = Date()) {
        let missionContext = makeIndoorMissionPetContext(reference: now)
        indoorMissionBoard = indoorMissionStore.buildBoard(now: now, context: missionContext)
        questAlternativeActionSuggestion = makeQuestAlternativeActionSuggestion(for: indoorMissionBoard)
        weatherFeedbackRemainingCount = indoorMissionStore.weatherFeedbackRemainingCount(now: now)
        let weatherStatus = indoorMissionStore.weatherStatus(now: now)
        let shieldDailySummary = indoorMissionStore.weatherShieldDailySummary(now: now)
        weatherShieldDailySummary = shieldDailySummary
        weatherMissionStatusSummary = weatherMissionStatusBuilder.makeStatusSummary(
            board: indoorMissionBoard,
            status: weatherStatus,
            now: now,
            shieldApplyCount: shieldDailySummary?.applyCount ?? 0,
            localizedCopy: localizedCopy(ko:en:)
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

    private func currentCalendar() -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }

    private func currentWeekInterval(reference: Date) -> DateInterval {
        let calendar = currentCalendar()
        return weeklyStatisticsService.currentWeekInterval(reference: reference, calendar: calendar)
    }

    private func sessionInterval(for polygon: Polygon) -> DateInterval {
        weeklyStatisticsService.sessionInterval(for: polygon)
    }

    private func weightedAreaContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        weeklyStatisticsService.weightedAreaContribution(for: polygon, in: bucket)
    }

    private func weightedDurationContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        weeklyStatisticsService.weightedDurationContribution(for: polygon, in: bucket)
    }

    private func sessionOverlaps(_ polygon: Polygon, with bucket: DateInterval) -> Bool {
        weeklyStatisticsService.sessionOverlaps(polygon, with: bucket)
    }

    private func dayStartsCovered(by polygon: Polygon, calendar: Calendar) -> [Date] {
        weeklyStatisticsService.dayStartsCovered(by: polygon, calendar: calendar)
    }

    private func makeDayBoundarySplitContribution(reference: Date) -> DayBoundarySplitContribution? {
        let calendar = currentCalendar()
        return weeklyStatisticsService.makeDayBoundarySplitContribution(
            from: polygonList,
            reference: reference,
            calendar: calendar
        )
    }
}
