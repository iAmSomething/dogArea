import SwiftUI

struct WalkListMetricTileView: View {
    let title: String
    let value: String
    let detail: String?
    let accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(1)
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .lineLimit(3)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            if let detail, detail.isEmpty == false {
                Text(detail)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1F2937, alpha: 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFCD68A, dark: 0x334155, alpha: 0.55), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if let accessibilityIdentifier, accessibilityIdentifier.isEmpty == false {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.001))
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
