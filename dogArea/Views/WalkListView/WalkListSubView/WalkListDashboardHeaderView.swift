import SwiftUI

struct WalkListDashboardHeaderView: View {
    let overview: WalkListOverviewModel
    let calendar: WalkListCalendarPresentationModel
    let pets: [PetInfo]
    let selectedPetId: String
    let onSelectPet: (String) -> Void
    let onRestoreSelected: () -> Void
    let onPreviousCalendarMonth: () -> Void
    let onNextCalendarMonth: () -> Void
    let onSelectCalendarDate: (Date) -> Void
    let onClearCalendarSelection: () -> Void

    private var headerTitle: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.WalkListHeaderLongSubtitle") {
            return "산책 기록과 월별 흐름"
        }
        return overview.title
    }

    private var headerSubtitle: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.WalkListHeaderLongSubtitle") {
            return "선택한 반려견 기준 기록, 달력 문맥, 최근 요약을 한 번에 훑고 바로 원하는 날짜 기록으로 이동해보세요"
        }
        return overview.subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TitleTextView(
                title: headerTitle,
                subTitle: headerSubtitle,
                accessibilityIdentifierPrefix: "walklist.header"
            )
            .accessibilityElement(children: .contain)

            WalkListPrimaryLoopSummaryCardView(
                badgeText: overview.primaryLoopBadge,
                title: overview.primaryLoopTitle,
                message: overview.primaryLoopMessage,
                secondaryFlowText: overview.primaryLoopSecondaryFlowText
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("최근 요약")
                    .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(overview.metrics) { metric in
                        WalkListMetricTileView(
                            title: metric.title,
                            value: metric.value,
                            detail: metric.detail,
                            accessibilityIdentifier: "walklist.summary.\(metric.id)"
                        )
                    }
                }
            }
            .appCardSurface()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walklist.summary")

            WalkListContextSummaryCardView(
                modeBadge: overview.modeBadge,
                title: overview.contextTitle,
                message: overview.contextMessage,
                helperMessage: overview.helperMessage,
                pets: pets,
                selectedPetId: selectedPetId,
                restoreActionTitle: overview.restoreActionTitle,
                onSelectPet: onSelectPet,
                onRestoreSelected: onRestoreSelected
            )

            WalkListMonthlyCalendarCardView(
                model: calendar,
                onPreviousMonth: onPreviousCalendarMonth,
                onNextMonth: onNextCalendarMonth,
                onSelectDate: onSelectCalendarDate,
                onClearSelection: onClearCalendarSelection
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.header")
    }
}
