import SwiftUI

struct HomeMissionGuideCoachCardView: View {
    let presentation: HomeMissionGuideCoachPresentation
    let onOpenGuide: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale.opacity(0.9))
                .clipShape(Capsule())

            Text(presentation.title)
                .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.summaryText)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onOpenGuide) {
                    Text(presentation.primaryActionTitle)
                        .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .headline))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appYellow)
                .foregroundStyle(Color.appInk)
                .accessibilityIdentifier("home.quest.help.coach.open")

                Button(action: onDismiss) {
                    Text(presentation.dismissActionTitle)
                        .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .headline))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                .accessibilityIdentifier("home.quest.help.coach.dismiss")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x3F2A12))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFCD34D), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quest.help.coach")
    }
}
