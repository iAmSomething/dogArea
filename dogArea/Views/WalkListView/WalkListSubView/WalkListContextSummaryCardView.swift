import SwiftUI

struct WalkListContextSummaryCardView: View {
    let modeBadge: String
    let title: String
    let message: String
    let helperMessage: String
    let pets: [PetInfo]
    let selectedPetId: String
    let restoreActionTitle: String?
    let onSelectPet: (String) -> Void
    let onRestoreSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(modeBadge)
                    .appPill(isActive: true)
                Spacer(minLength: 0)
                if let restoreActionTitle {
                    Button(restoreActionTitle, action: onRestoreSelected)
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .frame(minHeight: 40)
                }
            }

            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if pets.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pets, id: \.petId) { pet in
                            Button {
                                onSelectPet(pet.petId)
                            } label: {
                                Text(pet.petName)
                                    .appPill(isActive: selectedPetId == pet.petId)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("walklist.pet.\(pet.petId)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Text(helperMessage)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("walklist.context.helper")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.context")
    }
}
