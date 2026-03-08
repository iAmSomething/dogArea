import SwiftUI

struct WalkListSectionHeaderView: View {
    let model: WalkListSectionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(model.subtitle)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .accessibilityIdentifier(model.accessibilityIdentifier ?? "")
    }
}
