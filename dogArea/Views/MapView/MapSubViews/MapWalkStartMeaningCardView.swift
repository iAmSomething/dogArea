import SwiftUI

struct MapWalkStartMeaningCardView: View {
    let presentation: MapWalkStartPresentation
    let onOpenGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.meaningTitle)
                .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .headline))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(2)
            Text(presentation.meaningMessage)
                .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpenGuide) {
                HStack(spacing: 4) {
                    Text("설명 보기")
                        .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(MapChromePalette.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
                .accessibilityIdentifier("map.walk.guide.reopen")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapChromePill(.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.startMeaning.card")
    }
}
