//
//  SignInView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) var scheme

    /// Apple Developer 서명 준비 전까지 Apple 로그인 노출을 차단합니다.
    private let isAppleSignInTemporarilyDisabled: Bool

    @State private var userId: AuthUserInfo? = nil
    @State private var path = NavigationPath()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var emailAuthLoading: Bool = false
    @State private var authErrorMessage: String? = nil

    let allowDismiss: Bool
    let onAuthenticated: () -> Void
    let onDismiss: () -> Void
    private let authUseCase: AuthUseCaseProtocol

    init(
        allowDismiss: Bool = false,
        onAuthenticated: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        authService: AppleCredentialAuthServiceProtocol = DeviceAppleCredentialAuthService.shared,
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        isAppleSignInTemporarilyDisabled: Bool = true,
        authUseCase: AuthUseCaseProtocol? = nil
    ) {
        self.allowDismiss = allowDismiss
        self.onAuthenticated = onAuthenticated
        self.onDismiss = onDismiss
        self.isAppleSignInTemporarilyDisabled = isAppleSignInTemporarilyDisabled
        self.authUseCase = authUseCase ?? DefaultAuthUseCase(
            authRepository: DefaultAuthRepository(credentialService: authService),
            profileRepository: profileRepository,
            sessionStore: authSessionStore
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 14) {
                TitleTextView(title: "로그인/회원가입", subTitle: "계정 정보가 필요해요!")

                if isAppleSignInTemporarilyDisabled == false {
                    AppleSigninButton(
                        authUseCase: authUseCase,
                        onOutcome: applyAuthOutcome,
                        onError: { authErrorMessage = $0 }
                    )

                    HStack {
                        Rectangle().fill(Color.appTextLightGray.opacity(0.5)).frame(height: 0.7)
                        Text("또는 이메일")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                        Rectangle().fill(Color.appTextLightGray.opacity(0.5)).frame(height: 0.7)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text("Apple 로그인은 준비 중입니다. 현재 이메일 로그인/회원가입만 사용할 수 있어요.")
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appTextDarkGray)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 8) {
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appTextLightGray.opacity(0.7), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signin.email")

                    SecureField("비밀번호", text: $password)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appTextLightGray.opacity(0.7), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signin.password")

                    HStack(spacing: 10) {
                        Button("이메일 로그인") {
                            runEmailAuth(isSignup: false)
                        }
                        .accessibilityIdentifier("signin.login")
                        .buttonStyle(AppFilledButtonStyle(role: .primary))
                        .disabled(emailAuthLoading)

                        Button("이메일 회원가입") {
                            runEmailAuth(isSignup: true)
                        }
                        .accessibilityIdentifier("signin.signup")
                        .buttonStyle(AppFilledButtonStyle(role: .secondary))
                        .disabled(emailAuthLoading)
                    }
                }
                .padding(.horizontal, 20)
                .appCardSurface()
                .padding(.horizontal, 16)

                if emailAuthLoading {
                    ProgressView("이메일 인증 처리 중...")
                        .font(.appFont(for: .Regular, size: 12))
                }

                if let authErrorMessage, authErrorMessage.isEmpty == false {
                    Text(authErrorMessage)
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appRed)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationDestination(item: $userId, destination: { info in
                ProfileSettingsView(
                    path: $path,
                    viewModel: .init(info: info),
                    onSignupCompleted: onAuthenticated
                )
            })
            .frame(maxHeight: .infinity)
            .background(Color.appBackground)
            .accessibilityIdentifier("screen.signin")
            .toolbar {
                if allowDismiss {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("나중에") {
                            onDismiss()
                        }
                        .accessibilityIdentifier("signin.dismiss")
                    }
                }
            }
        }
    }

    /// 이메일 로그인/회원가입 요청을 실행하고 결과에 따라 인증 플로우를 분기합니다.
    private func runEmailAuth(isSignup: Bool) {
        authErrorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            authErrorMessage = "이메일과 비밀번호를 모두 입력해주세요."
            return
        }

        emailAuthLoading = true
        Task {
            do {
                let request: AuthRequest = isSignup
                    ? .emailSignUp(email: normalizedEmail, password: normalizedPassword)
                    : .emailSignIn(email: normalizedEmail, password: normalizedPassword)
                let outcome = try await authUseCase.execute(request)

                await MainActor.run {
                    emailAuthLoading = false
                    applyAuthOutcome(outcome)
                }
            } catch {
                await MainActor.run {
                    emailAuthLoading = false
                    authErrorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 유즈케이스 결과에 따라 앱 진입 또는 프로필 온보딩 화면으로 분기합니다.
    private func applyAuthOutcome(_ outcome: AuthUseCaseOutcome) {
        if outcome.requiresOnboarding == false {
            onAuthenticated()
            return
        }
        userId = .init(
            createdAt: Date().timeIntervalSince1970,
            id: outcome.identity.userId,
            name: outcome.displayNameHint
        )
    }
}

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

#Preview {
    SignInView()
}

struct AuthUserInfo: Identifiable, Hashable, TimeCheckable {
    var createdAt: TimeInterval
    let id: String
    let name: String?
}
