import SwiftUI

struct WalkListStatusCardView: View {
    let model: WalkListStateCardModel
    var actionAccessibilityIdentifier: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: model.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .frame(width: 42, height: 42)
                .background(Color.appYellowPale)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(model.badge)
                    .appPill(isActive: true)
                Text(model.title)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(model.message)
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                if let primaryActionTitle = model.primaryActionTitle,
                   let action {
                    Button(primaryActionTitle, action: action)
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .accessibilityIdentifier(actionAccessibilityIdentifier ?? "walklist.state.primaryAction")
                        .frame(minHeight: 44)
                }
                Text(model.footnote)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.accessibilityIdentifier)
    }
}
