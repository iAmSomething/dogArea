import SwiftUI

struct TerritoryGoalHeaderSectionView: View {
    let eyebrowText: String
    let title: String
    let subtitle: String
    let badgeText: String
    let goalMeaningText: String
    let sourceText: String
    let freshnessText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrowText)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))

            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 34, relativeTo: .largeTitle))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text(subtitle)
                .font(.appScaledFont(for: .Regular, size: 16, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

            Text(badgeText)
                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.3))
                .clipShape(Capsule())

            Text(goalMeaningText)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))

            HStack(spacing: 8) {
                Label(sourceText, systemImage: "square.stack.3d.up")
                Label(freshnessText, systemImage: "clock")
            }
            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
    }
}
