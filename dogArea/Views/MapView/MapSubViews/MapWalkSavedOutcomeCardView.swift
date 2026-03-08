import SwiftUI

struct MapWalkSavedOutcomeCardView: View {
    let presentation: MapWalkSavedOutcomePresentation
    let onOpenHistory: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                        .foregroundStyle(MapChromePalette.primaryText)
                    Text(presentation.summary)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("닫기", action: onDismiss)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption2))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .mapChromePill(.neutral)
                    .accessibilityIdentifier("map.walk.savedOutcome.dismiss")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(presentation.followUpItems) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                            .foregroundStyle(MapChromePalette.primaryText)
                        Text(item.body)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                            .foregroundStyle(MapChromePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mapChromePill(.neutral)
                }
            }

            Button(action: onOpenHistory) {
                Text(presentation.primaryActionTitle)
                    .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.walk.savedOutcome.openHistory")
        }
        .padding(12)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.savedOutcome.card")
    }
}
