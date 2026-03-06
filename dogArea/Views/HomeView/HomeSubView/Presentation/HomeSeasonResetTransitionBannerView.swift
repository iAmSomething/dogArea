import SwiftUI

struct HomeSeasonResetTransitionBannerView: View {
    var body: some View {
        VStack {
            HStack {
                Text("주간 시즌이 리셋되어 새 라운드를 시작했어요.")
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appYellow)
                    .cornerRadius(10)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
        .transition(.opacity)
    }
}
