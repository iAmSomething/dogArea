import SwiftUI

struct HomeStatusBannerView: View {
    let message: String
    let isWarning: Bool

    var body: some View {
        Text(message)
            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .footnote))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isWarning
                ? Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.35)
                : Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E293B)
            )
            .cornerRadius(12)
    }
}
