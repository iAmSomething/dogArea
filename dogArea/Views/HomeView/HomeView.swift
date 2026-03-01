//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
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

    private var isQuestMotionReduced: Bool {
        accessibilityReduceMotion
    }
    private var isSeasonMotionReduced: Bool {
        accessibilityReduceMotion || isLowPowerModeEnabled
    }
    var body: some View {
        ZStack {
            ScrollView {
                VStack{
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("산책 달력")
                                .font(.appFont(for: .SemiBold, size: 40))
                            Text("산책한 날을 표시해보아요!")
                                .font(.appFont(for: .Light, size: 15))
                                .foregroundStyle(Color.appTextDarkGray)
                        }.padding()
                        Spacer()
                    }
                    if let report = viewModel.guestDataUpgradeReport {
                        guestDataUpgradeCard(report: report)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    if let message = viewModel.aggregationStatusMessage {
                        Text(message)
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appYellowPale)
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                    }
                    if let message = viewModel.indoorMissionStatusMessage {
                        Text(message)
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appYellowPale)
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                    }
                    if let message = viewModel.seasonCatchupBuffStatusMessage {
                        Text(message)
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.seasonCatchupBuffStatusWarning ? Color.appYellowPale : Color.appGreen.opacity(0.45))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                    }
                    if viewModel.pets.isEmpty == false {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.pets, id: \.petId) { pet in
                                    Text(pet.petName)
                                        .font(.appFont(for: .Regular, size: 13))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewModel.selectedPetId == pet.petId ? Color.appYellow : Color.appYellowPale
                                        )
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            viewModel.selectPet(pet.petId)
                                        }
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                    CalenderView(clickedDates: viewModel.walkedDates())
                    UnderLine()
                    if viewModel.pets.isEmpty == false {
                        selectedPetContextBanner
                        if viewModel.shouldShowSelectedPetEmptyState {
                            selectedPetEmptyStateCard
                        }
                    }
                    HStack {
                        VStack{
                            HStack {
                                Text("이번 주 산책한 영역")
                                    .font(.appFont(for: .SemiBold, size: 20))
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            Text("\(viewModel.walkedAreaforWeek().calculatedAreaString)")
                                .font(.appFont(for: .Light, size: 15))
                        }.frame(maxWidth: .infinity)
                            .padding(.leading)
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 0.6)
                            .frame(maxHeight: .infinity)
                            .background(Color(red: 0.19, green: 0.19, blue: 0.19))
                        VStack {
                            HStack {
                                Text("이번 주 산책 횟수")
                                    .font(.appFont(for: .SemiBold, size: 20))
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            Text("\(viewModel.walkedCountforWeek()) 회")
                                .font(.appFont(for: .Light, size: 15))

                        }.frame(maxWidth: .infinity)
                            .padding(.trailing)
                    }
                    seasonMotionCard(summary: viewModel.seasonMotionSummary)
                    weatherMissionStatusCard(summary: viewModel.weatherMissionStatusSummary)
                    if let shieldDaily = viewModel.weatherShieldDailySummary {
                        weatherShieldSummaryCard(summary: shieldDaily)
                    }
                    if viewModel.indoorMissionBoard.shouldDisplayCard {
                        indoorMissionCard(board: viewModel.indoorMissionBoard)
                        UnderLine()
                    }
                    if let contribution = viewModel.boundarySplitContribution {
                        dayBoundarySplitCard(contribution: contribution)
                    }
                    HStack {
                        let petNameWithYi = viewModel.selectedPetNameWithYi
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(petNameWithYi)의 영역")
                                .font(.appFont(for: .SemiBold, size: 40))
                            Text("\(petNameWithYi)가 정복한 영역을 확인해보세요!")
                                .font(.appFont(for: .Light, size: 15))
                                .foregroundStyle(Color.appTextDarkGray)
                        }.padding()
                        Spacer()
                    }
                    goalTrackerCard
                    UnderLine()
                    recentConqueredCard
                    UnderLine()
                    
                    Spacer()
    //#if DEBUG
    //                Button("영역 올리기") {
    //                    viewModel.makeitup()
    //                }
    //                Button("초기화") {
    //                    viewModel.reset()
    //                }
    //#endif
                }
            }.refreshable {
                viewModel.fetchData()
            }.onAppear{
                viewModel.reloadUserInfo()
                viewModel.fetchData()
                seasonAnimatedProgress = viewModel.seasonMotionSummary.progress
                if viewModel.seasonMotionSummary.weatherShieldActive {
                    startSeasonShieldRingAnimationIfNeeded()
                }
            }.onChange(of: viewModel.aggregationStatusMessage) { newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    viewModel.clearAggregationStatusMessage()
                }
            }.onChange(of: viewModel.indoorMissionStatusMessage) { newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    viewModel.clearIndoorMissionStatusMessage()
                }
            }.onChange(of: viewModel.weatherFeedbackResultMessage) { newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    viewModel.clearWeatherFeedbackResultMessage()
                }
            }.onChange(of: viewModel.questMotionEvent) { event in
                handleQuestMotionEvent(event)
            }.onChange(of: viewModel.questCompletionPresentation) { payload in
                guard let payload else { return }
                presentQuestCompletionModal(payload)
            }.onChange(of: viewModel.seasonMotionSummary.progress) { progress in
                animateSeasonProgress(to: progress)
            }.onChange(of: viewModel.seasonMotionSummary.weatherShieldActive) { active in
                if active {
                    startSeasonShieldRingAnimationIfNeeded()
                } else {
                    seasonShieldRotation = 0
                }
            }.onChange(of: viewModel.seasonMotionEvent) { event in
                handleSeasonMotionEvent(event)
            }.onChange(of: viewModel.seasonResultPresentation) { payload in
                guard let payload else { return }
                presentSeasonResultModal(payload)
            }.onChange(of: viewModel.seasonResetTransitionToken) { token in
                guard token != nil else { return }
                presentSeasonResetTransitionBanner()
            }.onChange(of: isLowPowerModeEnabled) { enabled in
                if enabled {
                    seasonShieldRotation = 0
                } else if viewModel.seasonMotionSummary.weatherShieldActive {
                    startSeasonShieldRingAnimationIfNeeded()
                }
            }.onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }.padding(.top,20)

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
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.pets.isEmpty == false {
                selectedPetContextPill
            }
            Text("비교군 소스: \(viewModel.areaReferenceSourceLabel) · featured \(viewModel.featuredAreaCount)개 우선")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(alignment: .top) {
                Text("영역 목표 트래커")
                    .font(.appFont(for: .SemiBold, size: 20))
                Spacer()
                NavigationLink(destination: AreaDetailView(viewModel: viewModel)) {
                    Text("비교군 더보기 >")
                        .font(.appFont(for: .Light, size: 13))
                        .foregroundStyle(Color.appTextDarkGray)
                }
            }

            goalMetricRow(
                title: "현재 영역",
                value: viewModel.myArea.area.calculatedAreaString,
                detail: viewModel.myArea.areaName
            )

            goalMetricRow(
                title: "다음 목표",
                value: viewModel.nextGoalArea?.areaName ?? "더 정복할 곳이 없어요!",
                detail: viewModel.nextGoalArea?.area.calculatedAreaString ?? "목표 완료"
            )

            goalMetricRow(
                title: "남은 면적",
                value: viewModel.remainingAreaToGoal.calculatedAreaString,
                detail: viewModel.nextGoalArea == nil ? "다음 목표 없음" : "목표까지 남은 면적"
            )

            ProgressView(value: viewModel.goalProgressRatio)
                .tint(Color.appGreen)
                .accessibilityLabel("목표 진행률")
                .accessibilityValue("\(Int(viewModel.goalProgressRatio * 100)) 퍼센트")
        }
        .padding(14)
        .background(Color.appPeach)
        .cornerRadius(12)
        .shadow(radius: 3)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "영역 목표 트래커. 현재 영역 \(viewModel.myArea.area.calculatedAreaString), 다음 목표 \(viewModel.nextGoalArea?.areaName ?? "없음"), 남은 면적 \(viewModel.remainingAreaToGoal.calculatedAreaString)"
        )
    }

    private var selectedPetContextPillText: String {
        viewModel.isShowingAllRecordsOverride
            ? "전체 기록 보기 모드 · 선택 반려견 \(viewModel.selectedPetName)"
            : "선택 반려견 기준 · \(viewModel.selectedPetName)"
    }

    private var selectedPetContextPill: some View {
        Text(selectedPetContextPillText)
            .font(.appFont(for: .SemiBold, size: 11))
            .foregroundStyle(Color.appTextDarkGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appYellowPale)
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(selectedPetContextPillText)
    }

    private var selectedPetContextBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            selectedPetContextPill
            if viewModel.isShowingAllRecordsOverride {
                Button("기준으로 돌아가기") {
                    viewModel.showSelectedPetRecords()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)
                .accessibilityLabel("선택 반려견 기준으로 돌아가기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var selectedPetEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.selectedPetName) 기록이 아직 없어요")
                .font(.appFont(for: .SemiBold, size: 14))
            Text("필터를 유지하면 0건으로 보일 수 있어요. 전체 기록으로 전환해 계속 탐색해보세요.")
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Button("전체 기록 보기") {
                viewModel.showAllRecordsTemporarily()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.appYellow)
            .cornerRadius(8)
            .accessibilityLabel("전체 기록 보기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextDarkGray, lineWidth: 0.25)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func goalMetricRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(Color.appTextDarkGray)
                .frame(width: 66, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.appFont(for: .SemiBold, size: 17))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value) \(detail)")
    }

    private var recentConqueredCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 정복")
                .font(.appFont(for: .SemiBold, size: 20))
                .padding(.horizontal, 4)
            HStack(alignment: .bottom) {
                if let area = viewModel.nearlistLess() {
                    Text(area.areaName)
                        .font(.appFont(for: .Bold, size: 32))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("산책을 통해 영역을 넓혀봐요!")
                        .font(.appFont(for: .Medium, size: 20))
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.appPinkYello)
        .cornerRadius(10)
        .shadow(radius: 3)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("최근 정복 영역 \(viewModel.nearlistLess()?.areaName ?? "없음")")
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
                Text(board.riskLevel == .clear ? "데일리 미션 상태" : "악천후 실내 대체 미션")
                    .font(.appFont(for: .SemiBold, size: 18))
                Spacer()
                if board.riskLevel != .clear {
                    Text(board.riskLevel.displayTitle)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appYellow)
                        .cornerRadius(8)
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("시즌 게이지")
                        .font(.appFont(for: .SemiBold, size: 18))
                    Text("주간 점수 \(Int(summary.score.rounded())) / \(Int(summary.targetScore.rounded()))")
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                }
                Spacer()
                seasonShieldBadge(active: summary.weatherShieldActive)
                Text(summary.rankTier.title)
                    .font(.appFont(for: .SemiBold, size: 12))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
            }

            animatedSeasonGauge(progress: seasonAnimatedProgress)
                .frame(height: 12)

            HStack(spacing: 8) {
                seasonMetricPill(
                    title: "기여",
                    value: "\(summary.contributionCount)회",
                    color: Color.appYellowPale
                )
                seasonMetricPill(
                    title: "Shield",
                    value: "\(summary.weatherShieldApplyCount)회",
                    color: Color.appGreen.opacity(0.22)
                )
                seasonMetricPill(
                    title: "주차",
                    value: summary.weekKey.isEmpty ? "-" : summary.weekKey,
                    color: Color.appPinkYello.opacity(0.44)
                )
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
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "시즌 점수 \(Int(summary.score.rounded()))점, 랭크 \(summary.rankTier.title), 보호 \(summary.weatherShieldApplyCount)회"
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
        VStack(spacing: 0) {
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
        .onChange(of: mission.progress.progressRatio) { next in
            if isQuestMotionReduced {
                animatedQuestProgress[mission.id] = next
            } else {
                withAnimation(.easeOut(duration: 0.34)) {
                    animatedQuestProgress[mission.id] = next
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
