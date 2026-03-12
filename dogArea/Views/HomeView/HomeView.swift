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
    @Binding private var externalRoute: HomeExternalRoute?
    @StateObject var viewModel = HomeViewModel()
    @State private var animatedQuestProgress: [String: Double] = [:]
    @State private var questProgressPulseMissionId: String? = nil
    @State private var questClaimPulseMissionId: String? = nil
    @State private var questCompletionModal: QuestCompletionPresentation? = nil
    @State private var questCompletionPop: Bool = false
    @State private var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var hasInjectedWeatherGuidanceUITestPresentation: Bool = false
    @State private var seasonAnimatedProgress: Double = 0
    @State private var seasonGaugeWaveOffset: CGFloat = -120
    @State private var seasonShieldRotation: Double = 0
    @State private var seasonResultModal: SeasonResultPresentation? = nil
    @State private var seasonResultPop: Bool = false
    @State private var seasonResultRevealRank: Bool = false
    @State private var seasonResultRevealContribution: Bool = false
    @State private var seasonResultRevealShield: Bool = false
    @State private var seasonResetBannerVisible: Bool = false
    @State private var seasonGuidePresentation: SeasonGuidePresentation? = nil
    @State private var homeMissionGuidePresentation: HomeMissionGuidePresentation? = nil
    @State private var isWalkPrimaryLoopGuidePresented: Bool = false
    @State private var isHomeMissionGuideCoachVisible: Bool = false
    @State private var areaMilestonePop: Bool = false
    @State private var questWidgetTab: HomeQuestWidgetTab = .daily
    @State private var homeScrollOffsetY: CGFloat = 0
    @State private var isSeasonDetailPresented: Bool = false
    @State private var isWeatherGuidancePresented: Bool = false
    @State private var isTerritoryGoalPresented: Bool = false
    @State private var territoryGoalEntryContext: TerritoryGoalEntryContext? = nil
    @State private var questWidgetEntryContext: QuestWidgetEntryContext? = nil
    @State private var pendingHomeScrollTarget: HomeExternalScrollTarget? = nil
    @State private var hasAppearedOnce: Bool = false
    @State private var isHomeVisible: Bool = false
    @State private var hasInjectedHomeMissionGuideUITestPresentation: Bool = false
    private let seasonGuidePresentationService: SeasonGuidePresentationProviding = SeasonGuidePresentationService()
    private let seasonGuideStateStore: SeasonGuideStateStoring = DefaultSeasonGuideStateStore.shared
    private let homeMissionGuidePresentationService: HomeMissionGuidePresentationProviding = HomeMissionGuidePresentationService()
    private let homeMissionGuideStateStore: HomeMissionGuideStateStoring = DefaultHomeMissionGuideStateStore.shared
    private let walkPrimaryLoopPresentationService: HomeWalkPrimaryLoopPresenting = HomeWalkPrimaryLoopPresentationService()

    /// 외부 라우트를 주입받아 홈 화면을 초기화합니다.
    /// - Parameter externalRoute: 위젯/딥링크에서 전달된 홈 외부 라우트 바인딩입니다.
    init(externalRoute: Binding<HomeExternalRoute?> = .constant(nil as HomeExternalRoute?)) {
        _externalRoute = externalRoute
    }

    private var isQuestMotionReduced: Bool {
        accessibilityReduceMotion
    }
    private var isSeasonMotionReduced: Bool {
        accessibilityReduceMotion || isLowPowerModeEnabled
    }

    /// 홈 상단 인사말에 노출할 사용자 이름을 계산합니다.
    private var displayUserName: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.HomeHeaderLongName") {
            return "반가운산책메이트김태훈과함께걷는긴이름사용자"
        }
        let fallback = viewModel.selectedPetName
        return viewModel.userInfo?.name.nilIfBlank ?? fallback
    }

    /// 홈 헤더의 반려견 인사말에 사용할 이름을 계산합니다.
    private var headerSelectedPetName: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.HomeHeaderLongName") {
            return "아주아주긴이름을가진반려견친구"
        }
        return viewModel.selectedPetName
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

    /// 홈 상단에서 산책 기본 루프 설명 카드에 사용할 프레젠테이션을 계산합니다.
    private var walkPrimaryLoopPresentation: HomeWalkPrimaryLoopPresentation {
        walkPrimaryLoopPresentationService.makePresentation(
            selectedPetName: viewModel.selectedPetName,
            walkRecordCount: viewModel.allPolygons.count,
            totalDuration: viewModel.totalTime,
            totalArea: viewModel.totalArea,
            hasIndoorMissionReplacement: viewModel.indoorMissionBoard.riskLevel != .clear,
            localizedCopy: viewModel.localizedCopy(ko:en:)
        )
    }

    /// 홈 미션 섹션 상단에 1회성으로 노출할 코치 카드 프레젠테이션을 계산합니다.
    private var homeMissionGuideCoachPresentation: HomeMissionGuideCoachPresentation? {
        guard isHomeMissionGuideCoachVisible else { return nil }
        return makeHomeMissionGuidePresentation(for: .firstVisitCoach).coachPresentation
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottomTrailing) {
                Color.appTabScaffoldBackground
                    .ignoresSafeArea()

                homeDashboardScrollView

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
            .onChange(of: pendingHomeScrollTarget) { _, target in
                guard let target else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.24)) {
                        scrollProxy.scrollTo(target.rawValue, anchor: .top)
                    }
                    pendingHomeScrollTarget = nil
                }
            }
            .navigationDestination(isPresented: $isTerritoryGoalPresented) {
                TerritoryGoalView(
                    viewModel: TerritoryGoalViewModel(
                        homeViewModel: viewModel,
                        entryContext: territoryGoalEntryContext
                    )
                )
            }
        }
    }

    /// 홈 대시보드의 스크롤 컨테이너와 생명주기 modifier를 구성합니다.
    /// - Returns: 홈 카드/배너/시트/상태 반응을 포함한 스크롤 뷰입니다.
    private var homeDashboardScrollView: some View {
        configuredHomeDashboardScrollView(
            ScrollView(showsIndicators: false) {
                homeDashboardContent
            }
        )
        .nonMapRootTopChrome {
            homeHeaderSection
                .padding(.horizontal, 16)
        }
    }

    /// 홈 대시보드의 카드와 배너 콘텐츠를 순서대로 렌더링합니다.
    /// - Returns: 홈 스크롤 내부에 배치되는 메인 콘텐츠 뷰입니다.
    private var homeDashboardContent: some View {
        VStack(spacing: 16) {
            homeScrollAnchorMarkers
            homeWalkPrimaryLoopSection
            homeGuestDataUpgradeSection
            homeStatusBannerSection
            homeSelectedPetContextSection
            homeWeeklySnapshotSection
            seasonMotionCard(summary: viewModel.seasonMotionSummary)
            weatherDetailCard(presentation: viewModel.weatherDetailPresentation)
            homeMissionSection
            territoryHeaderSection
            goalTrackerCard
            recentConqueredCard
        }
        .padding(.horizontal, 16)
    }

    /// 게스트 데이터 이관 리포트 카드를 필요할 때만 렌더링합니다.
    private var homeGuestDataUpgradeSection: some View {
        Group {
            if let report = viewModel.guestDataUpgradeReport {
                guestDataUpgradeCard(report: report)
            }
        }
    }

    /// 홈 상태 배너들을 우선순위 순으로 묶어서 렌더링합니다.
    private var homeStatusBannerSection: some View {
        Group {
            if let context = questWidgetEntryContext {
                HomeStatusBannerView(message: context.bannerMessage, isWarning: context.isWarning)
                    .accessibilityIdentifier("home.quest.externalRouteBanner")
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
        }
    }

    /// 선택 반려견 문맥과 다중 반려견 전환 영역을 묶어 렌더링합니다.
    private var homeSelectedPetContextSection: some View {
        Group {
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
        }
    }

    /// 홈 상단에서 산책이 제품의 기본 루프라는 설명 카드를 렌더링합니다.
    private var homeWalkPrimaryLoopSection: some View {
        HomeWalkPrimaryLoopCardView(
            presentation: walkPrimaryLoopPresentation,
            onOpenGuide: { isWalkPrimaryLoopGuidePresented = true }
        )
    }

    /// 날씨 기반 미션 카드와 보조 상태 카드를 한 섹션으로 렌더링합니다.
    private var homeMissionSection: some View {
        homeMissionSectionContent
    }

    /// 홈 대시보드에서 미션 카드 직전의 소개 문구와 상태 카드를 묶습니다.
    private var homeMissionSectionContent: some View {
        HomeMissionSectionView(
            board: viewModel.indoorMissionBoard,
            presentation: viewModel.indoorMissionPresentation,
            missionGuideCoachPresentation: homeMissionGuideCoachPresentation,
            weatherMissionStatusSummary: viewModel.weatherMissionStatusSummary,
            weatherShieldDailySummary: viewModel.weatherShieldDailySummary,
            questWidgetTab: $questWidgetTab,
            questReminderEnabled: viewModel.questReminderEnabled,
            onSetQuestReminderEnabled: viewModel.setQuestReminderEnabled,
            canSubmitWeatherMismatchFeedback: viewModel.canSubmitWeatherMismatchFeedback,
            weatherFeedbackRemainingCount: viewModel.weatherFeedbackRemainingCount,
            weatherFeedbackWeeklyLimit: viewModel.weatherFeedbackWeeklyLimit,
            weatherFeedbackResultMessage: viewModel.weatherFeedbackResultMessage,
            questAlternativeActionSuggestion: viewModel.questAlternativeActionSuggestion,
            seasonSummary: viewModel.seasonMotionSummary,
            isSeasonMotionReduced: isSeasonMotionReduced,
            seasonGaugeWaveOffset: seasonGaugeWaveOffset,
            animatedQuestProgress: animatedQuestProgress,
            questProgressPulseMissionId: questProgressPulseMissionId,
            questClaimPulseMissionId: questClaimPulseMissionId,
            isQuestMotionReduced: isQuestMotionReduced,
            onSubmitWeatherMismatchFeedback: { viewModel.submitWeatherMismatchFeedback() },
            onActivateEasyDayMode: { viewModel.activateEasyDayMode() },
            onRecordIndoorMissionAction: viewModel.recordIndoorMissionAction,
            onFinalizeIndoorMission: viewModel.finalizeIndoorMission,
            onOpenMissionGuide: { openHomeMissionGuide(for: .helpButtonReentry) },
            onDismissMissionGuideCoach: dismissHomeMissionGuideCoach,
            onSyncMissionAppearProgress: { mission in
                if animatedQuestProgress[mission.id] == nil {
                    animatedQuestProgress[mission.id] = mission.progress.progressRatio
                }
            },
            onSyncMissionProgress: { mission, next in
                if isQuestMotionReduced {
                    animatedQuestProgress[mission.id] = next
                } else {
                    withAnimation(.easeOut(duration: 0.34)) {
                        animatedQuestProgress[mission.id] = next
                    }
                }
            }
        )
        .id(HomeExternalScrollTarget.questMissionSection.rawValue)
    }

    /// 홈 대시보드 스크롤 뷰에 상태 동기화, 시트, 전역 레이아웃 modifier를 적용합니다.
    /// - Parameter content: 홈 본문 카드가 이미 배치된 스크롤 컨테이너입니다.
    /// - Returns: 홈 화면 수명주기와 이벤트 반응이 연결된 스크롤 뷰입니다.
    private func configuredHomeDashboardScrollView<Content: View>(_ content: Content) -> some View {
        let lifecycleConfigured = configuredHomeDashboardLifecycle(content)
        let eventConfigured = configuredHomeDashboardEventHandlers(lifecycleConfigured)
        return configuredHomeDashboardPresentation(eventConfigured)
    }

    /// 홈 스크롤 뷰의 기본 수명주기와 스크롤 상태 동기화를 적용합니다.
    /// - Parameter content: 홈 카드가 배치된 스크롤 컨테이너입니다.
    /// - Returns: 기본 lifecycle modifier가 연결된 타입 소거 뷰입니다.
    private func configuredHomeDashboardLifecycle<Content: View>(_ content: Content) -> AnyView {
        AnyView(
            content
                .coordinateSpace(name: "home.scroll")
                .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                    homeScrollOffsetY = value
                }
                .refreshable {
                    viewModel.fetchData()
                }
                .onAppear {
                    isHomeVisible = true
                    consumeExternalRouteIfNeeded()
                    if hasAppearedOnce {
                        viewModel.refreshForVisibleReentry()
                    } else {
                        hasAppearedOnce = true
                    }
                    seasonAnimatedProgress = viewModel.seasonMotionSummary.progress
                    if viewModel.seasonMotionSummary.weatherShieldActive {
                        startSeasonShieldRingAnimationIfNeeded()
                    }
                    evaluateHomeMissionGuideCoachIfNeeded()
                    presentHomeMissionGuideIfRequestedForUITest()
                    presentWeatherGuidanceIfRequestedForUITest()
                }
                .onDisappear {
                    isHomeVisible = false
                }
        )
    }

    /// 홈 스크롤 뷰에 상태 변화 기반 반응 modifier를 적용합니다.
    /// - Parameter content: lifecycle modifier가 반영된 홈 스크롤 뷰입니다.
    /// - Returns: 상태 변화 핸들러가 연결된 타입 소거 뷰입니다.
    private func configuredHomeDashboardEventHandlers<Content: View>(_ content: Content) -> AnyView {
        let statusConfigured = configuredHomeDashboardStatusHandlers(content)
        let motionConfigured = configuredHomeDashboardMotionHandlers(statusConfigured)
        let systemConfigured = configuredHomeDashboardSystemHandlers(motionConfigured)
        return AnyView(systemConfigured)
    }

    /// 홈 상태 배너와 앱 복귀 갱신 이벤트를 묶어 적용합니다.
    /// - Parameter content: lifecycle modifier가 반영된 홈 스크롤 뷰입니다.
    /// - Returns: 상태 배너/복귀 갱신 핸들러가 적용된 타입 소거 뷰입니다.
    private func configuredHomeDashboardStatusHandlers<Content: View>(_ content: Content) -> AnyView {
        AnyView(
            content
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, isHomeVisible else { return }
                    viewModel.refreshForAppResumeIfNeeded()
                }
                .onChange(of: viewModel.aggregationStatusMessage) { _, newValue in
                    guard newValue != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        viewModel.clearAggregationStatusMessage()
                    }
                }
                .onChange(of: viewModel.indoorMissionStatusMessage) { _, newValue in
                    guard newValue != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        viewModel.clearIndoorMissionStatusMessage()
                    }
                }
                .onChange(of: viewModel.indoorMissionBoard.shouldDisplayCard) { _, _ in
                    evaluateHomeMissionGuideCoachIfNeeded()
                }
                .onChange(of: viewModel.weatherFeedbackResultMessage) { _, newValue in
                    guard newValue != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                        viewModel.clearWeatherFeedbackResultMessage()
                    }
                }
                .onChange(of: questWidgetEntryContext?.bannerMessage) { _, newValue in
                    guard newValue != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        questWidgetEntryContext = nil
                    }
                }
        )
    }

    /// 퀘스트/시즌/영역 마일스톤 같은 홈 프레젠테이션 이벤트를 묶어 적용합니다.
    /// - Parameter content: 상태 배너 핸들러가 연결된 홈 스크롤 뷰입니다.
    /// - Returns: 홈 프레젠테이션 이벤트 반응이 적용된 타입 소거 뷰입니다.
    private func configuredHomeDashboardMotionHandlers<Content: View>(_ content: Content) -> AnyView {
        AnyView(
            content
                .onChange(of: viewModel.questMotionEvent) { _, event in
                    handleQuestMotionEvent(event)
                }
                .onChange(of: viewModel.questCompletionPresentation) { _, payload in
                    guard let payload else { return }
                    presentQuestCompletionModal(payload)
                }
                .onChange(of: viewModel.seasonMotionSummary.progress) { _, progress in
                    animateSeasonProgress(to: progress)
                }
                .onChange(of: viewModel.seasonMotionSummary.weatherShieldActive) { _, active in
                    if active {
                        startSeasonShieldRingAnimationIfNeeded()
                    } else {
                        seasonShieldRotation = 0
                    }
                }
                .onChange(of: viewModel.seasonMotionEvent) { _, event in
                    handleSeasonMotionEvent(event)
                }
                .onChange(of: viewModel.seasonResultPresentation) { _, payload in
                    guard let payload else { return }
                    presentSeasonResultModal(payload)
                }
                .onChange(of: viewModel.seasonResetTransitionToken) { _, token in
                    guard token != nil else { return }
                    presentSeasonResetTransitionBanner()
                }
                .onChange(of: viewModel.areaMilestonePresentation) { _, event in
                    guard event != nil else { return }
                    presentAreaMilestoneOverlay()
                }
        )
    }

    /// 인증 결과, 외부 라우트, 저전력 상태 같은 시스템 이벤트를 묶어 적용합니다.
    /// - Parameter content: 프레젠테이션 이벤트가 연결된 홈 스크롤 뷰입니다.
    /// - Returns: 시스템 이벤트 반응이 적용된 타입 소거 뷰입니다.
    private func configuredHomeDashboardSystemHandlers<Content: View>(_ content: Content) -> AnyView {
        AnyView(
            content
                .onChange(of: authFlow.guestDataUpgradeResult?.executedAt) { _, _ in
                    viewModel.refreshGuestDataUpgradeReport()
                }
                .onChange(of: externalRoute?.id) { _, _ in
                    consumeExternalRouteIfNeeded()
                }
                .onChange(of: isLowPowerModeEnabled) { _, enabled in
                    if enabled {
                        seasonShieldRotation = 0
                    } else if viewModel.seasonMotionSummary.weatherShieldActive {
                        startSeasonShieldRingAnimationIfNeeded()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                    isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
        )
    }

    /// 홈 스크롤 뷰에 시트와 전역 레이아웃 modifier를 적용합니다.
    /// - Parameter content: 상태 변화 핸들러가 연결된 홈 스크롤 뷰입니다.
    /// - Returns: 최종 홈 대시보드 스크롤 뷰입니다.
    private func configuredHomeDashboardPresentation<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $isSeasonDetailPresented) {
                HomeSeasonDetailSheetView(
                    summary: viewModel.seasonMotionSummary,
                    remainingTimeText: viewModel.seasonRemainingTimeText,
                    onClose: { isSeasonDetailPresented = false }
                )
            }
            .sheet(isPresented: $isWeatherGuidancePresented) {
                HomeWeatherGuidanceSheetView(
                    presentation: viewModel.weatherGuidancePresentation,
                    onClose: { isWeatherGuidancePresented = false }
                )
            }
            .sheet(isPresented: $isWalkPrimaryLoopGuidePresented) {
                HomeWalkPrimaryLoopGuideSheetView(
                    presentation: walkPrimaryLoopPresentation,
                    onClose: { isWalkPrimaryLoopGuidePresented = false }
                )
            }
            .sheet(item: $seasonGuidePresentation) { presentation in
                SeasonGuideSheetView(
                    presentation: presentation,
                    onClose: { seasonGuidePresentation = nil }
                )
            }
            .sheet(item: $homeMissionGuidePresentation) { presentation in
                HomeMissionGuideSheetView(
                    presentation: presentation,
                    onClose: { homeMissionGuidePresentation = nil }
                )
            }
            .appTabRootScrollLayout(
                extraBottomPadding: AppTabLayoutMetrics.defaultScrollExtraBottomPadding,
                topSafeAreaPadding: 0
            )
    }

    /// 홈 대시보드 상단 인사말과 레벨 배지를 렌더링합니다.
    private var homeHeaderSection: some View {
        HomeHeaderSectionView(
            displayUserName: displayUserName,
            levelBadgeText: levelBadgeText,
            selectedPetName: headerSelectedPetName
        )
    }

    private var homeScrollAnchorMarkers: some View {
        VStack(spacing: 0) {
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
        }
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
        case .petIdRequired:
            return "반려견 정보가 비어 있어 이관할 수 없어요."
        case .sessionInvalidPetReference:
            return "연결된 반려견 정보를 다시 확인해야 해요."
        case .sessionTimeRangeInvalid:
            return "산책 시작/종료 시간이 올바르지 않아요."
        case .sessionOwnershipConflict:
            return "계정 소유권 확인이 필요해요."
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

    /// UI 테스트 플래그가 활성화된 경우 홈 날씨 가이드 시트를 자동 노출합니다.
    /// - Returns: 없음. 중복 노출은 내부 플래그로 한 번만 처리합니다.
    private func presentWeatherGuidanceIfRequestedForUITest() {
        guard ProcessInfo.processInfo.arguments.contains("-UITest.HomeWeatherGuidancePresented"),
              hasInjectedWeatherGuidanceUITestPresentation == false else { return }
        hasInjectedWeatherGuidanceUITestPresentation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isWeatherGuidancePresented = true
        }
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
            onOpenDetail: {
                territoryGoalEntryContext = nil
                isTerritoryGoalPresented = true
            }
        )
    }

    /// 외부 라우트를 한 번 소비해 홈 상세 네비게이션 상태에 반영합니다.
    /// - Returns: 없음. 처리한 라우트는 즉시 제거해 중복 네비게이션을 방지합니다.
    private func consumeExternalRouteIfNeeded() {
        guard let externalRoute else { return }
        switch externalRoute.destination {
        case .territoryGoalDetail:
            territoryGoalEntryContext = externalRoute.territoryGoalEntryContext
            isTerritoryGoalPresented = true
        case .questMissionBoard:
            questWidgetEntryContext = externalRoute.questWidgetEntryContext
            questWidgetTab = .daily
            pendingHomeScrollTarget = .questMissionSection
        }
        self.externalRoute = nil
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

    /// 홈에서 원시 날씨 수치와 관측 상태를 요약하는 상세 카드를 렌더링합니다.
    /// - Parameter presentation: 홈 카드가 직접 사용할 날씨 상세 프레젠테이션 상태입니다.
    /// - Returns: 기온/체감/습도/강수/공기질을 보여주는 상세 카드 뷰입니다.
    private func weatherDetailCard(presentation: HomeWeatherSnapshotCardPresentation) -> some View {
        HomeWeatherSnapshotCardView(
            presentation: presentation,
            onOpenGuidanceDetail: { isWeatherGuidancePresented = true }
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
            onOpenGuide: { openSeasonGuideFromHomeCard() },
            onOpenDetail: {
                isSeasonDetailPresented = true
            }
        )
    }

    /// 홈 시즌 카드에서 시즌 설명 가이드를 엽니다.
    private func openSeasonGuideFromHomeCard() {
        seasonGuideStateStore.markInitialSeasonGuidePresented()
        seasonGuidePresentation = seasonGuidePresentationService.makePresentation(for: .homeSeasonCard)
    }

    /// 홈 미션 도움말 sheet가 사용할 프레젠테이션을 생성합니다.
    /// - Parameter context: 사용자가 도움말을 연 진입 맥락입니다.
    /// - Returns: 코치 카드와 상세 sheet가 함께 재사용할 홈 미션 도움말 프레젠테이션입니다.
    private func makeHomeMissionGuidePresentation(for context: HomeMissionGuideEntryContext) -> HomeMissionGuidePresentation {
        homeMissionGuidePresentationService.makePresentation(
            board: viewModel.indoorMissionBoard,
            weatherSummary: viewModel.weatherMissionStatusSummary,
            context: context,
            localizedCopy: viewModel.localizedCopy(ko:en:)
        )
    }

    /// 홈 미션 도움말의 1회성 코치 카드를 노출할지 평가합니다.
    /// - Returns: 없음. 필요 시 최초 노출 소비 상태를 기록하고 코치 카드 표시 상태를 갱신합니다.
    private func evaluateHomeMissionGuideCoachIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-UITest.HomeMissionGuideCoachVisible") {
            isHomeMissionGuideCoachVisible = true
            return
        }
        guard homeMissionGuideStateStore.hasPresentedInitialGuide() == false else { return }
        guard viewModel.indoorMissionBoard.shouldDisplayCard else { return }
        homeMissionGuideStateStore.markInitialGuidePresented()
        isHomeMissionGuideCoachVisible = true
    }

    /// 홈 미션 도움말 sheet를 지정된 진입 맥락으로 엽니다.
    /// - Parameter context: 사용자가 도움말을 연 진입 맥락입니다.
    /// - Returns: 없음. 코치 카드를 내리고 재진입 가능한 상세 sheet를 표시합니다.
    private func openHomeMissionGuide(for context: HomeMissionGuideEntryContext) {
        homeMissionGuideStateStore.markInitialGuidePresented()
        isHomeMissionGuideCoachVisible = false
        homeMissionGuidePresentation = makeHomeMissionGuidePresentation(for: context)
    }

    /// 홈 미션 섹션 상단의 1회성 코치 카드를 닫습니다.
    /// - Returns: 없음. 최초 노출 상태를 소비하고 현재 코치 카드만 내립니다.
    private func dismissHomeMissionGuideCoach() {
        homeMissionGuideStateStore.markInitialGuidePresented()
        isHomeMissionGuideCoachVisible = false
    }

    /// UI 테스트 요청이 있으면 홈 미션 도움말 sheet를 강제로 표시합니다.
    /// - Returns: 없음. 같은 실행에서 중복 주입되지 않도록 1회만 처리합니다.
    private func presentHomeMissionGuideIfRequestedForUITest() {
        guard ProcessInfo.processInfo.arguments.contains("-UITest.HomeMissionGuidePresented") else { return }
        guard hasInjectedHomeMissionGuideUITestPresentation == false else { return }
        hasInjectedHomeMissionGuideUITestPresentation = true
        homeMissionGuidePresentation = makeHomeMissionGuidePresentation(for: .helpButtonReentry)
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

}

