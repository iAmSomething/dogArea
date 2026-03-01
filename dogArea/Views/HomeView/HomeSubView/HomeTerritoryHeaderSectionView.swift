import SwiftUI

struct HomeTerritoryHeaderSectionView: View {
    let selectedPetNameWithYi: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(selectedPetNameWithYi)의 영역")
                .font(.appScaledFont(for: .SemiBold, size: 36, relativeTo: .title2))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text("\(selectedPetNameWithYi)가 정복한 영역을 확인해보세요!")
                .font(.appScaledFont(for: .Regular, size: 16, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
