import SwiftUI

struct WalkListDashboardHeaderView: View {
    let overview: WalkListOverviewModel
    let pets: [PetInfo]
    let selectedPetId: String
    let onSelectPet: (String) -> Void
    let onRestoreSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(overview.title)
                    .font(.appScaledFont(for: .SemiBold, size: 34, relativeTo: .largeTitle))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(overview.subtitle)
                    .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 12) {
                Text("최근 요약")
                    .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(overview.metrics) { metric in
                        WalkListMetricTileView(
                            title: metric.title,
                            value: metric.value,
                            detail: metric.detail
                        )
                        .accessibilityIdentifier("walklist.summary.\(metric.id)")
                    }
                }
            }
            .appCardSurface()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walklist.summary")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(overview.modeBadge)
                        .appPill(isActive: true)
                    Spacer(minLength: 0)
                    if let restoreActionTitle = overview.restoreActionTitle {
                        Button(restoreActionTitle, action: onRestoreSelected)
                            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                            .frame(minHeight: 44)
                    }
                }

                Text(overview.contextTitle)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(overview.contextMessage)
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
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

                Text(overview.helperMessage)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .appCardSurface()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walklist.context")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.header")
    }
}
