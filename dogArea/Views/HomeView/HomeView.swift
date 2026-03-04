//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
    private enum QuestWidgetTab: String, CaseIterable, Identifiable {
        case daily
        case weekly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily:
                return "일일"
            case .weekly:
                return "주간"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
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
    @State private var questWidgetTab: QuestWidgetTab = .daily
    @State private var isSeasonCardCollapsed: Bool = false
    @State private var isSeasonDetailPresented: Bool = false

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

    /// 시즌 카드 토글 버튼에 노출할 액션 타이틀을 계산합니다.
    private var seasonCardToggleTitle: String {
        isSeasonCardCollapsed ? "시즌 카드 펼치기" : "시즌 카드 접기"
    }

    /// 시즌 카드 토글 버튼에 노출할 SF Symbol 이름을 계산합니다.
    private var seasonCardToggleIconName: String {
        isSeasonCardCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appTabScaffoldBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
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
                    if viewModel.indoorMissionBoard.shouldDisplayCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("데일리 미션 상태")
                                .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .title2))
                            Text("오늘 날씨·활동 상태를 반영한 추천 미션 진행 현황입니다.")
                                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        indoorMissionCard(board: viewModel.indoorMissionBoard)
                    }
                    territoryHeaderSection
                    goalTrackerCard
                    recentConqueredCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, CustomTabBar.reservedContentHeight + 12)
            }
            .refreshable {
                viewModel.fetchData()
            }
            .onAppear{
                viewModel.reloadUserInfo()
                viewModel.fetchData()
                seasonAnimatedProgress = viewModel.seasonMotionSummary.progress
                if viewModel.seasonMotionSummary.weatherShieldActive {
                    startSeasonShieldRingAnimationIfNeeded()
                }
            }.onChange(of: viewModel.aggregationStatusMessage) { _, newValue in
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
            }.onChange(of: isLowPowerModeEnabled) { _, enabled in
                if enabled {
                    seasonShieldRotation = 0
                } else if viewModel.seasonMotionSummary.weatherShieldActive {
                    startSeasonShieldRingAnimationIfNeeded()
                }
            }.onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }.sheet(isPresented: $isSeasonDetailPresented) {
                seasonDetailSheet
            }

            themeFloatingButton

            if let questCompletionModal {
                questCompletionOverlay(payload: questCompletionModal)
                    .zIndex(10)
            }
            if let seasonResultModal {
                seasonResultOverlay(payload: seasonResultModal)
                    .zIndex(11)
            }
            if seasonResetBannerVisible {
                seasonResetTransitionBanner
                    .zIndex(9)
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

    /// 우측 하단의 시즌 카드 표시 토글 버튼을 렌더링합니다.
    private var themeFloatingButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSeasonCardCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: seasonCardToggleIconName)
                    .font(.system(size: 14, weight: .semibold))
                Text(seasonCardToggleTitle)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, CustomTabBar.reservedContentHeight - 20)
        .accessibilityLabel(seasonCardToggleTitle)
        .accessibilityHint("시즌 카드 표시 상태를 전환합니다")
    }

    @ViewBuilder
    private func guestDataUpgradeCard(report: GuestDataUpgradeReport) -> some View {
        let validationText: String? = {
            guard let passed = report.validationPassed else { return nil }
            return passed ? "원격 검증 통과" : "원격 검증 실패: \(report.validationMessage ?? "mismatch")"
        }()
        VStack(alignment: .leading, spacing: 6) {
            Text(report.hasOutstandingWork ? "데이터 이관 재시도 필요" : "게스트 데이터 이관 완료")
                .font(.appFont(for: .SemiBold, size: 13))
            Text(
                "세션 \(report.sessionCount)건 · 포인트 \(report.pointCount)건 · 면적 \(report.totalAreaM2.calculatedAreaString)"
            )
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appTextDarkGray)
            if let validationText {
                Text(validationText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(report.validationPassed == true ? Color.appGreen : Color.appRed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(report.hasOutstandingWork ? Color.appRed : Color.appGreen, lineWidth: 0.4)
        )
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
            destination: TerritoryGoalView(viewModel: TerritoryGoalViewModel(homeViewModel: viewModel))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "영역 목표 트래커. 현재 영역 \(viewModel.myArea.area.calculatedAreaString), 다음 목표 \(viewModel.nextGoalArea?.areaName ?? "없음"), 남은 면적 \(viewModel.remainingAreaToGoal.calculatedAreaString)"
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(summary.title)
                    .font(.appFont(for: .SemiBold, size: 15))
                Spacer()
                Text(summary.badgeText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(summary.isFallback ? Color.appTextLightGray.opacity(0.35) : Color.appYellowPale)
                    .cornerRadius(8)
            }
            Text(summary.reasonText)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 8) {
                Text(summary.appliedAtText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                Spacer()
                Text(summary.shieldUsageText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(summary.riskLevel == .clear ? Color.appTextDarkGray : Color.appGreen)
            }
            if let fallbackNotice = summary.fallbackNotice {
                Text(fallbackNotice)
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appTextDarkGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.appTextLightGray.opacity(0.2))
                    .cornerRadius(8)
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
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityText)
    }

    private func weatherShieldSummaryCard(summary: WeatherShieldDailySummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("오늘 스트릭 보호 요약")
                    .font(.appFont(for: .SemiBold, size: 13))
                Text("보호 적용 \(summary.applyCount)회 · 마지막 \(summary.lastAppliedAtText)")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Spacer()
        }
        .padding(11)
        .background(Color.appGreen.opacity(0.22))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 스트릭 보호 요약. 적용 \(summary.applyCount)회, 마지막 \(summary.lastAppliedAtText)")
    }

    private func indoorMissionCard(board: IndoorMissionBoard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(questWidgetTab == .daily ? (board.riskLevel == .clear ? "데일리 미션 상태" : "악천후 실내 대체 미션") : "주간 퀘스트 요약")
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
                Text(viewModel.weatherMissionStatusSummary.reasonText)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
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

                if board.missions.isEmpty {
                    Text("오늘 활성화된 미션이 없어요.")
                        .font(.appFont(for: .Light, size: 12))
                        .foregroundStyle(Color.appTextDarkGray)
                        .padding(.vertical, 4)
                } else {
                    ForEach(board.missions) { mission in
                        indoorMissionRow(mission: mission)
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
    }

    /// 퀘스트 위젯에서 일일/주간 뷰를 전환하는 탭 선택 행입니다.
    private var questWidgetTabSelector: some View {
        HStack(spacing: 8) {
            ForEach(QuestWidgetTab.allCases) { tab in
                Button(tab.title) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        questWidgetTab = tab
                    }
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(questWidgetTab == tab ? Color.appYellow : Color.appTextLightGray.opacity(0.35))
                .cornerRadius(8)
            }
            Spacer()
        }
    }

    /// 하루 1회 퀘스트 리마인드 알림 설정 토글 행입니다.
    private var questReminderToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("퀘스트 리마인드")
                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                Text("매일 20:00 · 하루 최대 1회")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.questReminderEnabled },
                    set: { viewModel.setQuestReminderEnabled($0) }
                )
            )
            .labelsHidden()
            .tint(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x1E293B))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
    }

    /// 주간 퀘스트 진행도와 완료 현황을 요약해서 보여줍니다.
    private func weeklyQuestSummary(board: IndoorMissionBoard) -> some View {
        let summary = viewModel.seasonMotionSummary
        let completedDaily = board.missions.filter { $0.progress.isCompleted }.count
        let totalDaily = board.missions.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("이번 주 점수 \(Int(summary.score.rounded())) / \(Int(summary.targetScore.rounded()))")
                .font(.appFont(for: .SemiBold, size: 13))
            animatedSeasonGauge(progress: summary.progress)
                .frame(height: 8)
            HStack(spacing: 8) {
                seasonMetricPill(
                    title: "주간 기여",
                    value: "\(summary.contributionCount)회",
                    color: Color.appYellowPale
                )
                seasonMetricPill(
                    title: "오늘 완료",
                    value: "\(completedDaily)/\(totalDaily)",
                    color: Color.appGreen.opacity(0.22)
                )
            }
            Text("주간 점수는 미션 완료와 산책 기여로 누적됩니다.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }
    }

    /// 퀘스트 실패/만료 시 다음 행동을 안내하는 제안 카드입니다.
    private func questAlternativeSuggestionCard(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appYellowPale.opacity(0.65))
        .cornerRadius(8)
    }

    private func missionDifficultySummary(_ summary: IndoorMissionDifficultySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(summary.petName) 기준 난이도: \(summary.adjustmentDescription)")
                .font(.appFont(for: .SemiBold, size: 12))
            Text("연령 \(summary.ageBand.title) · 활동 \(summary.activityLevel.title) · 빈도 \(summary.walkFrequency.title)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            ForEach(summary.reasons.prefix(2), id: \.self) { reason in
                Text("• \(reason)")
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Text(summary.easyDayMessage)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(Color.appTextDarkGray)

            if summary.easyDayState == .available {
                Button("쉬운 날 모드 사용 (보상 -20%)") {
                    viewModel.activateEasyDayMode()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)
            } else if summary.easyDayState == .active {
                Text("오늘 쉬운 날 모드 적용됨")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
            }

            if summary.history.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    Text("최근 난이도 히스토리")
                        .font(.appFont(for: .SemiBold, size: 11))
                    ForEach(Array(summary.history.prefix(3))) { history in
                        Text(
                            "\(history.dayKey) · \(multiplierDescription(history.multiplier))\(history.easyDayApplied ? " · 쉬운 날" : "")"
                        )
                        .font(.appFont(for: .Light, size: 10))
                        .foregroundStyle(Color.appTextDarkGray)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(8)
    }

    private func seasonMotionCard(summary: SeasonMotionSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
                        .frame(width: 30, height: 30)
                    Image(systemName: "medal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("시즌 게이지")
                    .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                Text(summary.rankTier.title)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155))
                    .cornerRadius(9)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("시즌 점수 \(Int(summary.score.rounded())) / \(Int(summary.targetScore.rounded()))")
                    .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                Spacer()
                Text("+\(summary.todayScoreDelta) today")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }

            animatedSeasonGauge(progress: seasonAnimatedProgress)
                .frame(height: 10)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
                Text("남은 시간 \(viewModel.seasonRemainingTimeText)")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
                Spacer()
                Button("상세보기 >") {
                    isSeasonDetailPresented = true
                }
                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                .accessibilityIdentifier("home.season.detail")
                .frame(minHeight: 44)
            }

            if isSeasonCardCollapsed == false {
                HStack(spacing: 8) {
                    seasonMetricPill(
                        title: "기여",
                        value: "\(summary.contributionCount)회",
                        color: Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A8A, alpha: 0.24)
                    )
                    seasonMetricPill(
                        title: "Shield",
                        value: "\(summary.weatherShieldApplyCount)회",
                        color: Color.appDynamicHex(light: 0xDCFCE7, dark: 0x14532D, alpha: 0.34)
                    )
                    seasonMetricPill(
                        title: "주차",
                        value: summary.weekKey.isEmpty ? "-" : summary.weekKey,
                        color: Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.34)
                    )
                }
            }
        }
        .padding(16)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "시즌 점수 \(Int(summary.score.rounded()))점, 랭크 \(summary.rankTier.title), 보호 \(summary.weatherShieldApplyCount)회, 남은 시간 \(viewModel.seasonRemainingTimeText)"
        )
    }

    private func seasonMetricPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(Color.appTextDarkGray)
            Text(value)
                .font(.appFont(for: .SemiBold, size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(color)
        .cornerRadius(8)
    }

    private func animatedSeasonGauge(progress: Double) -> some View {
        let clampedProgress = min(1.0, max(0.0, progress))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appTextLightGray.opacity(0.24))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appGreen.opacity(0.75), Color.appYellow.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * clampedProgress)
                    .overlay(alignment: .leading) {
                        if isSeasonMotionReduced == false && clampedProgress > 0 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.34),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 120)
                                .offset(x: seasonGaugeWaveOffset)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
    }

    private func seasonShieldBadge(active: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Color.appTextLightGray.opacity(0.5), lineWidth: 1)
                .frame(width: 28, height: 28)
            if active {
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(seasonShieldRotation))
            }
            Text("S")
                .font(.appFont(for: .SemiBold, size: 11))
        }
    }

    private func multiplierDescription(_ multiplier: Double) -> String {
        let deltaPercent = Int(((multiplier - 1.0) * 100).rounded())
        if deltaPercent == 0 {
            return "기본"
        }
        if deltaPercent > 0 {
            return "+\(deltaPercent)%"
        }
        return "\(deltaPercent)%"
    }

    private func questProgressValue(for mission: IndoorMissionCardModel) -> Double {
        animatedQuestProgress[mission.id] ?? mission.progress.progressRatio
    }

    private func missionIsClaimable(_ mission: IndoorMissionCardModel) -> Bool {
        mission.progress.actionCount >= mission.minimumActionCount && mission.progress.isCompleted == false
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

    @ViewBuilder
    private func questCompletionOverlay(payload: QuestCompletionPresentation) -> some View {
        VStack {
            Spacer().frame(height: 120)
            VStack(spacing: 8) {
                Text("퀘스트 완료")
                    .font(.appFont(for: .SemiBold, size: 16))
                Text(payload.missionTitle)
                    .font(.appFont(for: .SemiBold, size: 14))
                    .multilineTextAlignment(.center)
                Text("+\(payload.rewardPoint)pt 수령 완료")
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appYellow, lineWidth: 1.0)
            )
            .scaleEffect(questCompletionPop ? 1.0 : 0.86)
            .opacity(questCompletionPop ? 1.0 : 0.0)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(questCompletionPop ? 0.18 : 0.0))
        .allowsHitTesting(false)
    }

    private func seasonResultOverlay(payload: SeasonResultPresentation) -> some View {
        let rewardStatus = viewModel.seasonRewardStatus(for: payload.weekKey)
        return VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("시즌 결과")
                            .font(.appFont(for: .SemiBold, size: 18))
                        Text("\(payload.weekKey) 리포트")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    Spacer()
                    Button("닫기") {
                        dismissSeasonResultModal()
                    }
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
                }
                seasonResultRow(
                    title: "최종 랭크",
                    value: payload.rankTier.title,
                    isVisible: seasonResultRevealRank
                )
                seasonResultRow(
                    title: "기여 횟수",
                    value: "\(payload.contributionCount)회",
                    isVisible: seasonResultRevealContribution
                )
                seasonResultRow(
                    title: "Shield 적용",
                    value: "\(payload.shieldApplyCount)회",
                    isVisible: seasonResultRevealShield
                )
                HStack {
                    Text("보상 상태")
                        .font(.appFont(for: .Light, size: 12))
                        .foregroundStyle(Color.appTextDarkGray)
                    Spacer()
                    Text(seasonRewardStatusText(rewardStatus))
                        .font(.appFont(for: .SemiBold, size: 13))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(seasonRewardStatusColor(rewardStatus).opacity(0.18))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.appYellowPale.opacity(0.45))
                .cornerRadius(8)
                if rewardStatus != .claimed {
                    HStack {
                        Spacer()
                        Button(rewardStatus == .failed ? "재수령" : "수령 처리") {
                            viewModel.retrySeasonRewardClaim(
                                for: payload.weekKey,
                                cloudSyncAllowed: authFlow.canAccess(.cloudSync)
                            )
                        }
                        .font(.appFont(for: .SemiBold, size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appYellow)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appYellow, lineWidth: 1.0)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 72)
            .scaleEffect(seasonResultPop ? 1.0 : 0.9)
            .opacity(seasonResultPop ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(seasonResultPop ? 0.22 : 0.0))
    }

    private var seasonDetailSheet: some View {
        let summary = viewModel.seasonMotionSummary
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("현재 시즌")
                            .font(.appFont(for: .SemiBold, size: 16))
                        Text("주차 \(summary.weekKey.isEmpty ? "-" : summary.weekKey)")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        seasonDetailLine(title: "현재 티어", value: summary.rankTier.title)
                        seasonDetailLine(title: "누적 점수", value: "\(Int(summary.score.rounded()))pt")
                        seasonDetailLine(title: "오늘 증가", value: "+\(summary.todayScoreDelta)pt")
                        seasonDetailLine(title: "기여 횟수", value: "\(summary.contributionCount)회")
                        seasonDetailLine(title: "Shield 적용", value: "\(summary.weatherShieldApplyCount)회")
                        seasonDetailLine(title: "남은 시간", value: viewModel.seasonRemainingTimeText)
                    }
                    .padding(12)
                    .background(Color.appYellowPale.opacity(0.42))
                    .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("랭크 구간")
                            .font(.appFont(for: .SemiBold, size: 13))
                        ForEach(SeasonRankTier.allCases, id: \.rawValue) { tier in
                            HStack {
                                Text(tier.title)
                                    .font(.appFont(for: .Regular, size: 12))
                                Spacer()
                                Text("\(Int(tier.minimumScore))pt+")
                                    .font(.appFont(for: .Light, size: 12))
                                    .foregroundStyle(Color.appTextDarkGray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(summary.rankTier == tier ? Color.appYellowPale : Color.appTextLightGray.opacity(0.18))
                            .cornerRadius(8)
                        }
                    }

                    Text("점수는 미션 완료/기여 기준으로 누적되며, 결과는 시즌 종료 후 결과 모달에서 다시 확인할 수 있습니다.")
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                }
                .padding(16)
            }
            .navigationTitle("시즌 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        isSeasonDetailPresented = false
                    }
                    .accessibilityIdentifier("home.season.detail.close")
                }
            }
        }
    }

    private func seasonDetailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Text(value)
                .font(.appFont(for: .SemiBold, size: 13))
        }
    }

    private func seasonRewardStatusText(_ status: SeasonRewardClaimStatus) -> String {
        switch status {
        case .pending:
            return "대기"
        case .claimed:
            return "수령 완료"
        case .failed:
            return "실패"
        }
    }

    private func seasonRewardStatusColor(_ status: SeasonRewardClaimStatus) -> Color {
        switch status {
        case .pending:
            return Color.appYellow
        case .claimed:
            return Color.appGreen
        case .failed:
            return Color.appRed
        }
    }

    private func seasonResultRow(title: String, value: String, isVisible: Bool) -> some View {
        HStack {
            Text(title)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Text(value)
                .font(.appFont(for: .SemiBold, size: 15))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(8)
        .offset(y: isVisible ? 0 : 10)
        .opacity(isVisible ? 1.0 : 0.0)
    }

    private var seasonResetTransitionBanner: some View {
        VStack {
            HStack {
                Text("주간 시즌이 리셋되어 새 라운드를 시작했어요.")
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appYellow)
                    .cornerRadius(10)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func animatedQuestProgressBar(mission: IndoorMissionCardModel) -> some View {
        let progress = min(1.0, max(0.0, questProgressValue(for: mission)))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appTextLightGray.opacity(0.28))
                Capsule()
                    .fill(mission.progress.isCompleted ? Color.appGreen : Color.appYellow)
                    .frame(width: proxy.size.width * progress)
                if questProgressPulseMissionId == mission.id, isQuestMotionReduced == false {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: proxy.size.width * progress)
                        .blur(radius: 2.5)
                }
            }
        }
        .frame(height: 8)
        .animation(
            isQuestMotionReduced ? nil : .easeOut(duration: 0.34),
            value: progress
        )
    }

    private func indoorMissionRow(mission: IndoorMissionCardModel) -> some View {
        let claimable = missionIsClaimable(mission)
        let claimed = mission.progress.isCompleted
        let folded = isQuestMotionReduced ? false : (claimable || claimed)
        let claimTitle = claimed ? "수령 완료" : (claimable ? "즉시 수령" : "완료 확인")
        let claimButtonColor = claimed ? Color.appGreen : (claimable ? Color.appYellow : Color.appTextLightGray)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(mission.title)
                    .font(.appFont(for: .SemiBold, size: 14))
                if mission.isExtension {
                    Text("연장 슬롯")
                        .font(.appFont(for: .SemiBold, size: 10))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.appYellowPale)
                        .cornerRadius(6)
                }
                Spacer()
                Text("보상 \(mission.rewardPoint)pt")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            if folded == false {
                Text(mission.description)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                if mission.isExtension {
                    Text("전일 미션 연장 · 보상 70% · 시즌 점수/연속 보상 제외")
                        .font(.appFont(for: .Light, size: 10))
                        .foregroundStyle(Color.appTextDarkGray)
                }
            }
            animatedQuestProgressBar(mission: mission)
            Text("행동량 \(mission.progress.actionCount)/\(mission.minimumActionCount)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 8) {
                Button("행동 +1") {
                    viewModel.recordIndoorMissionAction(mission.id)
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
                .disabled(claimed)

                Button(claimTitle) {
                    viewModel.finalizeIndoorMission(mission.id)
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(claimButtonColor)
                .cornerRadius(8)
                .scaleEffect(questClaimPulseMissionId == mission.id ? 1.06 : 1.0)
                .animation(
                    isQuestMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.74),
                    value: questClaimPulseMissionId == mission.id
                )
            }
        }
        .padding(10)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(10)
        .scaleEffect(folded ? 0.985 : 1.0)
        .animation(
            isQuestMotionReduced ? nil : .easeInOut(duration: 0.22),
            value: folded
        )
        .onAppear {
            if animatedQuestProgress[mission.id] == nil {
                animatedQuestProgress[mission.id] = mission.progress.progressRatio
            }
        }
        .onChange(of: mission.progress.progressRatio) { _, next in
            if isQuestMotionReduced {
                animatedQuestProgress[mission.id] = next
            } else {
                withAnimation(.easeOut(duration: 0.34)) {
                    animatedQuestProgress[mission.id] = next
                }
            }
        }
        .accessibilityIdentifier("home.quest.row.\(mission.id)")
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
