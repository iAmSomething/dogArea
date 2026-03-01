import SwiftUI

struct HomeWeeklyMetricCardView: View {
    let title: String
    let value: String
    let accentText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            Text(value)
                .font(.appScaledFont(for: .Bold, size: 35, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(accentText)
                .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x10B981, dark: 0x34D399))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x1E293B))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
    }
}
