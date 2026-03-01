import SwiftUI

struct HomeWeeklySnapshotSectionView: View {
    let areaText: String
    let areaAccentText: String
    let walkCountText: String
    let walkCountAccentText: String

    var body: some View {
        HStack(spacing: 12) {
            HomeWeeklyMetricCardView(
                title: "이번 주 산책 면적",
                value: areaText,
                accentText: areaAccentText
            )
            HomeWeeklyMetricCardView(
                title: "이번 주 산책 횟수",
                value: walkCountText,
                accentText: walkCountAccentText
            )
        }
    }
}