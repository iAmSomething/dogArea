import SwiftUI

struct WalkListPrimaryLoopSummaryCardView: View {
    let badgeText: String
    let title: String
    let message: String
    let secondaryFlowText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(badgeText)
                .appPill(isActive: true)
                .accessibilityIdentifier("walklist.primaryLoop.badge")

            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(secondaryFlowText)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("walklist.primaryLoop.secondary")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.primaryLoop.card")
    }
}
