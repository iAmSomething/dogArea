//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @StateObject var viewModel = HomeViewModel()
    @State private var animatedQuestProgress: [String: Double] = [:]
    @State private var questProgressPulseMissionId: String? = nil
    @State private var questClaimPulseMissionId: String? = nil
    @State private var questCompletionModal: QuestCompletionPresentation? = nil
    @State private var questCompletionPop: Bool = false
    @State private var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var seasonAnimatedProgress: Double = 0
    @State private var seasonGaugeWaveOffset: CGFloat = -120
    @State private var seasonShieldRotation: Double = 0
    @State private var seasonResultModal: SeasonResultPresentation? = nil
    @State private var seasonResultPop: Bool = false
    @State private var seasonResultRevealRank: Bool = false
    @State private var seasonResultRevealContribution: Bool = false
    @State private var seasonResultRevealShield: Bool = false
    @State private var seasonResetBannerVisible: Bool = false
    @State private var areaMilestonePop: Bool = false
    @State private var questWidgetTab: HomeQuestWidgetTab = .daily
    @State private var homeScrollOffsetY: CGFloat = 0
    @State private var isSeasonDetailPresented: Bool = false
    @State private var isTerritoryGoalPresented: Bool = false
    @State private var hasAppearedOnce: Bool = false
    @State private var isHomeVisible: Bool = false

    private var isQuestMotionReduced: Bool {
        accessibilityReduceMotion
    }
    private var isSeasonMotionReduced: Bool {
        accessibilityReduceMotion || isLowPowerModeEnabled
    }

    /// 홈 상단 인사말에 노출할 사용자 이름을 계산합니다.
    private var displayUserName: String {
        let fallback = viewModel.selectedPetName
        return viewModel.userInfo?.name.nilIfBlank ?? fallback
    }

    /// 시즌 점수 기반 레벨 배지를 계산합니다.
    private var levelBadgeText: String {
        let level = max(1, Int(viewModel.seasonMotionSummary.score / 100) + 1)
        return "Lv. \(level)"
    }

    /// 홈 스크롤 최상단 복귀 버튼 노출 여부를 계산합니다.
    private var shouldShowScrollToTopButton: Bool {
        homeScrollOffsetY < -220
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottomTrailing) {
                Color.appTabScaffoldBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: 0)
                            .id("home.scroll.top")
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HomeScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("home.scroll")).minY
                            )
                        }
                        .frame(height: 0)

                        homeHeaderSection
                        if let report = viewModel.guestDataUpgradeReport {
                            guestDataUpgradeCard(report: report)
                        }
                        if let message = viewModel.aggregationStatusMessage {
                            HomeStatusBannerView(message: message, isWarning: false)
                        }
                        if let message = viewModel.indoorMissionStatusMessage {
                            HomeStatusBannerView(message: message, isWarning: false)
                        }
                        if let message = viewModel.seasonCatchupBuffStatusMessage {
                            HomeStatusBannerView(
                                message: message,
                                isWarning: viewModel.seasonCatchupBuffStatusWarning
                            )
                        }
                        if viewModel.pets.count > 1 {
                            homePetSelector
                        }
                        if viewModel.pets.isEmpty == false {
                            if viewModel.isShowingAllRecordsOverride {
                                selectedPetContextBanner
                            }
                            if viewModel.shouldShowSelectedPetEmptyState {
                                selectedPetContextBanner
                                selectedPetEmptyStateCard
                            }
                        }
                        homeWeeklySnapshotSection
                        seasonMotionCard(summary: viewModel.seasonMotionSummary)
                        weatherDetailCard(presentation: viewModel.weatherDetailPresentation)
                        if viewModel.indoorMissionBoard.shouldDisplayCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("오늘 미션 안내")
                                    .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .title2))
                                Text("완료 기준, 부족분, 완료된 미션을 한 번에 확인하세요.")
                                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            weatherMissionStatusCard(summary: viewModel.weatherMissionStatusSummary)
                            if let shieldSummary = viewModel.weatherShieldDailySummary {
                                weatherShieldSummaryCard(summary: shieldSummary)
                            }
                            indoorMissionCard(board: viewModel.indoorMissionBoard)
                        }
                        territoryHeaderSection
                        goalTrackerCard
                        recentConqueredCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .coordinateSpace(name: "home.scroll")
                .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                    homeScrollOffsetY = value
                }
                .refreshable {
                    viewModel.fetchData()
                }
                .onAppear{
                    isHomeVisible = true
                    if hasAppearedOnce {
                        viewModel.refreshForVisibleReentry()
                    } else {
                        hasAppearedOnce = true
                    }
                    seasonAnimatedProgress = viewModel.seasonMotionSummary.progress
                    if viewModel.seasonMotionSummary.weatherShieldActive {
                        startSeasonShieldRingAnimationIfNeeded()
                    }
                }
                .onDisappear {
                    isHomeVisible = false
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, isHomeVisible else { return }
                    viewModel.refreshForAppResumeIfNeeded()
                }
                .onChange(of: viewModel.aggregationStatusMessage) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    viewModel.clearAggregationStatusMessage()
                }
                }.onChange(of: viewModel.indoorMissionStatusMessage) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    viewModel.clearIndoorMissionStatusMessage()
                }
                }.onChange(of: viewModel.weatherFeedbackResultMessage) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    viewModel.clearWeatherFeedbackResultMessage()
                }
                }.onChange(of: viewModel.questMotionEvent) { _, event in
                handleQuestMotionEvent(event)
                }.onChange(of: viewModel.questCompletionPresentation) { _, payload in
                guard let payload else { return }
                presentQuestCompletionModal(payload)
                }.onChange(of: viewModel.seasonMotionSummary.progress) { _, progress in
                animateSeasonProgress(to: progress)
                }.onChange(of: viewModel.seasonMotionSummary.weatherShieldActive) { _, active in
                if active {
                    startSeasonShieldRingAnimationIfNeeded()
                } else {
                    seasonShieldRotation = 0
                }
                }.onChange(of: viewModel.seasonMotionEvent) { _, event in
                handleSeasonMotionEvent(event)
                }.onChange(of: viewModel.seasonResultPresentation) { _, payload in
                guard let payload else { return }
                presentSeasonResultModal(payload)
                }.onChange(of: viewModel.seasonResetTransitionToken) { _, token in
                guard token != nil else { return }
                presentSeasonResetTransitionBanner()
                }.onChange(of: viewModel.areaMilestonePresentation) { _, event in
                guard event != nil else { return }
                presentAreaMilestoneOverlay()
                }.onChange(of: authFlow.guestDataUpgradeResult?.executedAt) { _, _ in
                viewModel.refreshGuestDataUpgradeReport()
                }.onChange(of: isLowPowerModeEnabled) { _, enabled in
                if enabled {
                    seasonShieldRotation = 0
                } else if viewModel.seasonMotionSummary.weatherShieldActive {
                    startSeasonShieldRingAnimationIfNeeded()
                }
                }.onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }.sheet(isPresented: $isSeasonDetailPresented) {
                HomeSeasonDetailSheetView(
                    summary: viewModel.seasonMotionSummary,
                    remainingTimeText: viewModel.seasonRemainingTimeText,
                    onClose: { isSeasonDetailPresented = false }
                )
                }
                .appTabRootScrollLayout(extraBottomPadding: 12)

                scrollToTopFloatingButton(proxy: scrollProxy)

                if let questCompletionModal {
                    HomeQuestCompletionOverlayView(
                        payload: questCompletionModal,
                        isVisible: questCompletionPop
                    )
                        .zIndex(10)
                }
                if let seasonResultModal {
                    HomeSeasonResultOverlayView(
                        payload: seasonResultModal,
                        rewardStatus: viewModel.seasonRewardStatus(for: seasonResultModal.weekKey),
                        revealRank: seasonResultRevealRank,
                        revealContribution: seasonResultRevealContribution,
                        revealShield: seasonResultRevealShield,
                        isVisible: seasonResultPop,
                        onDismiss: dismissSeasonResultModal,
                        onRetryClaim: {
                            viewModel.retrySeasonRewardClaim(
                                for: seasonResultModal.weekKey,
                                cloudSyncAllowed: authFlow.canAccess(.cloudSync)
                            )
                        }
                    )
                        .zIndex(11)
                }
                if let milestoneEvent = viewModel.areaMilestonePresentation {
                    HomeAreaMilestoneBadgeOverlayView(
                        event: milestoneEvent,
                        isVisible: areaMilestonePop
                    )
                    .zIndex(12)
                }
                if seasonResetBannerVisible {
                    HomeSeasonResetTransitionBannerView()
                        .zIndex(9)
                }

            }
            .navigationDestination(isPresented: $isTerritoryGoalPresented) {
                TerritoryGoalView(viewModel: TerritoryGoalViewModel(homeViewModel: viewModel))
            }
        }
    }

    /// 홈 대시보드 상단 인사말과 레벨 배지를 렌더링합니다.
    private var homeHeaderSection: some View {
        HomeHeaderSectionView(
            displayUserName: displayUserName,
            levelBadgeText: levelBadgeText,
            selectedPetName: viewModel.selectedPetName
        )
    }

    /// 홈에서 선택 반려견을 빠르게 전환하는 칩 목록입니다.
    private var homePetSelector: some View {
        HomePetSelectorView(
            pets: viewModel.pets,
            selectedPetId: viewModel.selectedPetId,
            onSelectPet: viewModel.selectPet
        )
    }

    /// 이번 주 산책 영역/횟수 요약 카드를 렌더링합니다.
    private var homeWeeklySnapshotSection: some View {
        HomeWeeklySnapshotSectionView(
            areaText: viewModel.walkedAreaforWeek().calculatedAreaString,
            areaAccentText: "↗︎ \(Int(viewModel.goalProgressRatio * 100))% 달성",
            walkCountText: "\(viewModel.walkedCountforWeek())회",
            walkCountAccentText: "목표 달성까지 3회"
        )
    }

    /// 영역 섹션 타이틀을 렌더링합니다.
    private var territoryHeaderSection: some View {
        HomeTerritoryHeaderSectionView(selectedPetNameWithYi: viewModel.selectedPetNameWithYi)
    }

    /// 홈 스크롤이 내려갔을 때 상단 복귀 플로팅 버튼을 렌더링합니다.
    /// - Parameter proxy: 홈 스크롤 앵커 이동을 담당하는 스크롤 프록시입니다.
    /// - Returns: 조건부 노출되는 상단 복귀 버튼 뷰입니다.
    @ViewBuilder
    private func scrollToTopFloatingButton(proxy: ScrollViewProxy) -> some View {
        if shouldShowScrollToTopButton {
            HomeScrollToTopFloatingButtonView {
                withAnimation(.easeInOut(duration: 0.24)) {
                    proxy.scrollTo("home.scroll.top", anchor: .top)
                }
            }
            .padding(.trailing, 20)
            .appTabFloatingOverlayPadding(lift: 20)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func guestDataUpgradeCard(report: GuestDataUpgradeReport) -> some View {
        let validationText: String? = {
            guard let passed = report.validationPassed else { return nil }
            return passed ? "원격 검증 통과" : "원격 검증 실패: \(report.validationMessage ?? "mismatch")"
        }()
        let lastErrorMessage: String? = {
            guard report.hasOutstandingWork,
                  let rawError = report.lastErrorCode,
                  rawError.isEmpty == false else { return nil }
            return guestDataUpgradeErrorMessage(rawValue: rawError)
        }()
        HomeGuestDataUpgradeCardView(
            report: report,
            validationText: validationText,
            lastErrorMessage: lastErrorMessage,
            isRetryInProgress: authFlow.guestDataUpgradeInProgress,
            onRetry: triggerGuestDataUpgradeRetry
        )
    }

    /// 게스트 데이터 이관 리포트의 아웃박스 오류 코드를 사용자 노출 문구로 변환합니다.
    /// - Parameter rawValue: `SyncOutboxErrorCode` raw 문자열입니다.
    /// - Returns: 이관 상태 카드에 표시할 오류 설명입니다.
    private func guestDataUpgradeErrorMessage(rawValue: String) -> String {
        guard let code = SyncOutboxErrorCode(rawValue: rawValue) else {
            return rawValue
        }
        switch code {
        case .notConfigured:
            return "동기화 서버 기능이 아직 준비되지 않았어요(404)."
        case .offline:
            return "네트워크 오프라인 상태예요."
        case .tokenExpired, .unauthorized:
            return "인증 세션이 만료됐어요. 다시 로그인해주세요."
        case .serverError:
            return "서버가 일시적으로 불안정해요."
        case .schemaMismatch:
            return "앱/서버 스키마 버전 확인이 필요해요."
        case .storageQuota:
            return "서버 저장소 한도를 초과했어요."
        case .conflict:
            return "동기화 데이터 충돌이 발생했어요."
        case .unknown:
            return "알 수 없는 동기화 오류가 발생했어요."
        }
    }

    /// 홈 게스트 데이터 이관 카드의 재시도 CTA를 실행합니다.
    /// 재시도를 시작한 직후 최신 리포트를 다시 읽어 카드 상태를 갱신합니다.
    private func triggerGuestDataUpgradeRetry() {
        #if DEBUG
        print("[Home] guest upgrade retry tapped")
        #endif
        authFlow.startGuestDataUpgrade(forceRetry: true)
        viewModel.refreshGuestDataUpgradeReport()
    }

    private var goalTrackerCard: some View {
        // area_reference_db_ui_unit_check 호환: HomeGoalTrackerCardView가 "비교군 소스:" 라벨을 렌더링합니다.
        HomeGoalTrackerCardView(
            areaReferenceSourceLabel: viewModel.areaReferenceSourceLabel,
            featuredAreaCount: viewModel.featuredAreaCount,
            currentAreaText: viewModel.myArea.area.calculatedAreaString,
            currentAreaName: viewModel.myArea.areaName,
            nextGoalNameText: viewModel.nextGoalArea?.areaName ?? "목표 없음",
            nextGoalAreaText: viewModel.nextGoalArea?.area.calculatedAreaString ?? "완료",
            remainingAreaText: viewModel.remainingAreaToGoal.calculatedAreaString,
            progressRatio: viewModel.goalProgressRatio,
            onOpenDetail: { isTerritoryGoalPresented = true }
        )
    }

    private var selectedPetContextBanner: some View {
        HomeSelectedPetContextBannerView(
            isShowingAllRecordsOverride: viewModel.isShowingAllRecordsOverride,
            selectedPetName: viewModel.selectedPetName,
            onRevertToSelectedPet: viewModel.showSelectedPetRecords
        )
    }

    private var selectedPetEmptyStateCard: some View {
        // selected_pet_context_ui_check 호환: CTA 문구 "전체 기록 보기"는 HomeSelectedPetEmptyStateCardView에서 렌더링됩니다.
        HomeSelectedPetEmptyStateCardView(
            selectedPetName: viewModel.selectedPetName,
            onShowAllRecords: viewModel.showAllRecordsTemporarily
        )
    }

    private var recentConqueredCard: some View {
        let recentAreas = Array(viewModel.myAreaList.sorted { $0.createdAt > $1.createdAt }.prefix(3))
        return HomeRecentConqueredSectionView(items: recentAreas)
    }

    private func dayBoundarySplitCard(contribution: DayBoundarySplitContribution) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("전날/오늘 분할 기여")
                .font(.appFont(for: .SemiBold, size: 17))
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contribution.previousDayLabel)
                        .font(.appFont(for: .SemiBold, size: 13))
                    Text("면적 \(contribution.previousArea.calculatedAreaString)")
                        .font(.appFont(for: .Light, size: 12))
                    Text("시간 \(contribution.previousDuration.simpleWalkingTimeInterval)")
                        .font(.appFont(for: .Light, size: 12))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(contribution.currentDayLabel)
                        .font(.appFont(for: .SemiBold, size: 13))
                    Text("면적 \(contribution.currentArea.calculatedAreaString)")
                        .font(.appFont(for: .Light, size: 12))
                    Text("시간 \(contribution.currentDuration.simpleWalkingTimeInterval)")
                        .font(.appFont(for: .Light, size: 12))
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextLightGray, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }

    private func weatherMissionStatusCard(summary: WeatherMissionStatusSummary) -> some View {
        HomeWeatherMissionStatusCardView(summary: summary)
    }

    /// 홈에서 원시 날씨 수치와 관측 상태를 요약하는 상세 카드를 렌더링합니다.
    /// - Parameter presentation: 홈 카드가 직접 사용할 날씨 상세 프레젠테이션 상태입니다.
    /// - Returns: 기온/체감/습도/강수/공기질을 보여주는 상세 카드 뷰입니다.
    private func weatherDetailCard(presentation: HomeWeatherSnapshotCardPresentation) -> some View {
        HomeWeatherSnapshotCardView(presentation: presentation)
    }

    private func weatherShieldSummaryCard(summary: WeatherShieldDailySummary) -> some View {
        HomeWeatherShieldSummaryCardView(summary: summary)
    }

    private func indoorMissionCard(board: IndoorMissionBoard) -> some View {
        let presentation = viewModel.indoorMissionPresentation
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(questWidgetTab == .daily ? presentation.sectionTitle : "주간 퀘스트 요약")
                    .font(.appFont(for: .SemiBold, size: 18))
                Spacer()
                if board.riskLevel != .clear && questWidgetTab == .daily {
                    Text(board.riskLevel.displayTitle)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appYellow)
                        .cornerRadius(8)
                }
            }
            questWidgetTabSelector
            questReminderToggleRow

            if questWidgetTab == .daily {
                Text(presentation.sectionSubtitle)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(viewModel.weatherMissionStatusSummary.appliedAtText)
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                    Spacer()
                    Text(viewModel.weatherMissionStatusSummary.shieldUsageText)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                }
                if board.riskLevel != .clear {
                    HStack(spacing: 8) {
                        Button("체감 날씨 다름") {
                            viewModel.submitWeatherMismatchFeedback()
                        }
                        .disabled(viewModel.canSubmitWeatherMismatchFeedback == false)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(viewModel.canSubmitWeatherMismatchFeedback ? Color.appYellow : Color.appTextLightGray)
                        .cornerRadius(8)

                        Text("주간 남은 반영 \(viewModel.weatherFeedbackRemainingCount)/\(viewModel.weatherFeedbackWeeklyLimit)")
                            .font(.appFont(for: .Light, size: 11))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                }
                if presentation.rationaleItems.isEmpty == false {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("진행 가이드")
                            .font(.appFont(for: .SemiBold, size: 12))
                        ForEach(Array(presentation.rationaleItems.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(Color.appInk)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(item)
                                    .font(.appFont(for: .Light, size: 11))
                                    .foregroundStyle(Color.appTextDarkGray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityIdentifier("home.quest.rationale.\(index)")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.appYellowPale.opacity(0.35))
                    .cornerRadius(10)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.quest.rationale.card")
                }
                if let difficulty = board.difficultySummary {
                    missionDifficultySummary(difficulty)
                }
                if let extensionMessage = board.extensionMessage {
                    Text(extensionMessage)
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            board.extensionState == .active || board.extensionState == .consumed
                            ? Color.appYellowPale
                            : Color.appTextLightGray.opacity(0.28)
                        )
                        .cornerRadius(8)
                }
                if let feedbackMessage = viewModel.weatherFeedbackResultMessage {
                    Text(feedbackMessage)
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.appYellowPale)
                        .cornerRadius(8)
                }

                if presentation.activeMissions.isEmpty && presentation.completedMissions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.emptyTitle)
                            .font(.appFont(for: .SemiBold, size: 13))
                        Text(presentation.emptyMessage)
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    .padding(.vertical, 4)
                } else {
                    indoorMissionSection(
                        title: "지금 진행할 미션",
                        accessibilityIdentifier: "home.quest.section.active",
                        rows: presentation.activeMissions
                    )
                    if let completedTitle = presentation.completedSectionTitle {
                        indoorMissionSection(
                            title: completedTitle,
                            accessibilityIdentifier: "home.quest.section.completed",
                            rows: presentation.completedMissions
                        )
                    }
                }
            } else {
                weeklyQuestSummary(board: board)
            }

            if let suggestion = viewModel.questAlternativeActionSuggestion {
                questAlternativeSuggestionCard(suggestion)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appTextLightGray, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quest.card.daily")
    }

    /// 퀘스트 위젯에서 일일/주간 뷰를 전환하는 탭 선택 행입니다.
    private var questWidgetTabSelector: some View {
        HomeQuestWidgetTabSelectorView(selectedTab: questWidgetTab) { tab in
            questWidgetTab = tab
        }
    }

    /// 하루 1회 퀘스트 리마인드 알림 설정 토글 행입니다.
    private var questReminderToggleRow: some View {
        HomeQuestReminderToggleRowView(
            isEnabled: Binding(
                get: { viewModel.questReminderEnabled },
                set: { viewModel.setQuestReminderEnabled($0) }
            )
        )
    }

    /// 주간 퀘스트 진행도와 완료 현황을 요약해서 보여줍니다.
    private func weeklyQuestSummary(board: IndoorMissionBoard) -> some View {
        let summary = viewModel.seasonMotionSummary
        let completedDaily = board.missions.filter { $0.progress.isCompleted }.count
        let totalDaily = board.missions.count

        return HomeWeeklyQuestSummaryView(
            summary: summary,
            completedDailyCount: completedDaily,
            totalDailyCount: totalDaily,
            isSeasonMotionReduced: isSeasonMotionReduced,
            seasonGaugeWaveOffset: seasonGaugeWaveOffset
        )
    }

    /// 퀘스트 실패/만료 시 다음 행동을 안내하는 제안 카드입니다.
    private func questAlternativeSuggestionCard(_ text: String) -> some View {
        HomeQuestAlternativeSuggestionCardView(text: text)
    }

    private func missionDifficultySummary(_ summary: IndoorMissionDifficultySummary) -> some View {
        HomeMissionDifficultySummaryView(
            summary: summary,
            onActivateEasyDayMode: {
                viewModel.activateEasyDayMode()
            }
        )
    }

    private func seasonMotionCard(summary: SeasonMotionSummary) -> some View {
        HomeSeasonMotionCardView(
            summary: summary,
            animatedProgress: seasonAnimatedProgress,
            isMotionReduced: isSeasonMotionReduced,
            gaugeWaveOffset: seasonGaugeWaveOffset,
            shieldRotation: seasonShieldRotation,
            remainingTimeText: viewModel.seasonRemainingTimeText,
            onOpenDetail: {
                isSeasonDetailPresented = true
            }
        )
    }

    private func animatedSeasonGauge(progress: Double) -> some View {
        HomeAnimatedSeasonGaugeView(
            progress: progress,
            isMotionReduced: isSeasonMotionReduced,
            waveOffset: seasonGaugeWaveOffset
        )
    }

    private func questProgressValue(for mission: IndoorMissionCardModel) -> Double {
        animatedQuestProgress[mission.id] ?? mission.progress.progressRatio
    }

    private func handleQuestMotionEvent(_ event: QuestMotionEvent?) {
        guard let event else { return }
        let shouldAnimate = isQuestMotionReduced == false
        switch event.type {
        case .progress:
            if shouldAnimate {
                withAnimation(.easeOut(duration: 0.34)) {
                    animatedQuestProgress[event.missionId] = event.progress
                    questProgressPulseMissionId = event.missionId
                }
            } else {
                animatedQuestProgress[event.missionId] = event.progress
            }
            AppHapticFeedback.questProgress()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                if questProgressPulseMissionId == event.missionId {
                    questProgressPulseMissionId = nil
                }
            }
        case .completed:
            if shouldAnimate {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                    animatedQuestProgress[event.missionId] = 1.0
                    questClaimPulseMissionId = event.missionId
                }
            } else {
                animatedQuestProgress[event.missionId] = 1.0
            }
            AppHapticFeedback.questCompleted()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if questClaimPulseMissionId == event.missionId {
                    questClaimPulseMissionId = nil
                }
            }
        case .failed:
            AppHapticFeedback.questFailed()
        case .alreadyCompleted:
            AppHapticFeedback.questProgress()
        }
    }

    private func animateSeasonProgress(to nextProgress: Double) {
        let clamped = min(1.0, max(0.0, nextProgress))
        if isSeasonMotionReduced {
            seasonAnimatedProgress = clamped
            return
        }

        let delta = abs(clamped - seasonAnimatedProgress)
        let duration = min(1.0, max(0.22, delta * 1.2))
        seasonGaugeWaveOffset = -120
        withAnimation(.easeOut(duration: duration)) {
            seasonAnimatedProgress = clamped
        }
        withAnimation(.easeInOut(duration: duration)) {
            seasonGaugeWaveOffset = 120
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            seasonGaugeWaveOffset = -120
        }
    }

    private func startSeasonShieldRingAnimationIfNeeded() {
        guard isSeasonMotionReduced == false else {
            seasonShieldRotation = 0
            return
        }
        seasonShieldRotation = 0
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
            seasonShieldRotation = 360
        }
    }

    private func handleSeasonMotionEvent(_ event: SeasonMotionEvent?) {
        guard let event else { return }
        switch event.type {
        case .scoreIncreased:
            AppHapticFeedback.seasonScoreTick(reducedMotion: isSeasonMotionReduced)
            if event.shieldApplied {
                AppHapticFeedback.seasonShieldApplied(reducedMotion: isSeasonMotionReduced)
            }
        case .rankUp:
            AppHapticFeedback.seasonRankUp(reducedMotion: isSeasonMotionReduced)
            if event.shieldApplied {
                AppHapticFeedback.seasonShieldApplied(reducedMotion: isSeasonMotionReduced)
            }
        case .shieldApplied:
            AppHapticFeedback.seasonShieldApplied(reducedMotion: isSeasonMotionReduced)
        case .seasonReset:
            AppHapticFeedback.seasonReset(reducedMotion: isSeasonMotionReduced)
        }
    }

    private func presentSeasonResultModal(_ payload: SeasonResultPresentation) {
        if viewModel.seasonRewardStatus(for: payload.weekKey) == .pending {
            viewModel.retrySeasonRewardClaim(
                for: payload.weekKey,
                cloudSyncAllowed: authFlow.canAccess(.cloudSync)
            )
        }
        seasonResultModal = payload
        seasonResultPop = false
        seasonResultRevealRank = false
        seasonResultRevealContribution = false
        seasonResultRevealShield = false

        if isSeasonMotionReduced {
            seasonResultPop = true
            seasonResultRevealRank = true
            seasonResultRevealContribution = true
            seasonResultRevealShield = true
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            seasonResultPop = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.24)) {
                seasonResultRevealRank = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.24)) {
                seasonResultRevealContribution = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            withAnimation(.easeOut(duration: 0.24)) {
                seasonResultRevealShield = true
            }
        }
    }

    private func dismissSeasonResultModal() {
        if isSeasonMotionReduced {
            seasonResultModal = nil
            viewModel.clearSeasonResultPresentation()
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            seasonResultPop = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            seasonResultModal = nil
            viewModel.clearSeasonResultPresentation()
        }
    }

    private func presentSeasonResetTransitionBanner() {
        if isSeasonMotionReduced {
            seasonResetBannerVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                seasonResetBannerVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if isSeasonMotionReduced {
                seasonResetBannerVisible = false
            } else {
                withAnimation(.easeIn(duration: 0.2)) {
                    seasonResetBannerVisible = false
                }
            }
            viewModel.clearSeasonResetTransitionToken()
        }
    }

    /// 영역 마일스톤 배지 오버레이를 표시하고 자동 종료 타이머를 시작합니다.
    private func presentAreaMilestoneOverlay() {
        AppHapticFeedback.questCompleted()
        areaMilestonePop = false
        if isQuestMotionReduced {
            areaMilestonePop = true
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                areaMilestonePop = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            dismissAreaMilestoneOverlay()
        }
    }

    /// 영역 마일스톤 배지 오버레이를 닫고 ViewModel 큐의 다음 이벤트를 진행합니다.
    private func dismissAreaMilestoneOverlay() {
        if isQuestMotionReduced {
            areaMilestonePop = false
            viewModel.clearAreaMilestonePresentation()
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            areaMilestonePop = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.clearAreaMilestonePresentation()
        }
    }

    private func presentQuestCompletionModal(_ payload: QuestCompletionPresentation) {
        questCompletionModal = payload
        questCompletionPop = false
        if isQuestMotionReduced {
            questCompletionPop = true
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                questCompletionPop = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            if isQuestMotionReduced {
                questCompletionModal = nil
                viewModel.clearQuestCompletionPresentation()
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                questCompletionPop = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                questCompletionModal = nil
                viewModel.clearQuestCompletionPresentation()
            }
        }
    }

    /// 홈 미션 카드를 활성/완료 섹션 단위로 렌더링합니다.
    /// - Parameters:
    ///   - title: 섹션 제목입니다.
    ///   - accessibilityIdentifier: UI 테스트와 접근성 탐색에 사용할 식별자입니다.
    ///   - rows: 섹션에 포함될 미션 행 프레젠테이션 목록입니다.
    /// - Returns: 홈 미션 카드 내부에 표시할 섹션 뷰입니다.
    private func indoorMissionSection(
        title: String,
        accessibilityIdentifier: String,
        rows: [HomeIndoorMissionRowPresentation]
    ) -> some View {
        guard rows.isEmpty == false else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.appFont(for: .SemiBold, size: 13))
                    .foregroundStyle(Color.appTextDarkGray)
                ForEach(rows) { row in
                    indoorMissionRow(presentation: row)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(accessibilityIdentifier)
        )
    }

    /// 개별 실내 미션 프레젠테이션을 홈 카드 행으로 렌더링합니다.
    /// - Parameter presentation: 렌더링할 미션 행 프레젠테이션 정보입니다.
    /// - Returns: 홈 카드 내부의 개별 미션 행 뷰입니다.
    private func indoorMissionRow(presentation: HomeIndoorMissionRowPresentation) -> some View {
        let mission = presentation.mission
        return HomeIndoorMissionRowView(
            presentation: presentation,
            animatedProgress: questProgressValue(for: mission),
            isQuestMotionReduced: isQuestMotionReduced,
            showClaimPulse: questClaimPulseMissionId == mission.id,
            showProgressPulse: questProgressPulseMissionId == mission.id,
            onRecordAction: { viewModel.recordIndoorMissionAction(mission.id) },
            onFinalize: { viewModel.finalizeIndoorMission(mission.id) },
            onAppearSync: {
                if animatedQuestProgress[mission.id] == nil {
                    animatedQuestProgress[mission.id] = mission.progress.progressRatio
                }
            },
            onProgressSync: { next in
                if isQuestMotionReduced {
                    animatedQuestProgress[mission.id] = next
                } else {
                    withAnimation(.easeOut(duration: 0.34)) {
                        animatedQuestProgress[mission.id] = next
                    }
                }
            }
        )
    }
}

private extension String {
    /// 앞뒤 공백을 제거한 결과가 비어 있으면 `nil`을 반환합니다.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    HomeView()
}
