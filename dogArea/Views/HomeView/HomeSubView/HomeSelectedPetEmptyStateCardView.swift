import SwiftUI

struct HomeSelectedPetEmptyStateCardView: View {
    let selectedPetName: String
    let onShowAllRecords: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedPetName) 기록이 아직 없어요")
                .font(.appFont(for: .SemiBold, size: 14))
            Text("필터를 유지하면 0건으로 보일 수 있어요. 전체 기록으로 전환해 계속 탐색해보세요.")
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Button("전체 기록 보기") {
                onShowAllRecords()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.appYellow)
            .cornerRadius(8)
            .accessibilityLabel("전체 기록 보기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextDarkGray, lineWidth: 0.25)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
