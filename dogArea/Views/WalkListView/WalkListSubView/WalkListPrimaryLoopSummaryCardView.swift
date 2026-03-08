import SwiftUI

struct WalkListPrimaryLoopSummaryCardView: View {
    let badgeText: String
    let title: String
    let message: String
    let secondaryFlowText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(badgeText)
                .appPill(isActive: true)
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(message)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
            Text(secondaryFlowText)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.primaryLoop.card")
    }
}
