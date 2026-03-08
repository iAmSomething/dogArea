import SwiftUI

struct MapWalkStartMeaningCardView: View {
    let presentation: MapWalkStartPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.meaningTitle)
                .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                .foregroundStyle(MapChromePalette.primaryText)
            Text(presentation.meaningMessage)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(presentation.pillars) { pillar in
                    Text(pillar.title)
                        .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption2))
                        .foregroundStyle(MapChromePalette.primaryText)
                        .mapChromePill(.accent)
                }
            }

            Text(presentation.secondaryFlowText)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: 420, alignment: .leading)
        .mapChromeSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.startMeaning.card")
    }
}
