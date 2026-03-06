import SwiftUI

struct HomeQuestAlternativeSuggestionCardView: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appYellowPale.opacity(0.65))
        .cornerRadius(8)
    }
}
