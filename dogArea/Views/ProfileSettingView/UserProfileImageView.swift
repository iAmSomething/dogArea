import SwiftUI
import Kingfisher

struct UserProfileImageView: View {
    @EnvironmentObject var viewModel: SettingViewModel

    var body: some View {
        let rankTier = viewModel.seasonProfileSummary?.rankTier
        let frameStyle = SeasonProfileFrameStyle.style(for: rankTier)
        if let url = viewModel.userInfo?.profile {
            KFImage(URL(string: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        } else {
            Image(uiImage: .emptyImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        }
    }
}
