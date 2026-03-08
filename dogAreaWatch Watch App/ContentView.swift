//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()
    @State private var isQueueStatusPresented = false
    @State private var isWalkEndDecisionPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                WatchMainStatusSummaryView(
                    isWalking: viewModel.isWalking,
                    isReachable: viewModel.isReachable,
                    walkingTime: viewModel.walkingTime,
                    walkingArea: viewModel.walkingArea
                )

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
        .safeAreaInset(edge: .bottom, spacing: 8) {
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
        .accessibilityIdentifier("screen.watch.main.scroll")
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
    }
}

#Preview {
    ContentView()
}
