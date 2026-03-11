//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI

enum WatchMainSurface: Hashable {
    case control
    case info
}

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()
    @State private var isQueueStatusPresented = false
    @State private var isWalkEndDecisionPresented = false
    @State private var selectedSurface: WatchMainSurface = .control
    @State private var hasInitializedLandingSurface = false
    @State private var hasVisitedInfoSurface = false

    var body: some View {
        TabView(selection: $selectedSurface) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    WatchControlSurfaceView(
                        isWalking: viewModel.isWalking,
                        isReachable: viewModel.isReachable,
                        walkingTime: viewModel.walkingTime,
                        walkingArea: viewModel.walkingArea,
                        pointCount: viewModel.currentPointCount,
                        petContext: viewModel.petContext,
                        feedbackBanner: viewModel.feedbackBanner,
                        startWalkPresentation: viewModel.controlPresentation(for: .startWalk),
                        addPointPresentation: viewModel.controlPresentation(for: .addPoint),
                        endWalkPresentation: viewModel.controlPresentation(for: .endWalk),
                        onStartWalk: { viewModel.handleActionTap(.startWalk) },
                        onAddPoint: { viewModel.handleActionTap(.addPoint) },
                        onEndWalk: { isWalkEndDecisionPresented = true }
                    )

                    if shouldShowPagingHint {
                        WatchSurfacePagingHintView(
                            currentSurface: .control,
                            targetSurfaceLabel: "정보 화면"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .tag(WatchMainSurface.control)
            .accessibilityIdentifier("screen.watch.main.control")

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    WatchSelectedPetContextCardView(
                        petContext: viewModel.petContext,
                        isReachable: viewModel.isReachable,
                        onRefresh: { viewModel.refreshPetContext() }
                    )

                    WatchOfflineQueueStatusCardView(
                        queueStatus: viewModel.queueStatus,
                        onOpenDetail: { isQueueStatusPresented = true },
                        onManualSync: { viewModel.handleManualQueueResync() }
                    )

                    if shouldShowPagingHint {
                        WatchSurfacePagingHintView(
                            currentSurface: .info,
                            targetSurfaceLabel: "조작 화면"
                        )
                    }

                    Color.clear
                        .frame(height: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .tag(WatchMainSurface.info)
            .accessibilityIdentifier("screen.watch.main.info")
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .accessibilityIdentifier("screen.watch.main.pager")
        .sheet(isPresented: $isQueueStatusPresented) {
            WatchOfflineQueueStatusSheetView(
                queueStatus: viewModel.queueStatus,
                onManualSync: { viewModel.handleManualQueueResync() }
            )
        }
        .sheet(isPresented: $isWalkEndDecisionPresented) {
            WatchWalkEndDecisionSheetView(
                elapsedTime: viewModel.walkingTime,
                area: viewModel.walkingArea,
                pointCount: viewModel.currentPointCount,
                petName: viewModel.currentWalkingPetName,
                isReachable: viewModel.isReachable,
                onSaveAndEnd: {
                    isWalkEndDecisionPresented = false
                    viewModel.handleWalkEndDecision(.saveAndEnd)
                },
                onContinueWalking: {
                    isWalkEndDecisionPresented = false
                    viewModel.handleWalkEndDecision(.continueWalking)
                },
                onDiscard: {
                    isWalkEndDecisionPresented = false
                    viewModel.handleWalkEndDecision(.discardRecord)
                }
            )
        }
        .sheet(
            item: Binding(
                get: { viewModel.walkCompletionSummary },
                set: { summary in
                    if summary == nil {
                        viewModel.dismissWalkCompletionSummary()
                    }
                }
            )
        ) { summary in
            WatchWalkCompletionSummarySheetView(
                summary: summary,
                onDismiss: { viewModel.dismissWalkCompletionSummary() }
            )
        }
        .onAppear {
            syncLandingSurface(isWalking: viewModel.isWalking)
        }
        .onChange(of: viewModel.isWalking) { _, isWalking in
            syncLandingSurface(isWalking: isWalking)
        }
        .onChange(of: selectedSurface) { _, surface in
            if surface == .info {
                hasVisitedInfoSurface = true
            }
        }
    }

    /// 현재 산책 진행 여부에 맞춰 watch 메인 landing surface를 조정합니다.
    /// - Parameter isWalking: 현재 산책이 진행 중이면 `true`입니다.
    private func syncLandingSurface(isWalking: Bool) {
        if hasInitializedLandingSurface == false {
            selectedSurface = .control
            hasInitializedLandingSurface = true
            return
        }
        if isWalking {
            selectedSurface = .control
        }
    }

    /// 사용자가 정보 화면을 아직 확인하지 않았다면 페이지 이동 affordance를 노출합니다.
    /// - Returns: 정보 화면 첫 발견 전이면 `true`입니다.
    private var shouldShowPagingHint: Bool {
        hasVisitedInfoSurface == false
    }
}

#Preview {
    ContentView()
}
