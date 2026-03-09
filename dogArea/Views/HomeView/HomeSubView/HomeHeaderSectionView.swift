import SwiftUI

struct HomeHeaderSectionView: View {
    let displayUserName: String
    let levelBadgeText: String
    let selectedPetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("안녕하세요, \(displayUserName)님!")
                    .font(.appScaledFont(for: .SemiBold, size: 36, relativeTo: .largeTitle))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.header.title")
                Spacer(minLength: 0)
                Text(levelBadgeText)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.appDynamicHex(light: 0xFFFBEB, dark: 0x334155))
                    )
                    .accessibilityIdentifier("home.header.levelBadge")
            }
            Text("오늘도 \(selectedPetName)와 즐거운 산책 되세요.")
                .font(.appScaledFont(for: .Regular, size: 16, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.header.subtitle")
            Rectangle()
                .fill(Color.appDynamicHex(light: 0xCBD5E1, dark: 0x334155))
                .frame(height: 1)
                .padding(.top, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.header.section")
    }
}
