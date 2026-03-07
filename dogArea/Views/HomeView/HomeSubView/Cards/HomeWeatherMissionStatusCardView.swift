import SwiftUI

struct HomeWeatherMissionStatusCardView: View {
    let summary: WeatherMissionStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.policyTitle)
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text(summary.policyText)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text(summary.lifecycleGuideText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.appYellowPale.opacity(0.45))
            .cornerRadius(10)
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
        .accessibilityIdentifier("home.quest.weatherStatus")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityText)
    }
}
