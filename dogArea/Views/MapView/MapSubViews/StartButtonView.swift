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
    @State private var isMeter: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            if !viewModel.isWalking && viewModel.availablePets.count > 1 {
                petSelectionHint
            }

            HStack(spacing: 12) {
                if viewModel.isWalking {
                    walkMetricCard(
                        title: "영역 넓이",
                        value: viewModel.calculatedAreaString(isPyong: !isMeter),
                        subtitle: isMeter ? "탭하면 평으로 보기" : "탭하면 ㎡로 보기",
                        emphasized: true,
                        tapAction: {
                            isMeter.toggle()
                        }
                    )
                } else {
                    idleContextCard
                }

                primaryActionButton

                if viewModel.isWalking {
                    walkMetricCard(
                        title: viewModel.currentWalkingPetName,
                        value: viewModel.time.simpleWalkingTimeInterval,
                        subtitle: "산책 진행 중",
                        emphasized: false,
                        tapAction: nil
                    )
                } else {
                    idleHintCard
                }
            }
            .padding(12)
            .frame(maxWidth: 420)
            .mapChromeSurface(emphasized: viewModel.isWalking)
        }
        .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
        .padding(.bottom, 4)
    }

    private var petSelectionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("대상: \(viewModel.selectedPetName) · 탭해서 변경")
                .font(.appFont(for: .SemiBold, size: 11))
                .lineLimit(1)
        }
        .foregroundStyle(MapChromePalette.secondaryText)
        .mapChromePill(.neutral)
        .onTapGesture {
            viewModel.cycleSelectedPetForWalkStart()
        }
        .accessibilityLabel("산책 대상 반려견 \(viewModel.selectedPetName)")
        .accessibilityHint("탭하면 다음 반려견으로 변경합니다.")
    }

    private var idleContextCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.hasSelectedPet ? viewModel.selectedPetName : "반려견 선택 필요")
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(1)
            Text(viewModel.hasSelectedPet ? "현재 반려견 기준으로 산책을 시작합니다." : "산책 시작 전에 반려견을 선택해주세요.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .mapChromePill(.neutral)
    }

    private var idleHintCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("준비 완료")
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(MapChromePalette.primaryText)
            Text("버튼을 누르면 현재 위치 기준으로 기록을 시작합니다.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .mapChromePill(.accent)
    }

    private var primaryActionButton: some View {
        Button(action: handleStartStopTapped) {
            VStack(spacing: 5) {
                Image(systemName: viewModel.isWalking ? "stop.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                Text(viewModel.isWalking ? "종료" : "시작")
                    .font(.appFont(for: .SemiBold, size: 12))
            }
            .foregroundStyle(Color.white)
            .frame(width: 88, height: 88)
            .background(viewModel.isWalking ? Color.appRed : Color.appInk)
            .overlay(
                Circle()
                    .stroke(MapChromePalette.surfaceBorder.opacity(0.9), lineWidth: 1)
            )
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.walk.primaryAction")
        .accessibilityLabel(viewModel.isWalking ? "산책 종료" : "산책 시작")
        .accessibilityHint("산책 기록을 시작하거나 종료합니다.")
    }

    /// 산책 중 메트릭 카드를 렌더링합니다.
    /// - Parameters:
    ///   - title: 카드 상단에 표시할 제목입니다.
    ///   - value: 현재 메트릭의 핵심 값입니다.
    ///   - subtitle: 메트릭 보조 설명 또는 힌트 텍스트입니다.
    ///   - emphasized: 강조 스타일 여부입니다.
    ///   - tapAction: 카드 탭 시 실행할 동작입니다. 없으면 탭을 무시합니다.
    /// - Returns: 산책 메트릭 카드 뷰입니다.
    private func walkMetricCard(
        title: String,
        value: String,
        subtitle: String,
        emphasized: Bool,
        tapAction: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 12))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .mapChromePill(emphasized ? .accent : .neutral)
        .contentShape(RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius, style: .continuous))
        .onTapGesture {
            tapAction?()
        }
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