private struct HomeMissionSectionView: View {
    let board: IndoorMissionBoard
    let presentation: HomeIndoorMissionBoardPresentation
    let missionGuideCoachPresentation: HomeMissionGuideCoachPresentation?
    let weatherMissionStatusSummary: WeatherMissionStatusSummary
    let weatherShieldDailySummary: WeatherShieldDailySummary?
    @Binding var questWidgetTab: HomeQuestWidgetTab
    let questReminderEnabled: Bool
    let onSetQuestReminderEnabled: (Bool) -> Void
    let canSubmitWeatherMismatchFeedback: Bool
    let weatherFeedbackRemainingCount: Int
    let weatherFeedbackWeeklyLimit: Int
    let weatherFeedbackResultMessage: String?
    let questAlternativeActionSuggestion: String?
    let seasonSummary: SeasonMotionSummary
    let isSeasonMotionReduced: Bool
    let seasonGaugeWaveOffset: CGFloat
    let animatedQuestProgress: [String: Double]
    let questProgressPulseMissionId: String?
    let questClaimPulseMissionId: String?
    let isQuestMotionReduced: Bool
    let onSubmitWeatherMismatchFeedback: () -> Void
    let onActivateEasyDayMode: () -> Void
    let onRecordIndoorMissionAction: (String) -> Void
    let onFinalizeIndoorMission: (String) -> Void
    let onOpenMissionGuide: () -> Void
    let onDismissMissionGuideCoach: () -> Void
    let onSyncMissionAppearProgress: (IndoorMissionCardModel) -> Void
    let onSyncMissionProgress: (IndoorMissionCardModel, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(presentation.sectionTitle)
                            .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .title2))
                        Text("보조 흐름")
                            .appPill(isActive: false)
                            .accessibilityIdentifier("home.mission.secondaryLabel")
                    }
                    Spacer(minLength: 12)
                    Button(action: onOpenMissionGuide) {
                        Text("미션이 뭔가요?")
                            .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .headline))
                            .foregroundStyle(Color.appInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .background(Color.appYellowPale.opacity(0.95))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.quest.help.open")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("산책이 어려운 날에만 확인하는 보조 카드예요. 기본은 산책 기록입니다.")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let missionGuideCoachPresentation {
                HomeMissionGuideCoachCardView(
                    presentation: missionGuideCoachPresentation,
                    onOpenGuide: onOpenMissionGuide,
                    onDismiss: onDismissMissionGuideCoach
                )
            }

            HomeWeatherMissionStatusCardView(summary: weatherMissionStatusSummary)

            if let weatherShieldDailySummary {
                HomeWeatherShieldSummaryCardView(summary: weatherShieldDailySummary)
            }

            HomeIndoorMissionCardContainerView(
                board: board,
                presentation: presentation,
                weatherMissionStatusSummary: weatherMissionStatusSummary,
                questWidgetTab: $questWidgetTab,
                questReminderEnabled: questReminderEnabled,
                onSetQuestReminderEnabled: onSetQuestReminderEnabled,
                canSubmitWeatherMismatchFeedback: canSubmitWeatherMismatchFeedback,
                weatherFeedbackRemainingCount: weatherFeedbackRemainingCount,
                weatherFeedbackWeeklyLimit: weatherFeedbackWeeklyLimit,
                weatherFeedbackResultMessage: weatherFeedbackResultMessage,
                questAlternativeActionSuggestion: questAlternativeActionSuggestion,
                seasonSummary: seasonSummary,
                isSeasonMotionReduced: isSeasonMotionReduced,
                seasonGaugeWaveOffset: seasonGaugeWaveOffset,
                animatedQuestProgress: animatedQuestProgress,
                questProgressPulseMissionId: questProgressPulseMissionId,
                questClaimPulseMissionId: questClaimPulseMissionId,
                isQuestMotionReduced: isQuestMotionReduced,
                onSubmitWeatherMismatchFeedback: onSubmitWeatherMismatchFeedback,
                onActivateEasyDayMode: onActivateEasyDayMode,
                onRecordIndoorMissionAction: onRecordIndoorMissionAction,
                onFinalizeIndoorMission: onFinalizeIndoorMission,
                onSyncMissionAppearProgress: onSyncMissionAppearProgress,
                onSyncMissionProgress: onSyncMissionProgress
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quest.section")
    }
}

