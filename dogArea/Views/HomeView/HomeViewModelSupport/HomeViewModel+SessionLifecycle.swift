import Foundation
import Combine

private enum HomeQuestReminderConstants {
    static let hour = 20
    static let minute = 0
}

private enum HomeCatchupStatusFormatter {
    static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

private enum HomeRefreshTrigger: String {
    case initialLoad
    case visibleReentry
    case manualRefresh
    case appResume
    case petSelection
    case timeBoundaryChange

    var reloadPersistedWalkData: Bool {
        switch self {
        case .initialLoad, .visibleReentry, .manualRefresh, .appResume:
            return true
        case .petSelection, .timeBoundaryChange:
            return false
        }
    }

    var refreshAreaReferences: Bool {
        switch self {
        case .initialLoad, .visibleReentry, .manualRefresh, .appResume:
            return true
        case .petSelection, .timeBoundaryChange:
            return false
        }
    }

    var refreshGuestUpgradeReport: Bool {
        switch self {
        case .initialLoad, .visibleReentry, .manualRefresh, .appResume:
            return true
        case .petSelection, .timeBoundaryChange:
            return false
        }
    }

    var shouldUpdateMeter: Bool {
        switch self {
        case .initialLoad, .visibleReentry, .manualRefresh, .appResume:
            return true
        case .petSelection, .timeBoundaryChange:
            return false
        }
    }

    var shouldReloadAreaList: Bool {
        switch self {
        case .initialLoad, .visibleReentry, .manualRefresh, .appResume:
            return true
        case .petSelection, .timeBoundaryChange:
            return false
        }
    }
}

extension HomeViewModel {
    func localizedCopy(ko: String, en: String) -> String {
        let languageCode = Locale.preferredLanguages.first?.lowercased() ?? "ko"
        return languageCode.hasPrefix("en") ? en : ko
    }

    /// 홈 화면 최초 구성 시 필요한 저장 상태와 파생 UI를 중복 없이 적재합니다.
    /// - Parameter now: 초기 집계와 시간 경계 계산에 사용할 기준 시각입니다.
    func performInitialRefresh(now: Date = Date()) {
        executeRefresh(trigger: .initialLoad, now: now)
    }

    /// 사용자가 명시적으로 새로고침했을 때 홈 데이터를 다시 집계합니다.
    /// - Parameter now: 새로고침 기준 시각입니다.
    func fetchData(now: Date = Date()) {
        executeRefresh(trigger: .manualRefresh, now: now)
    }

    /// 홈 탭이 다시 화면에 나타났을 때 필요한 새로고침을 수행합니다.
    /// - Parameter now: 재진입 시각 기준입니다.
    func refreshForVisibleReentry(now: Date = Date()) {
        executeRefresh(trigger: .visibleReentry, now: now)
    }

    /// 포그라운드 복귀 시 홈이 보이는 상태라면 1회성 초기 active 이벤트를 제외하고 데이터를 다시 집계합니다.
    /// - Parameter now: 앱 복귀 기준 시각입니다.
    func refreshForAppResumeIfNeeded(now: Date = Date()) {
        if hasSkippedInitialActiveSceneRefresh == false {
            hasSkippedInitialActiveSceneRefresh = true
            return
        }
        executeRefresh(trigger: .appResume, now: now)
    }

    /// 반려견 선택이 바뀌었을 때 선택 컨텍스트에 영향을 받는 홈 상태만 다시 계산합니다.
    /// - Parameter now: pet 전환 기준 시각입니다.
    func refreshForSelectedPetChange(now: Date = Date()) {
        executeRefresh(trigger: .petSelection, now: now)
    }

    /// 홈 refresh trigger별로 저장소 재조회와 파생 상태 계산 순서를 조정합니다.
    /// - Parameters:
    ///   - trigger: 이번 새로고침을 유발한 홈 이벤트 종류입니다.
    ///   - now: 집계/미션/시즌 계산에 공통으로 사용할 기준 시각입니다.
    private func executeRefresh(trigger: HomeRefreshTrigger, now: Date = Date()) {
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus(now: now)

        if trigger.reloadPersistedWalkData {
            allPolygons = walkRepository.fetchPolygons()
        }

        applySelectedPetStatistics(
            shouldUpdateMeter: trigger.shouldUpdateMeter,
            refreshDerivedContent: false,
            reference: now
        )

        if trigger.shouldReloadAreaList {
            myAreaList = walkRepository.fetchAreas()
        }
        if trigger.refreshAreaReferences {
            refreshAreaReferenceCatalogs()
        }
        if trigger.refreshGuestUpgradeReport {
            refreshGuestDataUpgradeReport()
        }

        refreshIndoorMissions(now: now)
    }

