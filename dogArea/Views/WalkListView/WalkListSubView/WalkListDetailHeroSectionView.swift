import SwiftUI

struct WalkListDetailHeroSectionView: View {
    let hero: WalkListDetailHeroModel
    let metrics: [WalkListDetailMetricModel]
    let onToggleAreaUnit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(hero.badge)
                    .appPill(isActive: true)
                Text(hero.title)
                    .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(hero.subtitle)
                    .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text(hero.petBadge)
                    .appPill(isActive: false)
                if let statusBadge = hero.statusBadge {
                    Text(statusBadge)
                        .appPill(isActive: true)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top)
                ],
                spacing: 10
            ) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.title)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Text(metric.value)
                            .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title2))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        Text(metric.detail)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(metricDetailColor(metric.tone))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    .padding(14)
                    .background(metricBackground(metric.tone))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(metricBorder(metric.tone), lineWidth: 1)
                    )
                    .accessibilityIdentifier("walklist.detail.metric.\(metric.id)")
                    .onTapGesture {
                        if metric.id == "area" {
                            onToggleAreaUnit()
                        }
                    }
                }
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.hero")
    }

    /// 수치 카드 톤에 맞는 배경 색상을 반환합니다.
    /// - Parameter tone: 현재 수치 카드가 사용하는 시각 톤입니다.
    /// - Returns: 카드 배경에 적용할 색상입니다.
    private func metricBackground(_ tone: WalkListDetailMetricModel.Tone) -> Color {
        switch tone {
        case .warm:
            return Color.appDynamicHex(light: 0xFFF7EB, dark: 0x431407, alpha: 0.72)
        case .neutral:
            return Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B)
        case .accent:
            return Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A8A, alpha: 0.22)
        }
    }

    /// 수치 카드 톤에 맞는 외곽선 색상을 반환합니다.
    /// - Parameter tone: 현재 수치 카드가 사용하는 시각 톤입니다.
    /// - Returns: 카드 외곽선에 적용할 색상입니다.
    private func metricBorder(_ tone: WalkListDetailMetricModel.Tone) -> Color {
        switch tone {
        case .warm:
            return Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12)
        case .neutral:
            return Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
        case .accent:
            return Color.appDynamicHex(light: 0xBFDBFE, dark: 0x1D4ED8)
        }
    }

    /// 수치 카드 톤에 맞는 보조 설명 색상을 반환합니다.
    /// - Parameter tone: 현재 수치 카드가 사용하는 시각 톤입니다.
    /// - Returns: 보조 설명 텍스트에 적용할 색상입니다.
    private func metricDetailColor(_ tone: WalkListDetailMetricModel.Tone) -> Color {
        switch tone {
        case .warm:
            return Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74)
        case .neutral:
            return Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1)
        case .accent:
            return Color.appDynamicHex(light: 0x2563EB, dark: 0x93C5FD)
        }
    }
}
