import SwiftUI

struct AreaDetailView: View {
    @ObservedObject var viewModel: AreaDetailViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    AreaDetailHeaderSectionView(
                        title: viewModel.title,
                        subtitle: viewModel.subtitle,
                        badgeText: viewModel.selectedPetBadgeText,
                        sourceText: viewModel.sourceText,
                        freshnessText: viewModel.freshnessText,
                        sourceDescriptionText: viewModel.sourceDescriptionText
                    )
                    AreaDetailCatalogSnapshotSectionView(
                        metrics: viewModel.catalogMetrics,
                        currentBandTitle: viewModel.currentBandTitle,
                        currentBandBody: viewModel.currentBandBody
                    )
                    AreaDetailSummaryCardView(
                        currentAreaText: viewModel.currentAreaText,
                        currentAreaName: viewModel.currentAreaName,
                        nextGoalNameText: viewModel.nextGoalNameText,
                        nextGoalAreaText: viewModel.nextGoalAreaText,
                        remainingAreaText: viewModel.remainingAreaText,
                        featuredSummaryText: viewModel.featuredSummaryText,
                        coverageSummaryText: viewModel.coverageSummaryText
                    )
                    AreaDetailReferenceCatalogSectionView(
                        sections: viewModel.referenceSections,
                        sourceText: viewModel.sourceText
                    )
                    AreaDetailRecentConquestSectionView(items: viewModel.recentAreas)
                    AreaDetailActionHintCardView(
                        title: viewModel.actionTitle,
                        bodyText: viewModel.actionBody
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }

            Color.black
                .opacity(0.01)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityIdentifier("screen.areaDetail")
        }
        .safeAreaPadding(.top, 8)
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("비교군 카탈로그")
        .appTabBarVisibility(.hidden)
        .onAppear { viewModel.refresh() }
        .refreshable {
            viewModel.refresh()
        }
    }
}
