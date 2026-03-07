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
                                    .foregroundStyle(Color.appYellow)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.appYellow.opacity(0.12))
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
}
