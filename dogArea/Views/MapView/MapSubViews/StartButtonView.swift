//
//  StartButtonView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import SwiftUI
struct StartButtonView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var myAlert: CustomAlertViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @Binding var isModalPresented: Bool
    @Binding var endWalkingViewPresented: Bool
    @State var isMeter: Bool = true
    var body: some View {
        HStack {
            if viewModel.isWalking {
                Spacer()
                Text("영역 넓이\n" + viewModel.calculatedAreaString(isPyong: !isMeter))
                    .frame(width: 100)
                    .multilineTextAlignment(.center)
                    .font(.appFont(for: .Light, size: 18))
                    .onTapGesture {isMeter.toggle()}
                Spacer()
            }
            VStack(spacing: 6) {
                if !viewModel.isWalking && viewModel.availablePets.count > 1 {
                    Text("대상: \(viewModel.selectedPetName) · 1탭 변경")
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(6)
                        .onTapGesture {
                            viewModel.cycleSelectedPetForWalkStart()
                        }
                }
                ZStack {
                    Button(action: handleStartStopTapped) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isWalking ? Color.appRed : Color.appInk)
                                .frame(width: 68, height: 68)
                                .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
                            Image(systemName: viewModel.isWalking ? "stop.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 68, height: 68)
                    .contentShape(Circle())
                    .accessibilityHidden(true)

                    Button(action: handleStartStopTapped) {
                        Text(viewModel.isWalking ? "산책 종료" : "산책 시작")
                            .font(.system(size: 1, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.01))
                            .frame(width: 68, height: 68)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.01))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map.walk.primaryAction")
                    .accessibilityLabel(viewModel.isWalking ? "산책 종료" : "산책 시작")
                    .accessibilityHint("산책 기록을 시작하거나 종료합니다.")
                }
            }
            if viewModel.isWalking {
                Spacer()
                Text("\(viewModel.currentWalkingPetName)\n" + viewModel.time.simpleWalkingTimeInterval)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
                    .font(.appFont(for: .Light, size: 18))
                Spacer()
            }
        }.frame(width: screenSize.width, height: screenSize.height * 0.1)
            .background(viewModel.isWalking ? Color.white : Color.clear)
            .animation(.easeIn, value: viewModel.isWalking)
    }

    /// 산책 시작/종료 버튼 탭 이벤트를 처리합니다.
    private func handleStartStopTapped() {
        if !viewModel.isWalking {
            guard authFlow.requestAccess(feature: .walkWrite) else {
                return
            }
            viewModel.prepareWalkPetSelectionSuggestion()
            guard viewModel.hasSelectedPet else {
                myAlert.callAlert(
                    type: .custom(
                        .simpleAlert(title: "반려견 선택 필요", message: "산책 시작 전에 반려견을 선택해주세요.", isOneButton: true),
                        {},
                        {}
                    )
                )
                return
            }
            if viewModel.walkStartCountdownEnabled {
                isModalPresented = true
            } else {
                viewModel.startWalkNow()
            }
        } else {
            myAlert.callAlert(
                type: .customThreeButton(
                    .threeChoiceAlert(
                        title: "산책 종료",
                        message: "현재 산책 기록을 어떻게 처리할까요?",
                        first: "저장하고 종료",
                        second: "계속 걷기",
                        third: "기록 폐기"
                    ),
                    {
                        viewModel.timerStop()
                        if viewModel.polygon.locations.count > 2 {
                            viewModel.makePolygon()
                            endWalkingViewPresented.toggle()
                        } else {
                            viewModel.endWalk()
                        }
                    },
                    {},
                    {
                        viewModel.discardCurrentWalk()
                    }
                )
            )
        }
    }
}
