import SwiftUI

struct HomeWeatherMissionStatusCardView: View {
    let summary: WeatherMissionStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(summary.title)
                    .font(.appFont(for: .SemiBold, size: 15))
                Spacer()
                Text(summary.badgeText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(summary.isFallback ? Color.appTextLightGray.opacity(0.35) : Color.appYellowPale)
                    .cornerRadius(8)
            }
            Text(summary.reasonText)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 8) {
                Text(summary.appliedAtText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                Spacer()
                Text(summary.shieldUsageText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(summary.riskLevel == .clear ? Color.appTextDarkGray : Color.appGreen)
            }
            if let fallbackNotice = summary.fallbackNotice {
                Text(fallbackNotice)
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appTextDarkGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.appTextLightGray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextLightGray, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityText)
    }
}
