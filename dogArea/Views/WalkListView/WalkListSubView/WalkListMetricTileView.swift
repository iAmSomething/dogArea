import SwiftUI

struct WalkListMetricTileView: View {
    let title: String
    let value: String
    let detail: String?
    let accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(1)
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, detail.isEmpty == false {
                Text(detail)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1F2937, alpha: 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFCD68A, dark: 0x334155, alpha: 0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .overlay(alignment: .topLeading) {
            if let accessibilityIdentifier, accessibilityIdentifier.isEmpty == false {
                Color.clear
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}
