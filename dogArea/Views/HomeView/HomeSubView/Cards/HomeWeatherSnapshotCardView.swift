import SwiftUI

struct HomeWeatherSnapshotCardView: View {
    let presentation: HomeWeatherSnapshotCardPresentation
    let onOpenGuidanceDetail: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var surfaceColor: Color {
        Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B)
    }

    private var borderColor: Color {
        Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
    }

    private var badgeBackgroundColor: Color {
        if presentation.isPlaceholder {
            return Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
        }
        if presentation.isFallback {
            return Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F)
        }
        return Color.appDynamicHex(light: 0xDCFCE7, dark: 0x14532D)
    }

    private var badgeTextColor: Color {
        if presentation.isPlaceholder {
            return Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0)
        }
        if presentation.isFallback {
            return Color.appDynamicHex(light: 0x92400E, dark: 0xFEF3C7)
        }
        return Color.appDynamicHex(light: 0x166534, dark: 0xDCFCE7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title)
                        .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(presentation.subtitle)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(presentation.statusBadgeText)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(badgeTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(presentation.metrics) { metric in
                    HomeWeatherSnapshotMetricTileView(metric: metric)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.observedAtText)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                    .accessibilityIdentifier("home.weather.observedAt")
                Text(presentation.sourceLineText)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.weather.source")
                Text(presentation.missionHintText)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.weather.missionHint")
            }

            Button(action: onOpenGuidanceDetail) {
                HStack(spacing: 8) {
                    Text(presentation.detailActionTitle)
                        .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenGuidanceDetail)
                .accessibilityIdentifier("home.weather.more")
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(presentation.detailActionTitle)
            .accessibilityHint("오늘 산책 가이드를 자세히 확인합니다.")
            .accessibilityIdentifier("home.weather.more")
        }
        .padding(16)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .accessibilityIdentifier("home.weather.snapshot")
    }
}
