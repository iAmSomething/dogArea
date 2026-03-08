import SwiftUI

struct HomeWalkPrimaryLoopCardView: View {
    let presentation: HomeWalkPrimaryLoopPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Text(presentation.badgeText)
                    .appPill(isActive: true)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.title)
                    .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .accessibilityIdentifier("home.walkPrimaryLoop.card")
                Text(presentation.summaryText)
                    .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                ],
                spacing: 10
            ) {
                ForEach(presentation.metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.title)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Text(metric.value)
                            .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(metric.detail)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                            .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1E293B, alpha: 0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(presentation.pillars) { pillar in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pillar.title)
                            .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(pillar.body)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x243244, alpha: 0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Text(presentation.secondaryFlowText)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityText)
        .accessibilityIdentifier("home.walkPrimaryLoop.card")
    }
}
