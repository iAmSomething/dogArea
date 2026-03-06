import SwiftUI

struct TerritoryGoalView: View {
    @ObservedObject var viewModel: TerritoryGoalViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                TerritoryGoalHeaderSectionView(
                    eyebrowText: viewModel.headerEyebrowText,
                    title: viewModel.title,
                    subtitle: viewModel.subtitle,
                    badgeText: viewModel.selectedPetBadgeText,
                    goalMeaningText: viewModel.goalMeaningText,
                    sourceText: viewModel.areaSourceText,
                    freshnessText: viewModel.freshnessText
                )
                TerritoryGoalOverviewCardView(
                    currentAreaText: viewModel.currentAreaText,
                    currentAreaName: viewModel.homeViewModel.myArea.areaName,
                    nextGoalNameText: viewModel.nextGoalNameText,
                    nextGoalAreaText: viewModel.nextGoalAreaText,
                    remainingAreaText: viewModel.remainingAreaText,
                    progressRatio: viewModel.progressRatio,
                    progressPercentText: viewModel.progressPercentText,
                    progressMessageText: viewModel.progressMessageText,
                    compareDestination: AreaDetailView(viewModel: AreaDetailViewModel(homeViewModel: viewModel.homeViewModel))
                )
                TerritoryGoalInsightSectionView(
                    items: [
                        .init(
                            id: "recent",
                            title: "최근 정복",
                            value: "\(viewModel.recentAreas.count)개",
                            detail: viewModel.recentInsightDetailText,
                            accentColor: Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC)
                        ),
                        .init(
                            id: "remaining",
                            title: "다음 목표까지",
                            value: viewModel.remainingAreaText,
                            detail: viewModel.progressPercentText + " 진행 중",
                            accentColor: Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15)
                        ),
                        .init(
                            id: "source",
                            title: "기준 출처",
                            value: viewModel.areaSourceText,
                            detail: viewModel.sourceInsightDetailText,
                            accentColor: Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0)
                        ),
                        .init(
                            id: "freshness",
                            title: "데이터 신선도",
                            value: viewModel.freshnessText,
                            detail: viewModel.freshnessInsightDetailText,
                            accentColor: Color.appGreen
                        )
                    ]
                )
                TerritoryGoalRecentListSectionView(items: viewModel.recentAreas)
                TerritoryGoalActionHintCardView(
                    title: viewModel.actionTitle,
                    bodyText: viewModel.actionBodyText,
                    isFallbackSource: viewModel.isFallbackSource
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .safeAreaPadding(.top, 8)
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("영역 목표 상세")
        .accessibilityIdentifier("screen.territoryGoal")
        .appTabBarVisibility(.hidden)
        .onAppear { viewModel.refresh() }
        .refreshable {
            viewModel.refresh()
        }
    }
}
