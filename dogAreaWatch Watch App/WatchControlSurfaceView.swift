import SwiftUI

struct WatchControlSurfaceView: View {
    let isWalking: Bool
    let isReachable: Bool
    let walkingTime: TimeInterval
    let walkingArea: Double
    let pointCount: Int
    let petContext: WatchSelectedPetContextState
    let feedbackBanner: WatchActionFeedbackBanner?
    let startWalkPresentation: WatchActionControlPresentation
    let addPointPresentation: WatchActionControlPresentation
    let endWalkPresentation: WatchActionControlPresentation
    let onStartWalk: () -> Void
    let onAddPoint: () -> Void
    let onEndWalk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WatchMainStatusSummaryView(
                isWalking: isWalking,
                isReachable: isReachable,
                walkingTime: walkingTime,
                walkingArea: walkingArea,
                pointCount: pointCount,
                petContext: petContext
            )

            if let feedbackBanner {
                WatchActionBannerView(
                    banner: feedbackBanner,
                    style: .inline
                )
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            WatchPrimaryActionDockView(
                isWalking: isWalking,
                startWalkPresentation: startWalkPresentation,
                addPointPresentation: addPointPresentation,
                endWalkPresentation: endWalkPresentation,
                onStartWalk: onStartWalk,
                onAddPoint: onAddPoint,
                onEndWalk: onEndWalk,
                showsBackground: false
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.controlSurface")
    }
}
