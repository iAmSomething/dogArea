import SwiftUI

struct SettingsPrivacyCenterEntryCardView: View {
    let summary: SettingsPrivacyEntrySummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프라이버시 센터")
                            .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(summary.subtitle)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(summary.badgeText)
                        .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                        .foregroundStyle(badgeForegroundColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(badgeBackgroundColor)
                        .clipShape(Capsule())
                }

                Text("프라이버시 센터 열기")
                    .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appTextLightGray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityIdentifier("settings.privacyCenter.entry")
            .accessibilityLabel("프라이버시 센터 열기")
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appCardSurface()
    }

    private var badgeForegroundColor: Color {
        switch summary.tone {
        case .neutral:
            return Color.appTextDarkGray
        case .positive:
            return Color.appGreen
        case .warning:
            return Color.appYellow
        case .critical:
            return Color.appRed
        }
    }

    private var badgeBackgroundColor: Color {
        switch summary.tone {
        case .neutral:
            return Color.appTextLightGray.opacity(0.18)
        case .positive:
            return Color.appGreen.opacity(0.14)
        case .warning:
            return Color.appYellow.opacity(0.14)
        case .critical:
            return Color.appRed.opacity(0.14)
        }
    }
}
