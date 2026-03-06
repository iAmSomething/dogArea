import SwiftUI

struct HomeGuestDataUpgradeCardView: View {
    let report: GuestDataUpgradeReport
    let validationText: String?
    let lastErrorMessage: String?
    let isRetryInProgress: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.hasOutstandingWork ? "데이터 이관 재시도 필요" : "게스트 데이터 이관 완료")
                .font(.appFont(for: .SemiBold, size: 13))
            Text(
                "세션 \(report.sessionCount)건 · 포인트 \(report.pointCount)건 · 면적 \(report.totalAreaM2.calculatedAreaString)"
            )
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appTextDarkGray)

            if let lastErrorMessage, report.hasOutstandingWork {
                Text("최근 오류: \(lastErrorMessage)")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appRed)
            }
            if let validationText {
                Text(validationText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(report.validationPassed == true ? Color.appGreen : Color.appRed)
            }
            if report.hasOutstandingWork {
                Button(isRetryInProgress ? "재시도 중..." : "이관 재시도", action: onRetry)
                    .accessibilityIdentifier("home.guestUpgrade.retry")
                    .disabled(isRetryInProgress)
                    .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(report.hasOutstandingWork ? Color.appRed : Color.appGreen, lineWidth: 0.4)
        )
    }
}
