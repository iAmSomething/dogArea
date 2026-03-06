import SwiftUI

struct GuestDataUpgradePromptSheetView: View {
    let prompt: GuestDataUpgradePrompt
    let onImport: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt.shouldEmphasizeRetry ? "산책 데이터 이관 재시도" : "게스트 산책 데이터 가져오기")
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text("로그인 전에 기록한 산책 데이터를 계정으로 이관합니다. 중복 없이 안전하게 처리돼요.")
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 6) {
                Text("세션 \(prompt.snapshot.sessionCount)건")
                Text("포인트 \(prompt.snapshot.pointCount)건")
                Text("누적 면적 \(prompt.snapshot.totalAreaM2.calculatedAreaString)")
                Text("누적 시간 \(prompt.snapshot.totalDurationSec.walkingTimeInterval)")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button(prompt.shouldEmphasizeRetry ? "다시 가져오기" : "가져오기") {
                    onImport()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreen)
                .foregroundStyle(Color.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}
