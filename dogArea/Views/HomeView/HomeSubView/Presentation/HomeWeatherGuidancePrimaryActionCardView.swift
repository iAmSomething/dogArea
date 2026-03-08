import SwiftUI

struct HomeWeatherGuidancePrimaryActionCardView: View {
    let sectionTitle: String
    let presentation: HomeWeatherGuidancePrimaryActionPresentation

    private var surfaceColor: Color {
        Color.appDynamicHex(light: 0xFFF7EB, dark: 0x31230D)
    }

    private var borderColor: Color {
        Color.appDynamicHex(light: 0xFED7AA, dark: 0x78350F)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.eyebrow)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))
                    Text(presentation.title)
                        .font(.appFont(for: .SemiBold, size: 18))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.body)
                        .font(.appFont(for: .Light, size: 12))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(presentation.emphasisText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFEF3C7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.appDynamicHex(light: 0xFFFBEB, dark: 0x3B2A10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityIdentifier("home.weather.guidance.primaryAction")
    }
}
