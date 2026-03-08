import SwiftUI

struct HomeSeasonMotionCardView: View {
    let summary: SeasonMotionSummary
    let animatedProgress: Double
    let isMotionReduced: Bool
    let gaugeWaveOffset: CGFloat
    let shieldRotation: Double
    let remainingTimeText: String
    let onOpenGuide: () -> Void
    let onOpenDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
                        .frame(width: 30, height: 30)
                    Image(systemName: "medal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("시즌 게이지")
                    .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                Text(summary.rankTier.title)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155))
                    .cornerRadius(9)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("시즌 점수 \(Int(summary.score.rounded())) / \(Int(summary.targetScore.rounded()))")
                    .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                Spacer()
                Text("오늘 +\(summary.todayScoreDelta)점")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }

            HomeAnimatedSeasonGaugeView(
                progress: animatedProgress,
                isMotionReduced: isMotionReduced,
                waveOffset: gaugeWaveOffset
            )
            .frame(height: 10)

            HStack(alignment: .center) {
                Text("목표까지 \(max(0, Int((summary.targetScore - summary.score).rounded())))점 남았어요")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                Spacer()
                HomeSeasonShieldBadgeView(active: summary.weatherShieldActive, rotation: shieldRotation)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
                Text("남은 시간 \(remainingTimeText)")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
                Spacer()
                HStack(spacing: 12) {
                    Button("시즌이 뭔가요?", action: onOpenGuide)
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .accessibilityIdentifier("home.season.guide")
                        .frame(minHeight: 44)
                    Button("상세보기 >", action: onOpenDetail)
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                        .accessibilityIdentifier("home.season.detail")
                        .frame(minHeight: 44)
                }
            }

            HStack(spacing: 8) {
                HomeSeasonMetricPillView(
                    title: "기여",
                    value: "\(summary.contributionCount)회",
                    color: Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A8A, alpha: 0.24)
                )
                HomeSeasonMetricPillView(
                    title: "보호",
                    value: "\(summary.weatherShieldApplyCount)회",
                    color: Color.appDynamicHex(light: 0xDCFCE7, dark: 0x14532D, alpha: 0.34)
                )
                HomeSeasonMetricPillView(
                    title: "주차",
                    value: summary.weekKey.isEmpty ? "-" : summary.weekKey,
                    color: Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.34)
                )
            }
        }
        .padding(16)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "시즌 점수 \(Int(summary.score.rounded()))점, 랭크 \(summary.rankTier.title), 보호 \(summary.weatherShieldApplyCount)회, 남은 시간 \(remainingTimeText)"
        )
    }
}
