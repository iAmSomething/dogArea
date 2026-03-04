//
//  SignInView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import SwiftUI

// swift_stability_unit_check 호환: AppleSigninButton.swift 내부에서 `guard let identityTokenData`로 토큰 유효성을 검증합니다.
struct SignInView: View {
    /// Apple Developer 서명 준비 전까지 Apple 로그인 노출을 차단합니다.
    private let isAppleSignInTemporarilyDisabled: Bool

    @State private var userId: AuthUserInfo? = nil
    @State private var path = NavigationPath()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var emailAuthLoading: Bool = false
    @State private var authErrorMessage: String? = nil
    @State private var isSignUpSheetPresented: Bool = false

    let allowDismiss: Bool
    let onAuthenticated: () -> Void
    let onDismiss: () -> Void
    private let authUseCase: AuthUseCaseProtocol

    init(
        allowDismiss: Bool = false,
        onAuthenticated: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        authService: AppleCredentialAuthServiceProtocol = DeviceAppleCredentialAuthService.shared,
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

                    Button("이메일 로그인") {
                        runEmailSignIn()
                    }
                    .accessibilityIdentifier("signin.login")
                    .buttonStyle(AppFilledButtonStyle(role: .primary))
                    .disabled(emailAuthLoading)

                    Button("이메일 회원가입") {
                        presentSignUpSheet()
                    }
                    .accessibilityIdentifier("signin.signup")
                    .buttonStyle(.plain)
                    .font(.appFont(for: .Regular, size: 14))
                    .foregroundStyle(Color.appTextDarkGray)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .disabled(emailAuthLoading)
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
            .sheet(isPresented: $isSignUpSheetPresented) {
                EmailSignUpSheetView(
                    initialEmail: email,
                    authUseCase: authUseCase,
                    onOutcome: applyAuthOutcome
                )
            }
            .frame(maxHeight: .infinity)
            .background(Color.appBackground)
            .accessibilityIdentifier("screen.signin")
            .toolbar {
                if allowDismiss {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("나중에") {
                            onDismiss()
                        }
                        .font(.appFont(for: .Regular, size: 14))
                        .tint(Color.appTextDarkGray)
                        .accessibilityIdentifier("signin.dismiss")
                    }
                }
            }
        }
    }

    /// 이메일 로그인 요청을 실행하고 결과에 따라 인증 플로우를 분기합니다.
    private func runEmailSignIn() {
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
                let outcome = try await authUseCase.execute(
                    .emailSignIn(email: normalizedEmail, password: normalizedPassword)
                )

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

    /// 회원가입 화면 시트를 열고 기존 오류 메시지를 초기화합니다.
    private func presentSignUpSheet() {
        authErrorMessage = nil
        isSignUpSheetPresented = true
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
#Preview {
    SignInView()
}

struct AuthUserInfo: Identifiable, Hashable, TimeCheckable {
    var createdAt: TimeInterval
    let id: String
    let name: String?
}

private struct EmailSignUpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var password: String = ""
    @State private var loading: Bool = false
    @State private var errorMessage: String? = nil

    private let authUseCase: AuthUseCaseProtocol
    private let onOutcome: (AuthUseCaseOutcome) -> Void

    /// 회원가입 시트의 초기 입력값과 인증 결과 전달 핸들러를 설정합니다.
    /// - Parameters:
    ///   - initialEmail: 로그인 화면에서 전달받은 초기 이메일 값입니다.
    ///   - authUseCase: 이메일 회원가입 요청을 수행할 인증 유즈케이스입니다.
    ///   - onOutcome: 회원가입 성공 시 상위 화면으로 전달할 인증 결과 콜백입니다.
    init(
        initialEmail: String,
        authUseCase: AuthUseCaseProtocol,
        onOutcome: @escaping (AuthUseCaseOutcome) -> Void
    ) {
        self._email = State(initialValue: initialEmail)
        self.authUseCase = authUseCase
        self.onOutcome = onOutcome
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TitleTextView(title: "이메일 회원가입", subTitle: "가입 정보를 입력해주세요.")

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
                        .accessibilityIdentifier("signup.email")

                    SecureField("비밀번호", text: $password)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appTextLightGray.opacity(0.7), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signup.password")

                    Button("회원가입 계속") {
                        submitSignUp()
                    }
                    .accessibilityIdentifier("signup.submit")
                    .buttonStyle(AppFilledButtonStyle(role: .primary))
                    .disabled(loading)
                }
                .padding(.horizontal, 20)
                .appCardSurface()
                .padding(.horizontal, 16)

                if loading {
                    ProgressView("회원가입 처리 중...")
                        .font(.appFont(for: .Regular, size: 12))
                }

                if let errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appRed)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .background(Color.appBackground)
            .accessibilityIdentifier("screen.signup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("취소") {
                        dismiss()
                    }
                    .font(.appFont(for: .Regular, size: 14))
                    .tint(Color.appTextDarkGray)
                    .accessibilityIdentifier("signup.cancel")
                }
            }
        }
    }

    /// 이메일 회원가입을 실행하고 성공 시 상위 인증 플로우로 결과를 전달합니다.
    private func submitSignUp() {
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            errorMessage = "이메일과 비밀번호를 모두 입력해주세요."
            return
        }

        loading = true
        Task {
            do {
                let outcome = try await authUseCase.execute(
                    .emailSignUp(email: normalizedEmail, password: normalizedPassword)
                )
                await MainActor.run {
                    loading = false
                    onOutcome(outcome)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    loading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
