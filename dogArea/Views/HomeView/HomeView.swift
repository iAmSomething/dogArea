//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    var body: some View {
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
        }.padding(.top,20)
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
            Text(board.riskLevel == .clear
                 ? "연장 슬롯 상태를 확인할 수 있어요."
                 : "악천후 단계에 맞춰 실외 미션 일부를 실내 미션으로 치환했어요.")
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
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

    private func indoorMissionRow(mission: IndoorMissionCardModel) -> some View {
        VStack(alignment: .leading, spacing: 7) {
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
            Text(mission.description)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            if mission.isExtension {
                Text("전일 미션 연장 · 보상 70% · 시즌 점수/연속 보상 제외")
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            ProgressView(value: mission.progress.progressRatio)
                .tint(mission.progress.isCompleted ? Color.appGreen : Color.appYellow)
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

                Button(mission.progress.isCompleted ? "완료됨" : "완료 확인") {
                    viewModel.finalizeIndoorMission(mission.id)
                }
                .disabled(mission.progress.isCompleted)
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(mission.progress.isCompleted ? Color.appTextLightGray : Color.appYellow)
                .cornerRadius(8)
            }
        }
        .padding(10)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(10)
    }
}

#Preview {
    HomeView()
}
