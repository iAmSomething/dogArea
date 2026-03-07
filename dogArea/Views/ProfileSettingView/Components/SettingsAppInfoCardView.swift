import SwiftUI

struct SettingsAppInfoCardView: View {
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String
    let rows: [SettingsInfoRow]

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
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.label)
                            .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Spacer(minLength: 12)
                        Text(row.value)
                            .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 32)
                    .accessibilityIdentifier(row.accessibilityIdentifier)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .appCardSurface()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
