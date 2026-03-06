import SwiftUI

struct HomeAnimatedSeasonGaugeView: View {
    let progress: Double
    let isMotionReduced: Bool
    let waveOffset: CGFloat

    var body: some View {
        let clampedProgress = min(1.0, max(0.0, progress))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appTextLightGray.opacity(0.24))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appGreen.opacity(0.75), Color.appYellow.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * clampedProgress)
                    .overlay(alignment: .leading) {
                        if isMotionReduced == false && clampedProgress > 0 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.34),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 120)
                                .offset(x: waveOffset)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
    }
}
