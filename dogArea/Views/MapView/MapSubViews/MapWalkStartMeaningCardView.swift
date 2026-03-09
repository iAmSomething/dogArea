import SwiftUI

struct MapWalkStartMeaningCardView: View {
    let presentation: MapWalkStartPresentation
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.meaningTitle)
                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .headline))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(2)
            Text(presentation.meaningSummary)
                .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(isExpanded ? 3 : 1)

            if isExpanded {
                Text(presentation.meaningDetail)
                    .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption))
                    .foregroundStyle(MapChromePalette.secondaryText)
                    .lineLimit(3)
                    .accessibilityIdentifier("map.walk.startMeaning.detail")
            }

            disclosureActions
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapChromePill(.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.startMeaning.card")
    }

    private var disclosureActions: some View {
        HStack(spacing: 10) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 4) {
                    Text(isExpanded ? presentation.disclosureCloseTitle : presentation.disclosureTitle)
                        .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(MapChromePalette.primaryText)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isExpanded ? "map.walk.startMeaning.collapse" : "map.walk.startMeaning.expand")

            if isExpanded {
                Button(action: onOpenGuide) {
                    HStack(spacing: 4) {
                        Text(presentation.guideTitle)
                            .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(MapChromePalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.walk.guide.reopen")
            }
        }
    }
}