    /// 공용 날씨 스냅샷 저장소에서 최신 값을 읽어 홈 상태에 반영합니다.
    /// - Parameter now: 관측 시각의 신선도와 보정 여부를 계산할 기준 시각입니다.
    func refreshWeatherSnapshot(now: Date = Date()) {
        latestWeatherSnapshot = weatherSnapshotStore.loadSnapshot()
        updateWeatherDetailPresentation(now: now)
    }

    /// 최신 날씨 스냅샷과 오늘 미션 상태를 조합해 상세 카드 프레젠테이션을 갱신합니다.
    /// - Parameter now: 상세 카드의 관측 시각/보정 상태를 계산할 기준 시각입니다.
    func updateWeatherDetailPresentation(now: Date = Date()) {
        weatherDetailPresentation = weatherSnapshotPresentationService.makePresentation(
            snapshot: latestWeatherSnapshot,
            missionSummary: weatherMissionStatusSummary,
            now: now,
            localizedCopy: localizedCopy(ko:en:)
        )
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
                self.areaReferenceSource = snapshot.source
                self.areaReferenceSourceLabel = snapshot.source == .remote ? "운영 비교 구역" : "기본 비교 구역"
                self.areaReferenceLastUpdatedAt = Date()
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
        refreshForSelectedPetChange()
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

    func bindSeasonCatchupBuffStatusNotifications() {
        eventCenter.publisher(for: UserdefaultSetting.seasonCatchupBuffDidUpdateNotification, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSeasonCatchupBuffStatus()
            }
            .store(in: &cancellables)
    }

    func bindSelectedPetSync() {
        eventCenter.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let source = notification.userInfo?["source"] as? String
                guard source != "home" else { return }
                self.isShowingAllRecordsOverride = false
                self.refreshForSelectedPetChange()
            }
            .store(in: &cancellables)
    }

    func bindQuestProgressNotifications() {
        eventCenter.publisher(for: .walkPointRecordedForQuest, object: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIndoorMissions()
            }
            .store(in: &cancellables)
    }

    func bindTimeBoundaryNotifications() {
        let timezoneChanged = eventCenter.publisher(for: .NSSystemTimeZoneDidChange, object: nil)
        let dayChanged = eventCenter.publisher(for: .NSCalendarDayChanged, object: nil)

        Publishers.Merge(timezoneChanged, dayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleTimeBoundaryChange(notification.name)
            }
            .store(in: &cancellables)
    }

    func handleTimeBoundaryChange(_ name: Notification.Name) {
        let newTimeZoneIdentifier = TimeZone.current.identifier
        let didTimeZoneChange = newTimeZoneIdentifier != aggregationTimeZoneIdentifier

        aggregationTimeZoneIdentifier = newTimeZoneIdentifier
        executeRefresh(trigger: .timeBoundaryChange, now: Date())

        guard didTimeZoneChange || name == .NSSystemTimeZoneDidChange else { return }
        aggregationStatusMessage = "타임존이 변경되어 통계를 현재 시간대 기준으로 다시 계산했어요."
    }

    func reloadSeasonCatchupBuffStatus(now: Date = Date()) {
        guard let snapshot = userSessionStore.seasonCatchupBuffSnapshot() else {
            seasonCatchupBuffStatusMessage = nil
            seasonCatchupBuffStatusWarning = false
            return
        }

        let nowTs = now.timeIntervalSince1970
        let expiresAt = snapshot.expiresAt

        if snapshot.isActive, let expiresAt, expiresAt > nowTs {
            let expiryText = HomeCatchupStatusFormatter.expiryFormatter.string(from: Date(timeIntervalSince1970: expiresAt))
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

    func catchupBlockReasonText(_ reason: String?) -> String {
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
    func syncQuestReminderOnLaunch() async {
        await applyQuestReminderPreference(
            enabled: questReminderEnabled,
            allowAuthorizationPrompt: false
        )
    }

    /// 퀘스트 리마인드 설정 변경을 로컬 알림 스케줄에 적용하고 상태 메시지를 갱신합니다.
    func applyQuestReminderPreference(
        enabled: Bool,
        allowAuthorizationPrompt: Bool
    ) async {
        let result = await questReminderScheduler.applyDailyReminder(
            enabled: enabled,
            allowAuthorizationPrompt: allowAuthorizationPrompt,
            hour: HomeQuestReminderConstants.hour,
            minute: HomeQuestReminderConstants.minute
        )

        await MainActor.run {
            switch result {
            case .enabled:
                if allowAuthorizationPrompt {
                    indoorMissionStatusMessage = "퀘스트 리마인드를 매일 \(HomeQuestReminderConstants.hour):\(String(format: "%02d", HomeQuestReminderConstants.minute)) 1회로 설정했어요."
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

    func refreshGuestDataUpgradeReport() {
        guard let userId = userInfo?.id, userId.isEmpty == false else {
            guestDataUpgradeReport = nil
            return
        }
        guestDataUpgradeReport = GuestDataUpgradeService.shared.latestReport(for: userId)
    }
}
