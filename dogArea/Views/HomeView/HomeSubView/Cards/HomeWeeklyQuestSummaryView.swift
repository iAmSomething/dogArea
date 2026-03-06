import SwiftUI

struct HomeWeeklyQuestSummaryView: View {
    let summary: SeasonMotionSummary
    let completedDailyCount: Int
    let totalDailyCount: Int
    let isSeasonMotionReduced: Bool
    let seasonGaugeWaveOffset: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이번 주 점수 \(Int(summary.score.rounded())) / \(Int(summary.targetScore.rounded()))")
                .font(.appFont(for: .SemiBold, size: 13))
            HomeAnimatedSeasonGaugeView(
                progress: summary.progress,
                isMotionReduced: isSeasonMotionReduced,
                waveOffset: seasonGaugeWaveOffset
            )
            .frame(height: 8)
            HStack(spacing: 8) {
                HomeSeasonMetricPillView(
                    title: "주간 기여",
                    value: "\(summary.contributionCount)회",
                    color: Color.appYellowPale
                )
                HomeSeasonMetricPillView(
                    title: "오늘 완료",
                    value: "\(completedDailyCount)/\(totalDailyCount)",
                    color: Color.appGreen.opacity(0.22)
                )
            }
            Text("주간 점수는 미션 완료와 산책 기여로 누적됩니다.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }
    }
}
