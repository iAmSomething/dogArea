import SwiftUI

struct WalkCompletionValueFlowCardView: View {
    let presentation: WalkCompletionValuePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(presentation.summary)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(presentation.items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(item.body)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x2B2116))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text(presentation.footnote)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("walk.detail.valueFlow.card")
    }
}