private struct HomeIndoorMissionCardContainerView: View {
    let board: IndoorMissionBoard
    let presentation: HomeIndoorMissionBoardPresentation
    let weatherMissionStatusSummary: WeatherMissionStatusSummary
    @Binding var questWidgetTab: HomeQuestWidgetTab
    let questReminderEnabled: Bool
    let onSetQuestReminderEnabled: (Bool) -> Void
    let canSubmitWeatherMismatchFeedback: Bool
    let weatherFeedbackRemainingCount: Int
    let weatherFeedbackWeeklyLimit: Int
    let weatherFeedbackResultMessage: String?
    let questAlternativeActionSuggestion: String?
    let seasonSummary: SeasonMotionSummary
    let isSeasonMotionReduced: Bool
    let seasonGaugeWaveOffset: CGFloat
    let animatedQuestProgress: [String: Double]
    let questProgressPulseMissionId: String?
    let questClaimPulseMissionId: String?
    let isQuestMotionReduced: Bool
    let onSubmitWeatherMismatchFeedback: () -> Void
    let onActivateEasyDayMode: () -> Void
    let onRecordIndoorMissionAction: (String) -> Void
    let onFinalizeIndoorMission: (String) -> Void
    let onSyncMissionAppearProgress: (IndoorMissionCardModel) -> Void
    let onSyncMissionProgress: (IndoorMissionCardModel, Double) -> Void

