import SwiftUI

struct HomeWeatherShieldSummaryCardView: View {
    let summary: WeatherShieldDailySummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("오늘 스트릭 보호 요약")
                    .font(.appFont(for: .SemiBold, size: 13))
                Text("보호 적용 \(summary.applyCount)회 · 마지막 \(summary.lastAppliedAtText)")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Spacer()
        }
        .padding(11)
        .background(Color.appGreen.opacity(0.22))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 스트릭 보호 요약. 적용 \(summary.applyCount)회, 마지막 \(summary.lastAppliedAtText)")
    }
}
