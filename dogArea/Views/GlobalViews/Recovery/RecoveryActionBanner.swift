import SwiftUI

struct RecoveryActionBanner: View {
    let issue: RecoveryIssue
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.title)
                .font(.appFont(for: .SemiBold, size: 13))
            Text(issue.message)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button(issue.primaryButtonTitle) {
                    onPrimary()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)

                Button("닫기") {
                    onDismiss()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}
