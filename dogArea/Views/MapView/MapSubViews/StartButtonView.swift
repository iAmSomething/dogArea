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
                Image(viewModel.isWalking ? .stopIcon : .startIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .onTapGesture {
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
                        }
                        else {
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
}
