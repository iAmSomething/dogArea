import SwiftUI

struct HomeWeatherGuidanceDecisionFactorsCardView: View {
    let title: String
    let subtitle: String
    let factors: [HomeWeatherGuidanceDecisionFactorPresentation]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(subtitle)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(factors) { factor in
                    Text(factor.title)
                        .font(.appFont(for: .SemiBold, size: 12))
                        .foregroundStyle(textColor(for: factor.tone))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColor(for: factor.tone))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("home.weather.guidance.factor.\(factor.id)")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x16202E))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .accessibilityIdentifier("home.weather.guidance.decisionFactors")
    }

    /// 판단 근거 칩의 톤별 배경색을 계산합니다.
    /// - Parameter tone: 날씨/반려견/기본 fallback 중 어떤 신호인지 나타내는 톤입니다.
    /// - Returns: 현재 칩에 적용할 배경색입니다.
    private func backgroundColor(for tone: HomeWeatherGuidanceDecisionFactorTone) -> Color {
        switch tone {
        case .weather:
            return Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A5F)
        case .pet:
            return Color.appDynamicHex(light: 0xF0FDF4, dark: 0x163B2A)
        case .fallback:
            return Color.appDynamicHex(light: 0xFFFBEB, dark: 0x3B2A10)
        }
    }

    /// 판단 근거 칩의 톤별 전경색을 계산합니다.
    /// - Parameter tone: 날씨/반려견/기본 fallback 중 어떤 신호인지 나타내는 톤입니다.
    /// - Returns: 현재 칩에 적용할 텍스트 색상입니다.
    private func textColor(for tone: HomeWeatherGuidanceDecisionFactorTone) -> Color {
        switch tone {
        case .weather:
            return Color.appDynamicHex(light: 0x1D4ED8, dark: 0xBFDBFE)
        case .pet:
            return Color.appDynamicHex(light: 0x166534, dark: 0xBBF7D0)
        case .fallback:
            return Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA)
        }
    }
}
