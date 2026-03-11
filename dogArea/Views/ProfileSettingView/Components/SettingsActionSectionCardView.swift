import SwiftUI

struct SettingsActionSectionCardView: View {
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String
    let actions: [SettingsSurfaceAction]
    let onSelect: (SettingsSurfaceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(subtitle)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }

            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    Button {
                        onSelect(action)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appYellow.opacity(0.18))
                                    .frame(width: 38, height: 38)
                                Image(systemName: action.iconSystemName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.appYellow)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.title)
                                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                                    .multilineTextAlignment(.leading)
                                Text(action.subtitle)
                                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 8)

                            if let badgeText = action.badgeText {
                                Text(badgeText)
                                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                                    .foregroundStyle(badgeForegroundColor(for: action.badgeTone))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(badgeBackgroundColor(for: action.badgeTone))
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(action.accessibilityIdentifier)

                    if index < actions.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .appCardSurface()
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// 설정 액션 배지의 foreground 색상을 톤에 맞춰 계산합니다.
    /// - Parameter tone: 액션이 노출할 배지 강조 톤입니다.
    /// - Returns: 사용자 상태에 맞는 배지 전경색입니다.
    private func badgeForegroundColor(for tone: SettingsPrivacyTone?) -> Color {
        switch tone {
        case .positive:
            return Color.appGreen
        case .warning:
            return Color.appYellow
        case .critical:
            return Color.appRed
        case .neutral, .none:
            return Color.appTextDarkGray
        }
    }

    /// 설정 액션 배지의 background 색상을 톤에 맞춰 계산합니다.
    /// - Parameter tone: 액션이 노출할 배지 강조 톤입니다.
    /// - Returns: 사용자 상태에 맞는 배지 배경색입니다.
    private func badgeBackgroundColor(for tone: SettingsPrivacyTone?) -> Color {
        switch tone {
        case .positive:
            return Color.appGreen.opacity(0.14)
        case .warning:
            return Color.appYellow.opacity(0.14)
        case .critical:
            return Color.appRed.opacity(0.14)
        case .neutral, .none:
            return Color.appTextLightGray.opacity(0.18)
        }
    }
}
