import SwiftUI

struct HomeSeasonMetricPillView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(Color.appTextDarkGray)
            Text(value)
                .font(.appFont(for: .SemiBold, size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(color)
        .cornerRadius(8)
    }
}
