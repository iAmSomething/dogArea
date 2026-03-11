//
//  StartButtonView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import SwiftUI

enum MapWalkControlBarMetrics {
    static let idleFootprintBudget: CGFloat = 124
    static let walkingFootprintBudget: CGFloat = 112
    static let surfaceMaxWidth: CGFloat = 404
    static let surfaceHorizontalPadding: CGFloat = 10
    static let idleSurfaceVerticalPadding: CGFloat = 10
    static let walkingSurfaceVerticalPadding: CGFloat = 8
    static let interItemSpacing: CGFloat = 8
    static let surfaceCornerRadius: CGFloat = 18
    static let primaryActionSize: CGFloat = 74
}

struct StartButtonView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var myAlert: CustomAlertViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @Binding var isModalPresented: Bool
    @Binding var endWalkingViewPresented: Bool
    @State private var isMeter: Bool = true
    @State private var isMeaningExpanded: Bool = false
    private let walkStartPresentationService: MapWalkStartPresenting = MapWalkStartPresentationService()

    private var walkStartPresentation: MapWalkStartPresentation {
        walkStartPresentationService.makePresentation(
            hasSelectedPet: viewModel.hasSelectedPet,
            selectedPetName: viewModel.selectedPetName
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            if !viewModel.isWalking && viewModel.availablePets.count > 1 {
                petSelectionHint
            }

            ZStack {
                HStack(spacing: MapWalkControlBarMetrics.interItemSpacing) {
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
                        walkingControlContextCard
                    } else {
                        idleHintCard
                    }
                }
            }
            .padding(.horizontal, MapWalkControlBarMetrics.surfaceHorizontalPadding)
            .padding(
                .vertical,
                viewModel.isWalking
                    ? MapWalkControlBarMetrics.walkingSurfaceVerticalPadding
                    : MapWalkControlBarMetrics.idleSurfaceVerticalPadding
            )
            .frame(maxWidth: MapWalkControlBarMetrics.surfaceMaxWidth)
            .background(viewModel.isWalking ? MapChromePalette.elevatedSurfaceBackground : MapChromePalette.surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: MapWalkControlBarMetrics.surfaceCornerRadius, style: .continuous)
                    .stroke(MapChromePalette.surfaceBorder, lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: MapWalkControlBarMetrics.surfaceCornerRadius, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                ProcessInfo.processInfo.arguments.contains("-UITest.FeatureRegression")
                    ? "map.walk.controlBar"
                    : ""
            )
        }
        .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
        .onChange(of: viewModel.isWalking) { _, isWalking in
            if isWalking {
                isMeaningExpanded = false
            }
        }
    }

    private var petSelectionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("대상: \(viewModel.selectedPetName) · 탭해서 변경")
                .font(.appFont(for: .SemiBold, size: 10))
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
            Text(walkStartPresentation.selectedPetTitle)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(1)
            Text(walkStartPresentation.selectedPetMessage)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .mapChromePill(.neutral)
    }

    private var idleHintCard: some View {
        MapWalkStartMeaningCardView(
            presentation: walkStartPresentation,
            isExpanded: isMeaningExpanded,
            onToggleExpanded: toggleMeaningDisclosure,
            onOpenGuide: viewModel.presentWalkValueGuideFromMapHelp
        )
    }

    private var walkingControlContextCard: some View {
        walkMetricCard(
            title: "포인트 기록",
            value: viewModel.isAutoPointRecordMode ? "자동" : "수동",
            subtitle: walkingControlContextSubtitle,
            emphasized: false,
            tapAction: nil
        )
    }

    private var walkingControlContextSubtitle: String {
        if viewModel.isAddPointLongPressModeEnabled {
            return "길게 눌러 추가"
        }
        return viewModel.isAutoPointRecordMode ? "이동 중 자동 반영" : "버튼으로 직접 추가"
    }

    private var primaryActionButton: some View {
        Button(action: handleStartStopTapped) {
            VStack(spacing: 5) {
                Image(systemName: viewModel.isWalking ? "stop.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                Text(viewModel.isWalking ? "종료" : "시작")
                    .font(.appFont(for: .SemiBold, size: 11))
            }
            .foregroundStyle(Color.white)
            .frame(
                width: MapWalkControlBarMetrics.primaryActionSize,
                height: MapWalkControlBarMetrics.primaryActionSize
            )
            .background(viewModel.isWalking ? Color.appRed : Color.appInk)
            .overlay(
                Circle()
                    .stroke(MapChromePalette.surfaceBorder.opacity(0.9), lineWidth: 1)
            )
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
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
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.appFont(for: .SemiBold, size: 15))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
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
                        title: "산책을 마칠까요?",
                        message: walkStartPresentation.endAlertMessage,
                        first: "저장 후 종료",
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

    /// 시작 전 의미 설명 disclosure 상태를 토글합니다.
    private func toggleMeaningDisclosure() {
        isMeaningExpanded.toggle()
    }
}
