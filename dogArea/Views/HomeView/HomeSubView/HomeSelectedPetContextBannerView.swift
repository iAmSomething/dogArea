import SwiftUI

struct HomeSelectedPetContextBannerView: View {
    let isShowingAllRecordsOverride: Bool
    let selectedPetName: String
    let onRevertToSelectedPet: () -> Void

    private var contextText: String {
        isShowingAllRecordsOverride
            ? "전체 기록 보기 모드 · 선택 반려견 \(selectedPetName)"
            : "선택 반려견 기준 · \(selectedPetName)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(contextText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(contextText)

            if isShowingAllRecordsOverride {
                Button("기준으로 돌아가기") {
                    onRevertToSelectedPet()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)
                .accessibilityLabel("선택 반려견 기준으로 돌아가기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
