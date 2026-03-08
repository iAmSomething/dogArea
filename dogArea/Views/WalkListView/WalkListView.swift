//
//  WalkListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct WalkListView: View {
    @StateObject private var viewModel = WalkListViewModel()
    @EnvironmentObject var authFlow: AuthFlowCoordinator

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                WalkListDashboardHeaderView(
                    overview: viewModel.overviewModel,
                    pets: viewModel.pets,
                    selectedPetId: viewModel.selectedPetId,
                    onSelectPet: viewModel.selectPet(_:),
                    onRestoreSelected: viewModel.showSelectedPetRecords
                )
                .padding(.horizontal, 16)

                if authFlow.isGuestMode {
                    guestUpgradeCard
                        .padding(.horizontal, 16)
                }

                if let stateCardModel = viewModel.stateCardModel {
                    if stateCardModel.accessibilityIdentifier == "walklist.empty.filtered" {
                        filteredEmptyStateCard
                            .padding(.horizontal, 16)
                    } else {
                        emptyHistoryCard
                            .padding(.horizontal, 16)
                    }
                }

                ForEach(viewModel.sectionModels) { section in
                    Section {
                        LazyVStack(spacing: 12) {
                            ForEach(section.items) { item in
                                NavigationLink(value: item.walkData) {
                                    WalkListCell(
                                        walkData: item.walkData,
                                        petName: item.petName
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("walklist.cell")
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        WalkListSectionHeaderView(model: section)
                            .padding(.horizontal, 16)
                            .background(Color.appTabScaffoldBackground)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .refreshable {
            viewModel.fetchModel()
        }
        .appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)
        .onAppear {
            viewModel.fetchModel()
        }
        .navigationDestination(for: WalkDataModel.self) { model in
            WalkListDetailView(model: model)
        }
        .accessibilityIdentifier("screen.walkList.content")
    }

    var guestUpgradeCard: some View {
        let model = WalkListStateCardModel(
            accessibilityIdentifier: "walklist.guest.card",
            badge: "게스트 모드",
            title: "기록은 이 기기에만 저장되고 있어요",
            message: "로그인하면 산책 기록을 백업하고 다른 기기와 동기화할 수 있어요. 지금 보는 목록 구조는 그대로 유지됩니다.",
            footnote: "다음 행동: 로그인 후 기록을 안전하게 보관하세요.",
            primaryActionTitle: "로그인",
            symbolName: "person.crop.circle.badge.plus"
        )
        return WalkListStatusCardView(
            model: model,
            actionAccessibilityIdentifier: "walklist.guest.login"
        ) {
            _ = authFlow.requestAccess(feature: .cloudSync)
        }
    }

    var filteredEmptyStateCard: some View {
        statusCardView(for: viewModel.stateCardModel)
    }

    var emptyHistoryCard: some View {
        statusCardView(for: viewModel.stateCardModel)
    }

    /// 상태 카드 모델에 맞는 액션을 연결한 뷰를 생성합니다.
    /// - Parameter model: 현재 목록 상태를 설명하는 카드 모델입니다.
    /// - Returns: 현재 상태와 액션 wiring이 반영된 카드 뷰입니다.
    @ViewBuilder
    func statusCardView(for model: WalkListStateCardModel?) -> some View {
        if let model {
            WalkListStatusCardView(
                model: model,
                actionAccessibilityIdentifier: model.primaryActionTitle == "전체 기록 보기"
                    ? "walklist.showAllRecords"
                    : nil
            ) {
                if model.primaryActionTitle == "전체 기록 보기" {
                    viewModel.showAllRecordsTemporarily()
                }
            }
        }
    }
}

#Preview {
    WalkListView()
}
