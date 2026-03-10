//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI

private enum WatchMainSurface: Hashable {
    case control
    case info
}

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()
    @State private var isQueueStatusPresented = false
    @State private var isWalkEndDecisionPresented = false
    @State private var selectedSurface: WatchMainSurface = .control
    @State private var hasInitializedLandingSurface = false

    var body: some View {
        TabView(selection: $selectedSurface) {
            VStack(alignment: .leading, spacing: 10) {
                WatchMainStatusSummaryView(
                    isWalking: viewModel.isWalking,
                    isReachable: viewModel.isReachable,
                    walkingTime: viewModel.walkingTime,
                    walkingArea: viewModel.walkingArea,
                    pointCount: viewModel.currentPointCount,
                    petName: viewModel.currentWalkingPetName
                )

                if let feedbackBanner = viewModel.feedbackBanner {
                    WatchActionBannerView(banner: feedbackBanner)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .tag(WatchMainSurface.control)
            .accessibilityIdentifier("screen.watch.main.control")

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let feedbackBanner = viewModel.feedbackBanner {
                        WatchActionBannerView(banner: feedbackBanner)
                    }

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
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if selectedSurface == .control {
                WatchPrimaryActionDockView(
                    isWalking: viewModel.isWalking,
                    startWalkPresentation: viewModel.controlPresentation(for: .startWalk),
                    addPointPresentation: viewModel.controlPresentation(for: .addPoint),
                    endWalkPresentation: viewModel.controlPresentation(for: .endWalk),
                    onStartWalk: { viewModel.handleActionTap(.startWalk) },
                    onAddPoint: { viewModel.handleActionTap(.addPoint) },
                    onEndWalk: { isWalkEndDecisionPresented = true }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
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
}

#Preview {
    ContentView()
}
