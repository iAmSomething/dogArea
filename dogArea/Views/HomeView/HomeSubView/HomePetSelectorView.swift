import SwiftUI

struct HomePetSelectorView: View {
    let pets: [PetInfo]
    let selectedPetId: String
    let onSelectPet: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pets, id: \.petId) { pet in
                    Button {
                        onSelectPet(pet.petId)
                    } label: {
                        Text(pet.petName)
                            .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .footnote))
                            .foregroundStyle(
                                selectedPetId == pet.petId
                                ? Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA)
                                : Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedPetId == pet.petId
                                        ? Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.35)
                                        : Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
                                    )
                            )
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
