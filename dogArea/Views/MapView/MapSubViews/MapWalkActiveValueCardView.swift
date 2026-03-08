import SwiftUI

struct MapWalkActiveValueCardView: View {
    let presentation: MapWalkActiveValuePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                .foregroundStyle(MapChromePalette.primaryText)
            Text(presentation.summary)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(presentation.metrics) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.title)
                            .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                            .foregroundStyle(MapChromePalette.secondaryText)
                        Text(metric.value)
                            .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                            .foregroundStyle(MapChromePalette.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .mapChromePill(.neutral)
                }
            }

            Text(presentation.footer)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: 420, alignment: .leading)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.activeValue.card")
    }
}