    private var completedDailyCount: Int {
        board.missions.filter { $0.progress.isCompleted }.count
    }

    private var totalDailyCount: Int {
        board.missions.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            HomeQuestWidgetTabSelectorView(selectedTab: questWidgetTab) { tab in
                questWidgetTab = tab
            }

            HomeQuestReminderToggleRowView(
                isEnabled: Binding(
                    get: { questReminderEnabled },
                    set: { onSetQuestReminderEnabled($0) }
                )
            )

            if questWidgetTab == .daily {
                dailyMissionContent
            } else {
                HomeWeeklyQuestSummaryView(
                    summary: seasonSummary,
                    completedDailyCount: completedDailyCount,
                    totalDailyCount: totalDailyCount,
                    isSeasonMotionReduced: isSeasonMotionReduced,
                    seasonGaugeWaveOffset: seasonGaugeWaveOffset
                )
            }

            if let questAlternativeActionSuggestion {
                HomeQuestAlternativeSuggestionCardView(text: questAlternativeActionSuggestion)
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

    @ViewBuilder
    private var dailyMissionContent: some View {
        Text(presentation.sectionSubtitle)
            .font(.appFont(for: .Light, size: 12))
            .foregroundStyle(Color.appTextDarkGray)
            .fixedSize(horizontal: false, vertical: true)

        HomeMissionTrackingModeOverviewView(
            title: presentation.trackingOverviewTitle,
            modes: presentation.trackingModes
        )

        HStack {
            Text(weatherMissionStatusSummary.appliedAtText)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Text(weatherMissionStatusSummary.shieldUsageText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }

        if board.riskLevel != .clear {
            HStack(spacing: 8) {
                Button("체감 날씨 다름") {
                    onSubmitWeatherMismatchFeedback()
                }
                .disabled(canSubmitWeatherMismatchFeedback == false)
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(canSubmitWeatherMismatchFeedback ? Color.appYellow : Color.appTextLightGray)
                .cornerRadius(8)

                Text("주간 남은 반영 \(weatherFeedbackRemainingCount)/\(weatherFeedbackWeeklyLimit)")
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
            HomeMissionDifficultySummaryView(
                summary: difficulty,
                onActivateEasyDayMode: onActivateEasyDayMode
            )
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

        if let weatherFeedbackResultMessage {
            Text(weatherFeedbackResultMessage)
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
            missionRowsSection(
                title: "지금 진행할 미션",
                accessibilityIdentifier: "home.quest.section.active",
                rows: presentation.activeMissions
            )
            if let completedTitle = presentation.completedSectionTitle {
                missionRowsSection(
                    title: completedTitle,
                    accessibilityIdentifier: "home.quest.section.completed",
                    rows: presentation.completedMissions
                )
            }
        }
    }

    /// 홈 미션 카드 내부에서 섹션 제목과 미션 행 목록을 렌더링합니다.
    /// - Parameters:
    ///   - title: 카드 안에서 노출할 섹션 제목입니다.
    ///   - accessibilityIdentifier: 접근성 및 UI 테스트 식별자입니다.
    ///   - rows: 섹션에 렌더링할 미션 행 프레젠테이션 목록입니다.
    /// - Returns: 제목과 행 목록을 포함한 섹션 뷰입니다.
    private func missionRowsSection(
        title: String,
        accessibilityIdentifier: String,
        rows: [HomeIndoorMissionRowPresentation]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(Color.appTextDarkGray)
            ForEach(rows) { row in
                missionRow(presentation: row)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// 개별 실내 미션 프레젠테이션을 홈 카드 행으로 렌더링합니다.
    /// - Parameter presentation: 렌더링할 미션 행 프레젠테이션입니다.
    /// - Returns: 애니메이션 상태와 액션을 포함한 홈 미션 행 뷰입니다.
    private func missionRow(presentation: HomeIndoorMissionRowPresentation) -> some View {
        let mission = presentation.mission
        return HomeIndoorMissionRowView(
            presentation: presentation,
            animatedProgress: animatedQuestProgress[mission.id] ?? mission.progress.progressRatio,
            isQuestMotionReduced: isQuestMotionReduced,
            showClaimPulse: questClaimPulseMissionId == mission.id,
            showProgressPulse: questProgressPulseMissionId == mission.id,
            onRecordAction: { onRecordIndoorMissionAction(mission.id) },
            onFinalize: { onFinalizeIndoorMission(mission.id) },
            onAppearSync: {
                onSyncMissionAppearProgress(mission)
            },
            onProgressSync: { next in
                onSyncMissionProgress(mission, next)
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
