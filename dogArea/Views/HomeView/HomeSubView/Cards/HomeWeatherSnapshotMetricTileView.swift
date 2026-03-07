import SwiftUI

struct HomeWeatherSnapshotMetricTileView: View {
    let metric: HomeWeatherMetricPresentation

    private var backgroundColor: Color {
        Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A)
    }

    private var borderColor: Color {
        Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .accessibilityIdentifier("home.weather.metric.\(metric.id)")
            Text(metric.valueText)
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.weather.metric.\(metric.id).value")
            if let detailText = metric.detailText {
                Text(detailText)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityIdentifier("home.weather.metric.\(metric.id)")
        .accessibilityElement(children: .combine)
    }
}
