import SwiftUI
import AuthenticationServices

struct AppleSigninButton: View {
    let authUseCase: AuthUseCaseProtocol
    let onOutcome: (AuthUseCaseOutcome) -> Void
    let onError: (String) -> Void
    @State private var isAuthenticating: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        isAuthenticating = true
                        switch authResults.credential {
                        case let appleIDCredential as ASAuthorizationAppleIDCredential:
                            let fullName = appleIDCredential.fullName
                            let name = (fullName?.familyName ?? "") + (fullName?.givenName ?? "")
                            guard let identityTokenData = appleIDCredential.identityToken,
                                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                                isAuthenticating = false
                                onError("Apple identity token이 없습니다.")
                                return
                            }
                            Task {
                                do {
                                    let outcome = try await authUseCase.execute(
                                        .apple(
                                            identityToken: identityToken,
                                            appleUserId: appleIDCredential.user,
                                            nameHint: name.isEmpty ? nil : name
                                        )
                                    )
                                    await MainActor.run {
                                        isAuthenticating = false
                                        onOutcome(outcome)
                                    }
                                } catch {
                                    await MainActor.run {
                                        isAuthenticating = false
                                        onError(error.localizedDescription)
                                    }
                                }
                            }

                        default:
                            isAuthenticating = false
                            break
                        }
                    case .failure(let error):
                        isAuthenticating = false
                        onError(error.localizedDescription)
                    }
                }
            )
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 50)
            .cornerRadius(5)

            if isAuthenticating {
                ProgressView("Apple 로그인 처리 중...")
                    .font(.appFont(for: .Regular, size: 12))
            }
        }

    }
}
