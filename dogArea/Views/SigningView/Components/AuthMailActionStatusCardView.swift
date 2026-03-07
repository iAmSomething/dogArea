import SwiftUI

struct AuthMailActionStatusCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let actionType: AuthMailActionType
    let email: String
    let state: AuthMailResendState
    let messageOverride: String?
    let resendAccessibilityIdentifier: String
    let continueAccessibilityIdentifier: String?
    let onResend: () -> Void
    let onContinue: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(statusTint.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: statusIconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(statusTint)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.appFont(for: .SemiBold, size: 16))
                        .foregroundStyle(Color.appColor(type: .appTextBlack, scheme: colorScheme))
                    if let message = messageOverride ?? state.message(for: actionType, email: email) {
                        Text(message)
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(state.buttonTitle(for: actionType)) {
                    onResend()
                }
                .buttonStyle(AppFilledButtonStyle(role: state.isRequestAllowed ? .primary : .neutral, fillsWidth: false))
                .disabled(state.isRequestAllowed == false)
                .accessibilityIdentifier(resendAccessibilityIdentifier)

                if let onContinue, let continueAccessibilityIdentifier {
                    Button("프로필 입력 계속") {
                        onContinue()
                    }
                    .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                    .accessibilityIdentifier(continueAccessibilityIdentifier)
                }
            }
        }
        .appCardSurface()
    }

    private var statusTitle: String {
        switch state {
        case .idle, .sending, .sent, .cooldown, .rateLimited:
            return actionType.successTitle()
        case .failed:
            return "다시 확인이 필요해요"
        }
    }

    private var statusTint: Color {
        switch state {
        case .failed:
            return Color.appRed
        case .rateLimited:
            return Color.appYellow
        case .idle, .sending, .sent, .cooldown:
            return Color.appGreen
        }
    }

    private var statusIconName: String {
        switch state {
        case .failed:
            return "exclamationmark.circle.fill"
        case .rateLimited:
            return "clock.badge.exclamationmark"
        case .idle, .sending, .sent, .cooldown:
            return "envelope.badge.fill"
        }
    }
}
