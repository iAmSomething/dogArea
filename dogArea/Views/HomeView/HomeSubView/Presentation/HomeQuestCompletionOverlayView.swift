import SwiftUI

struct HomeQuestCompletionOverlayView: View {
    let payload: QuestCompletionPresentation
    let isVisible: Bool

    var body: some View {
        VStack {
            Spacer().frame(height: 120)
            VStack(spacing: 8) {
                Text("퀘스트 완료")
                    .font(.appFont(for: .SemiBold, size: 16))
                Text(payload.missionTitle)
                    .font(.appFont(for: .SemiBold, size: 14))
                    .multilineTextAlignment(.center)
                Text("+\(payload.rewardPoint)pt 수령 완료")
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appYellow, lineWidth: 1.0)
            )
            .scaleEffect(isVisible ? 1.0 : 0.86)
            .opacity(isVisible ? 1.0 : 0.0)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(isVisible ? 0.18 : 0.0))
        .allowsHitTesting(false)
    }
}
