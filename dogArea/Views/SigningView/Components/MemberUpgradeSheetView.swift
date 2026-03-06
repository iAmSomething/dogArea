import SwiftUI

struct MemberUpgradeSheetView: View {
    let request: MemberUpgradeRequest
    let onUpgrade: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(request.trigger.title)
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text(request.trigger.message)
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 8) {
                Text("• 계정 연동 후 자동 백업")
                Text("• 기기 변경 시 기록 복원")
                Text("• 로그인 완료 후 현재 화면으로 복귀")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .accessibilityIdentifier("sheet.memberUpgrade.later")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button("로그인하고 계속") {
                    onUpgrade()
                }
                .accessibilityIdentifier("sheet.memberUpgrade.signin")
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
