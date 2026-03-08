import SwiftUI

struct WatchPrimaryActionDockView: View {
    let isWalking: Bool
    let startWalkPresentation: WatchActionControlPresentation
    let addPointPresentation: WatchActionControlPresentation
    let endWalkPresentation: WatchActionControlPresentation
    let onStartWalk: () -> Void
    let onAddPoint: () -> Void
    let onEndWalk: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isWalking {
                WatchActionButtonView(
                    presentation: addPointPresentation,
                    action: onAddPoint
                )
                WatchActionButtonView(
                    presentation: endWalkPresentation,
                    action: onEndWalk
                )
            } else {
                WatchActionButtonView(
                    presentation: startWalkPresentation,
                    action: onStartWalk
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.actionsDock")
    }
}
