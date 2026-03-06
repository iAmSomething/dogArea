import SwiftUI

struct HomeAnimatedQuestProgressBarView: View {
    let progress: Double
    let isCompleted: Bool
    let showPulse: Bool
    let isMotionReduced: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appTextLightGray.opacity(0.28))
                Capsule()
                    .fill(isCompleted ? Color.appGreen : Color.appYellow)
                    .frame(width: proxy.size.width * progress)
                if showPulse && isMotionReduced == false {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: proxy.size.width * progress)
                        .blur(radius: 2.5)
                }
            }
        }
        .frame(height: 8)
        .animation(isMotionReduced ? nil : .easeOut(duration: 0.34), value: progress)
    }
}
