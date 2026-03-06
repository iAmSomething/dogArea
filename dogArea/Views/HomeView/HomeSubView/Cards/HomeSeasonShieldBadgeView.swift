import SwiftUI

struct HomeSeasonShieldBadgeView: View {
    let active: Bool
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appTextLightGray.opacity(0.5), lineWidth: 1)
                .frame(width: 28, height: 28)
            if active {
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(rotation))
            }
            Text("S")
                .font(.appFont(for: .SemiBold, size: 11))
        }
    }
}
