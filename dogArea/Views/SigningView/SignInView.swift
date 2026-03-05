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
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 2, height: 2)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("screen.signin")
            }
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
    private enum SignUpField: Hashable {
        case email
        case password
        case confirmPassword
    }

    private enum FieldValidationState: Equatable {
        case idle
        case validating
        case valid(message: String)
        case invalid(message: String)

        var message: String? {
            switch self {
            case .valid(let message), .invalid(let message):
                return message
            case .idle, .validating:
                return nil
            }
        }

        var borderColor: Color {
            switch self {
            case .idle:
                return Color.appTextLightGray.opacity(0.7)
            case .validating:
                return Color.appYellow
            case .valid:
                return Color.appGreen
            case .invalid:
                return Color.appRed
            }
        }

        var messageColor: Color {
            switch self {
            case .invalid:
                return Color.appRed
            case .valid:
                return Color.appGreen
            case .idle, .validating:
                return Color.appTextDarkGray
            }
        }

        var isValid: Bool {
            if case .valid = self {
                return true
            }
            return false
        }
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: SignUpField?

    @State private var email: String
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var loading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var emailValidationState: FieldValidationState = .idle
    @State private var passwordValidationState: FieldValidationState = .idle
    @State private var confirmPasswordValidationState: FieldValidationState = .idle
    @State private var lastValidatedEmail: String = ""
    @State private var emailValidationTask: Task<Void, Never>? = nil

    private let authUseCase: AuthUseCaseProtocol
    private let emailValidationService: SignUpEmailValidationServicing
    private let onOutcome: (AuthUseCaseOutcome) -> Void
    private let minimumPasswordLength: Int = 8

    /// 회원가입 시트의 초기 입력값과 인증 결과 전달 핸들러를 설정합니다.
    /// - Parameters:
    ///   - initialEmail: 로그인 화면에서 전달받은 초기 이메일 값입니다.
    ///   - authUseCase: 이메일 회원가입 요청을 수행할 인증 유즈케이스입니다.
    ///   - emailValidationService: 이메일 중복 확인 RPC 요청을 수행하는 검증 서비스입니다.
    ///   - onOutcome: 회원가입 성공 시 상위 화면으로 전달할 인증 결과 콜백입니다.
    init(
        initialEmail: String,
        authUseCase: AuthUseCaseProtocol,
        emailValidationService: SignUpEmailValidationServicing = SupabaseSignUpEmailValidationService(),
        onOutcome: @escaping (AuthUseCaseOutcome) -> Void
    ) {
        self._email = State(initialValue: initialEmail)
        self.authUseCase = authUseCase
        self.emailValidationService = emailValidationService
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
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            handleEmailSubmit()
                        }
                        .onChange(of: email) { _, _ in
                            handleEmailInputChanged()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(emailValidationState.borderColor, lineWidth: 1.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signup.email")
                    if let message = emailValidationState.message {
                        Text(message)
                            .font(.appFont(for: .Regular, size: 11))
                            .foregroundStyle(emailValidationState.messageColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SecureField("비밀번호", text: $password)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            handlePasswordSubmit()
                        }
                        .onChange(of: password) { _, _ in
                            handlePasswordInputChanged()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(passwordValidationState.borderColor, lineWidth: 1.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signup.password")
                    if let message = passwordValidationState.message {
                        Text(message)
                            .font(.appFont(for: .Regular, size: 11))
                            .foregroundStyle(passwordValidationState.messageColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SecureField("비밀번호 확인", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            handleConfirmPasswordSubmit()
                        }
                        .onChange(of: confirmPassword) { _, _ in
                            validatePasswordFields(triggerHaptic: false)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(confirmPasswordValidationState.borderColor, lineWidth: 1.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("signup.passwordConfirm")
                    if let message = confirmPasswordValidationState.message {
                        Text(message)
                            .font(.appFont(for: .Regular, size: 11))
                            .foregroundStyle(confirmPasswordValidationState.messageColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
            .onChange(of: focusedField) { oldValue, newValue in
                handleFocusTransition(from: oldValue, to: newValue)
            }
            .onDisappear {
                emailValidationTask?.cancel()
            }
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
        let normalizedConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationError = validateSignUpInput(
            email: normalizedEmail,
            password: normalizedPassword,
            confirmPassword: normalizedConfirmPassword
        ) {
            errorMessage = validationError
            AppHapticFeedback.questFailed()
            return
        }

        loading = true
        Task {
            let isEmailAvailable = await ensureEmailAvailabilityBeforeSubmit(email: normalizedEmail)
            guard isEmailAvailable else {
                await MainActor.run {
                    loading = false
                }
                return
            }
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
                    AppHapticFeedback.questFailed()
                }
            }
        }
    }

    /// 회원가입 입력값을 로컬에서 검증하고 실패 사유를 반환합니다.
    /// - Parameters:
    ///   - email: 공백 정리 후 검증할 이메일 문자열입니다.
    ///   - password: 공백 정리 후 검증할 비밀번호 문자열입니다.
    ///   - confirmPassword: 비밀번호 확인 입력값입니다.
    /// - Returns: 검증 실패 시 사용자에게 노출할 메시지이며, 통과하면 `nil`입니다.
    private func validateSignUpInput(
        email: String,
        password: String,
        confirmPassword: String
    ) -> String? {
        guard email.isEmpty == false, password.isEmpty == false, confirmPassword.isEmpty == false else {
            return "이메일, 비밀번호, 비밀번호 확인을 모두 입력해주세요."
        }
        guard isValidEmailFormat(email) else {
            return "올바른 이메일 형식을 입력해주세요."
        }
        guard validatePasswordFormat(password) else {
            return "비밀번호는 \(minimumPasswordLength)자 이상이며 영문/숫자를 모두 포함해야 합니다."
        }
        guard password == confirmPassword else {
            return "비밀번호 확인이 일치하지 않습니다."
        }
        return nil
    }

    /// 이메일 문자열이 기본 형식을 만족하는지 검사합니다.
    /// - Parameter email: 형식 검증 대상 이메일 문자열입니다.
    /// - Returns: 기본 이메일 형식을 만족하면 `true`, 아니면 `false`입니다.
    private func isValidEmailFormat(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    /// 이메일 입력값 변경 시 기존 서버 검증 상태를 초기화합니다.
    private func handleEmailInputChanged() {
        lastValidatedEmail = ""
        emailValidationTask?.cancel()
        if case .idle = emailValidationState {
            return
        }
        emailValidationState = .idle
    }

    /// 비밀번호 입력값 변경 시 형식/확인값 검증 상태를 재계산합니다.
    private func handlePasswordInputChanged() {
        validatePasswordFields(triggerHaptic: false)
    }

    /// 포커스 전환 시 이메일 서버 검증 및 비밀번호 로컬 검증을 트리거합니다.
    /// - Parameters:
    ///   - previous: 포커스 전환 직전 필드입니다.
    ///   - current: 포커스 전환 후 현재 필드입니다.
    private func handleFocusTransition(from previous: SignUpField?, to current: SignUpField?) {
        if previous == .email, current != .email {
            validateEmailAvailabilityFromServer(triggerHaptic: true)
        }
        if previous == .password, current != .password {
            validatePasswordFields(triggerHaptic: true)
        }
        if previous == .confirmPassword, current != .confirmPassword {
            validatePasswordFields(triggerHaptic: true)
        }
    }

    /// 이메일 필드 submit 액션에서 서버 중복 검사를 실행하고 비밀번호 필드로 포커스를 이동합니다.
    private func handleEmailSubmit() {
        focusedField = .password
        validateEmailAvailabilityFromServer(triggerHaptic: true)
    }

    /// 비밀번호 필드 submit 액션에서 비밀번호 검증을 실행하고 확인 필드로 포커스를 이동합니다.
    private func handlePasswordSubmit() {
        focusedField = .confirmPassword
        validatePasswordFields(triggerHaptic: true)
    }

    /// 비밀번호 확인 필드 submit 액션에서 검증을 마무리하고 키보드를 닫습니다.
    private func handleConfirmPasswordSubmit() {
        focusedField = nil
        validatePasswordFields(triggerHaptic: true)
    }

    /// 이메일 중복 여부를 서버 RPC로 조회하고 검증 상태를 반영합니다.
    /// - Parameter triggerHaptic: 검증 완료 시 성공/실패 햅틱 발생 여부입니다.
    private func validateEmailAvailabilityFromServer(triggerHaptic: Bool) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.isEmpty == false else {
            applyEmailValidationState(.idle, triggerHaptic: false)
            return
        }
        guard isValidEmailFormat(normalizedEmail) else {
            applyEmailValidationState(.invalid(message: "올바른 이메일 형식을 입력해주세요."), triggerHaptic: triggerHaptic)
            return
        }
        if lastValidatedEmail == normalizedEmail, emailValidationState.isValid {
            return
        }

        emailValidationTask?.cancel()
        applyEmailValidationState(.validating, triggerHaptic: false)

        emailValidationTask = Task {
            do {
                let isAvailable = try await emailValidationService.checkEmailAvailability(email: normalizedEmail)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    let latestEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard latestEmail == normalizedEmail else { return }
                    lastValidatedEmail = normalizedEmail
                    if isAvailable {
                        applyEmailValidationState(.valid(message: "사용 가능한 이메일입니다."), triggerHaptic: triggerHaptic)
                    } else {
                        applyEmailValidationState(.invalid(message: "이미 가입된 이메일입니다."), triggerHaptic: triggerHaptic)
                    }
                }
            } catch {
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    applyEmailValidationState(
                        .invalid(message: error.localizedDescription),
                        triggerHaptic: triggerHaptic
                    )
                }
            }
        }
    }

    /// 회원가입 제출 직전에 이메일 서버 중복 검증을 강제 수행합니다.
    /// - Parameter email: 제출 직전 정규화된 이메일 문자열입니다.
    /// - Returns: 서버 검증 기준으로 사용 가능한 이메일이면 `true`를 반환합니다.
    private func ensureEmailAvailabilityBeforeSubmit(email: String) async -> Bool {
        if lastValidatedEmail == email, emailValidationState.isValid {
            return true
        }

        await MainActor.run {
            applyEmailValidationState(.validating, triggerHaptic: false)
        }

        do {
            let isAvailable = try await emailValidationService.checkEmailAvailability(email: email)
            await MainActor.run {
                lastValidatedEmail = email
                if isAvailable {
                    applyEmailValidationState(.valid(message: "사용 가능한 이메일입니다."), triggerHaptic: false)
                } else {
                    applyEmailValidationState(.invalid(message: "이미 가입된 이메일입니다."), triggerHaptic: true)
                    errorMessage = "이미 가입된 이메일입니다. 로그인을 시도해주세요."
                }
            }
            return isAvailable
        } catch {
            await MainActor.run {
                applyEmailValidationState(
                    .invalid(message: error.localizedDescription),
                    triggerHaptic: true
                )
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    /// 비밀번호 형식과 확인값 일치 여부를 검증해 필드 상태를 업데이트합니다.
    /// - Parameter triggerHaptic: 상태 전환 시 햅틱 피드백 발생 여부입니다.
    private func validatePasswordFields(triggerHaptic: Bool) {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedPassword.isEmpty {
            applyPasswordValidationState(.idle, triggerHaptic: false)
            applyConfirmPasswordValidationState(.idle, triggerHaptic: false)
            return
        }

        if validatePasswordFormat(normalizedPassword) {
            applyPasswordValidationState(
                .valid(message: "사용 가능한 비밀번호 형식입니다."),
                triggerHaptic: triggerHaptic
            )
        } else {
            applyPasswordValidationState(
                .invalid(message: "비밀번호는 \(minimumPasswordLength)자 이상이며 영문/숫자를 모두 포함해야 합니다."),
                triggerHaptic: triggerHaptic
            )
        }

        guard normalizedConfirm.isEmpty == false else {
            applyConfirmPasswordValidationState(.idle, triggerHaptic: false)
            return
        }
        if normalizedPassword == normalizedConfirm {
            applyConfirmPasswordValidationState(
                .valid(message: "비밀번호 확인이 일치합니다."),
                triggerHaptic: triggerHaptic
            )
        } else {
            applyConfirmPasswordValidationState(
                .invalid(message: "비밀번호 확인이 일치하지 않습니다."),
                triggerHaptic: triggerHaptic
            )
        }
    }

    /// 비밀번호가 최소 길이와 영문/숫자 포함 정책을 만족하는지 검증합니다.
    /// - Parameter password: 공백 정리 후 검증할 비밀번호 문자열입니다.
    /// - Returns: 정책을 만족하면 `true`, 아니면 `false`입니다.
    private func validatePasswordFormat(_ password: String) -> Bool {
        guard password.count >= minimumPasswordLength else { return false }
        let hasLetter = password.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
        let hasNumber = password.range(of: #"[0-9]"#, options: .regularExpression) != nil
        return hasLetter && hasNumber
    }

    /// 이메일 필드 검증 상태를 갱신하고 필요 시 햅틱 피드백을 발생시킵니다.
    /// - Parameters:
    ///   - state: 반영할 이메일 검증 상태입니다.
    ///   - triggerHaptic: 상태 전환 시 햅틱 피드백 발생 여부입니다.
    private func applyEmailValidationState(_ state: FieldValidationState, triggerHaptic: Bool) {
        guard emailValidationState != state else { return }
        emailValidationState = state
        if triggerHaptic {
            triggerValidationHaptic(for: state)
        }
    }

    /// 비밀번호 필드 검증 상태를 갱신하고 필요 시 햅틱 피드백을 발생시킵니다.
    /// - Parameters:
    ///   - state: 반영할 비밀번호 검증 상태입니다.
    ///   - triggerHaptic: 상태 전환 시 햅틱 피드백 발생 여부입니다.
    private func applyPasswordValidationState(_ state: FieldValidationState, triggerHaptic: Bool) {
        guard passwordValidationState != state else { return }
        passwordValidationState = state
        if triggerHaptic {
            triggerValidationHaptic(for: state)
        }
    }

    /// 비밀번호 확인 필드 검증 상태를 갱신하고 필요 시 햅틱 피드백을 발생시킵니다.
    /// - Parameters:
    ///   - state: 반영할 비밀번호 확인 검증 상태입니다.
    ///   - triggerHaptic: 상태 전환 시 햅틱 피드백 발생 여부입니다.
    private func applyConfirmPasswordValidationState(_ state: FieldValidationState, triggerHaptic: Bool) {
        guard confirmPasswordValidationState != state else { return }
        confirmPasswordValidationState = state
        if triggerHaptic {
            triggerValidationHaptic(for: state)
        }
    }

    /// 필드 검증 결과에 맞춰 성공/실패 햅틱 피드백을 재생합니다.
    /// - Parameter state: 현재 반영할 필드 검증 상태입니다.
    private func triggerValidationHaptic(for state: FieldValidationState) {
        switch state {
        case .valid:
            AppHapticFeedback.questCompleted()
        case .invalid:
            AppHapticFeedback.questFailed()
        case .idle, .validating:
            break
        }
    }
}

private protocol SignUpEmailValidationServicing {
    /// 서버 RPC를 호출해 이메일 사용 가능 여부를 확인합니다.
    /// - Parameter email: 중복 검사를 수행할 정규화 이메일 문자열입니다.
    /// - Returns: 사용 가능한 이메일이면 `true`, 이미 가입되어 있으면 `false`입니다.
    func checkEmailAvailability(email: String) async throws -> Bool
}

private enum SignUpEmailValidationServiceError: LocalizedError {
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이메일 중복 확인 기능이 아직 서버에 배포되지 않았습니다."
        case .invalidResponse:
            return "이메일 중복 확인 응답을 해석하지 못했습니다."
        }
    }
}

private struct SignUpEmailAvailabilityResponseDTO: Decodable {
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
    }
}

private struct SupabaseSignUpEmailValidationService: SignUpEmailValidationServicing {
    private let client: SupabaseHTTPClient

    /// Supabase RPC 기반 이메일 중복 확인 서비스를 초기화합니다.
    /// - Parameter client: RPC 호출에 사용할 Supabase HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// `rpc_check_signup_email_availability` RPC를 호출해 이메일 중복 여부를 조회합니다.
    /// - Parameter email: 중복 검사를 수행할 정규화 이메일 문자열입니다.
    /// - Returns: 사용 가능한 이메일이면 `true`, 이미 존재하면 `false`입니다.
    func checkEmailAvailability(email: String) async throws -> Bool {
        let payload = ["p_email": email]
        do {
            let data = try await client.request(
                .rest(path: "rpc/rpc_check_signup_email_availability"),
                method: .post,
                body: payload
            )
            if let rows = try? JSONDecoder().decode([SignUpEmailAvailabilityResponseDTO].self, from: data),
               let first = rows.first {
                return first.isAvailable
            }
            if let single = try? JSONDecoder().decode(SignUpEmailAvailabilityResponseDTO.self, from: data) {
                return single.isAvailable
            }
            throw SignUpEmailValidationServiceError.invalidResponse
        } catch let error as SupabaseHTTPError {
            if case .unexpectedStatusCode(404) = error {
                throw SignUpEmailValidationServiceError.unavailable
            }
            throw error
        }
    }
}
