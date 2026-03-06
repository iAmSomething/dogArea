import SwiftUI

struct AreaDetailActionHintCardView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))

            Text(bodyText)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15, alpha: 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                )
        )
    }
}
