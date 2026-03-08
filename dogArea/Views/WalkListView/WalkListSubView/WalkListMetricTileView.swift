import SwiftUI

struct WalkListMetricTileView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(detail)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1F2937, alpha: 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFCD68A, dark: 0x334155, alpha: 0.55), lineWidth: 1)
        )
    }
}
