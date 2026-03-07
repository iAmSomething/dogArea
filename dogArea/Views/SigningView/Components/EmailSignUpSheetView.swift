//
//  EmailSignUpSheetView.swift
//  dogArea
//

import Foundation
import SwiftUI

struct EmailSignUpSheetView: View {
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

    private enum SignUpSheetMode {
        case form
        case confirmation(outcome: AuthUseCaseOutcome, email: String)
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: SignUpField?

    @State private var email: String
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var loading: Bool = false
    @State private var isMailActionDispatching: Bool = false
    @State private var errorMessage: String? = nil
    @State private var emailValidationState: FieldValidationState = .idle
    @State private var passwordValidationState: FieldValidationState = .idle
    @State private var confirmPasswordValidationState: FieldValidationState = .idle
    @State private var lastValidatedEmail: String = ""
    @State private var emailValidationTask: Task<Void, Never>? = nil
    @State private var signUpSheetMode: SignUpSheetMode = .form
    @State private var signUpMailState: AuthMailResendState = .idle
    @State private var mailActionTickerTask: Task<Void, Never>? = nil

    private let authUseCase: AuthUseCaseProtocol
    private let emailValidationService: SignUpEmailValidationServicing
    private let authMailActionService: AuthMailActionDispatching
    private let authMailStateMachine: AuthMailActionStateManaging
    private let metricTracker: AppMetricTracker
    private let onOutcome: (AuthUseCaseOutcome) -> Void
    private let minimumPasswordLength: Int = 8

    /// 회원가입 시트의 초기 입력값과 인증 결과 전달 핸들러를 설정합니다.
    /// - Parameters:
    ///   - initialEmail: 로그인 화면에서 전달받은 초기 이메일 값입니다.
    ///   - authUseCase: 이메일 회원가입 요청을 수행할 인증 유즈케이스입니다.
    ///   - emailValidationService: 이메일 중복 확인 RPC 요청을 수행하는 검증 서비스입니다.
    ///   - authMailActionService: 인증 메일 resend 요청을 수행하는 서비스입니다.
    ///   - authMailStateMachine: 메일 resend state machine을 계산하는 서비스입니다.
    ///   - metricTracker: 메일 액션 telemetry를 전송하는 metric 추적기입니다.
    ///   - onOutcome: 회원가입 성공 시 상위 화면으로 전달할 인증 결과 콜백입니다.
    init(
        initialEmail: String,
        authUseCase: AuthUseCaseProtocol,
        emailValidationService: SignUpEmailValidationServicing = SupabaseSignUpEmailValidationService(),
        authMailActionService: AuthMailActionDispatching = SupabaseAuthMailActionService(),
        authMailStateMachine: AuthMailActionStateManaging = AuthMailActionStateMachine(),
        metricTracker: AppMetricTracker = .shared,
        onOutcome: @escaping (AuthUseCaseOutcome) -> Void
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let previewEmail: String?
        if let previewIndex = arguments.firstIndex(of: "-UITest.SignUpMailPreviewEmail"),
           arguments.indices.contains(previewIndex + 1) {
            let rawPreviewEmail = arguments[previewIndex + 1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            previewEmail = rawPreviewEmail.isEmpty ? nil : rawPreviewEmail
        } else {
            previewEmail = nil
        }

        let resolvedInitialEmail = previewEmail ?? initialEmail
        self._email = State(initialValue: resolvedInitialEmail)
        if let previewEmail {
            self._signUpSheetMode = State(
                initialValue: .confirmation(
                    outcome: AuthUseCaseOutcome(
                        identity: AuthenticatedUserIdentity(
                            userId: "uitest-signup-preview",
                            email: previewEmail
                        ),
                        displayNameHint: nil,
                        requiresOnboarding: true
                    ),
                    email: previewEmail
                )
            )
        } else {
            self._signUpSheetMode = State(initialValue: .form)
        }
        self.authUseCase = authUseCase
        self.emailValidationService = emailValidationService
        self.authMailActionService = authMailActionService
        self.authMailStateMachine = authMailStateMachine
        self.metricTracker = metricTracker
        self.onOutcome = onOutcome
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TitleTextView(title: "이메일 회원가입", subTitle: "가입 정보를 입력해주세요.")

                switch signUpSheetMode {
                case .form:
                    signUpFormContent
                case .confirmation(_, let confirmedEmail):
                    signUpConfirmationContent(email: confirmedEmail)
                }

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
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 2, height: 2)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("screen.signup")
            }
            .onAppear {
                refreshSignUpMailState()
                startMailActionTicker()
            }
            .onChange(of: focusedField) { oldValue, newValue in
                handleFocusTransition(from: oldValue, to: newValue)
            }
            .onDisappear {
                emailValidationTask?.cancel()
                mailActionTickerTask?.cancel()
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

    private var signUpFormContent: some View {
        VStack(spacing: 12) {
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
                .disabled(loading || isMailActionDispatching)
            }
            .padding(.horizontal, 20)
            .appCardSurface()
            .padding(.horizontal, 16)

            if shouldShowFormMailStatusCard, let email = activeMailActionEmail {
                AuthMailActionStatusCardView(
                    actionType: .signupConfirmation,
                    email: email,
                    state: signUpMailState,
                    messageOverride: nil,
                    resendAccessibilityIdentifier: "signup.mail.resend",
                    continueAccessibilityIdentifier: nil,
                    onResend: {
                        resendSignupConfirmationMail()
                    },
                    onContinue: nil
                )
                .padding(.horizontal, 16)
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 2, height: 2)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("signup.mail.status")
                }
            }
        }
    }

    /// 회원가입 성공 후 메일 resend 상태와 프로필 입력 진입 버튼을 구성합니다.
    /// - Parameter email: 방금 인증 메일을 발송한 정규화 이메일입니다.
    /// - Returns: 성공 직후 확인/재발송/계속 진행 UI를 포함한 확인 콘텐츠입니다.
    @ViewBuilder
    private func signUpConfirmationContent(email: String) -> some View {
        AuthMailActionStatusCardView(
            actionType: .signupConfirmation,
            email: email,
            state: signUpMailState,
            messageOverride: confirmationMessageOverride(for: email),
            resendAccessibilityIdentifier: "signup.mail.resend",
            continueAccessibilityIdentifier: "signup.mail.continue",
            onResend: {
                resendSignupConfirmationMail()
            },
            onContinue: {
                continueToProfileSetup()
            }
        )
        .padding(.horizontal, 16)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 2, height: 2)
                .allowsHitTesting(false)
                .accessibilityIdentifier("signup.mail.status")
        }
    }

    /// 이메일 회원가입을 실행하고 성공 시 메일 확인 단계를 거쳐 상위 인증 플로우로 결과를 전달합니다.
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

        guard let actionKey = makeSignUpMailActionKey(for: normalizedEmail),
              allowMailActionRequest(for: actionKey, surface: "signup_submit") else {
            return
        }

        loading = true
        signUpMailState = .sending

        Task {
            let isEmailAvailable = await ensureEmailAvailabilityBeforeSubmit(email: normalizedEmail)
            guard isEmailAvailable else {
                await MainActor.run {
                    loading = false
                    refreshSignUpMailState()
                }
                return
            }
            do {
                let outcome = try await authUseCase.execute(
                    .emailSignUp(email: normalizedEmail, password: normalizedPassword)
                )
                await MainActor.run {
                    loading = false
                    signUpSheetMode = .confirmation(outcome: outcome, email: normalizedEmail)
                    signUpMailState = authMailStateMachine.recordSuccess(
                        for: actionKey,
                        now: Date(),
                        fallbackCooldownSeconds: actionKey.actionType.fallbackCooldownSeconds
                    )
                    trackAuthMailEvent(
                        .authMailActionSucceeded,
                        actionType: actionKey.actionType,
                        surface: "signup_submit",
                        retryAfterSeconds: nil,
                        duplicateSuppressed: false
                    )
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    loading = false
                    handleMailActionFailure(error, for: actionKey, surface: "signup_submit")
                }
            }
        }
    }

    /// 회원가입 확인 메일 resend 요청을 실행하고 상태 기계를 갱신합니다.
    private func resendSignupConfirmationMail() {
        guard let actionKey = activeMailActionKey else { return }
        guard allowMailActionRequest(for: actionKey, surface: "signup_resend") else {
            return
        }

        errorMessage = nil
        isMailActionDispatching = true
        signUpMailState = .sending

        Task {
            do {
                try await authMailActionService.send(.signupConfirmation(email: actionKey.recipient))
                await MainActor.run {
                    isMailActionDispatching = false
                    signUpMailState = authMailStateMachine.recordSuccess(
                        for: actionKey,
                        now: Date(),
                        fallbackCooldownSeconds: actionKey.actionType.fallbackCooldownSeconds
                    )
                    trackAuthMailEvent(
                        .authMailActionSucceeded,
                        actionType: actionKey.actionType,
                        surface: "signup_resend",
                        retryAfterSeconds: nil,
                        duplicateSuppressed: false
                    )
                }
            } catch {
                await MainActor.run {
                    isMailActionDispatching = false
                    handleMailActionFailure(error, for: actionKey, surface: "signup_resend")
                }
            }
        }
    }

    /// 메일 확인 단계를 마친 뒤 상위 인증 플로우로 결과를 전달하고 시트를 닫습니다.
    private func continueToProfileSetup() {
        guard case let .confirmation(outcome, _) = signUpSheetMode else { return }
        onOutcome(outcome)
        dismiss()
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

    /// 이메일 입력값 변경 시 기존 서버 검증 상태를 초기화하고 메일 resend 상태를 다시 계산합니다.
    private func handleEmailInputChanged() {
        lastValidatedEmail = ""
        emailValidationTask?.cancel()
        if case .idle = emailValidationState {
            refreshSignUpMailState()
            return
        }
        emailValidationState = .idle
        refreshSignUpMailState()
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

    /// 현재 입력/확인 단계에 대응하는 메일 resend 상태를 다시 계산합니다.
    private func refreshSignUpMailState() {
        guard let actionKey = activeMailActionKey else {
            if isMailActionDispatching == false {
                signUpMailState = .idle
            }
            return
        }
        if let uiTestOverride = resolvedUITestMailStateOverride() {
            signUpMailState = uiTestOverride
            return
        }
        if isMailActionDispatching || loading {
            return
        }
        signUpMailState = authMailStateMachine.state(for: actionKey, now: Date())
    }

    /// cooldown/rate-limit 카운트다운이 자연스럽게 줄어들도록 1초 주기 ticker를 시작합니다.
    private func startMailActionTicker() {
        mailActionTickerTask?.cancel()
        mailActionTickerTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    refreshSignUpMailState()
                }
            }
        }
    }

    /// 메일 액션 요청이 현재 시점에 허용되는지 확인하고, 막힌 경우 사용자/metric/log 상태를 함께 갱신합니다.
    /// - Parameters:
    ///   - key: 전송 여부를 판정할 메일 액션 키입니다.
    ///   - surface: 요청 진입 화면/버튼을 식별할 표면 이름입니다.
    /// - Returns: 현재 요청을 보내도 되면 `true`, 아니면 `false`입니다.
    private func allowMailActionRequest(for key: AuthMailActionKey, surface: String) -> Bool {
        if loading || isMailActionDispatching {
            trackAuthMailEvent(
                .authMailActionSuppressed,
                actionType: key.actionType,
                surface: surface,
                retryAfterSeconds: signUpMailState.remainingSeconds,
                duplicateSuppressed: true
            )
            return false
        }

        if let uiTestOverride = resolvedUITestMailStateOverride() {
            signUpMailState = uiTestOverride
            if uiTestOverride.isRequestAllowed == false {
                errorMessage = uiTestOverride.message(for: key.actionType, email: key.recipient)
                    ?? "잠시 후 다시 시도해주세요."
                return false
            }
        }

        let resolvedState = authMailStateMachine.state(for: key, now: Date())
        signUpMailState = resolvedState
        guard resolvedState.isRequestAllowed else {
            errorMessage = resolvedState.message(for: key.actionType, email: key.recipient)
                ?? "잠시 후 다시 시도해주세요."
            AppHapticFeedback.questFailed()
            trackAuthMailEvent(
                .authMailActionSuppressed,
                actionType: key.actionType,
                surface: surface,
                retryAfterSeconds: resolvedState.remainingSeconds,
                duplicateSuppressed: true
            )
            return false
        }
        return true
    }

    /// 서버 응답 오류를 resend 상태 기계와 사용자 문구로 변환합니다.
    /// - Parameters:
    ///   - error: 서버 또는 네트워크에서 발생한 오류입니다.
    ///   - key: 상태를 갱신할 메일 액션 키입니다.
    ///   - surface: 오류가 발생한 화면/버튼 진입점입니다.
    private func handleMailActionFailure(
        _ error: Error,
        for key: AuthMailActionKey,
        surface: String
    ) {
        if case let SupabaseAuthError.rateLimited(_, _, retryAfterSeconds) = error {
            signUpMailState = authMailStateMachine.recordRateLimited(
                for: key,
                retryAfterSeconds: retryAfterSeconds,
                now: Date(),
                fallbackCooldownSeconds: key.actionType.fallbackCooldownSeconds
            )
            errorMessage = signUpMailState.message(for: key.actionType, email: key.recipient)
            trackAuthMailEvent(
                .authMailActionRateLimited,
                actionType: key.actionType,
                surface: surface,
                retryAfterSeconds: retryAfterSeconds,
                duplicateSuppressed: false
            )
        } else {
            let failureMessage = normalizedMailActionFailureMessage(error, actionType: key.actionType)
            signUpMailState = .failed(message: failureMessage)
            errorMessage = failureMessage
            trackAuthMailEvent(
                .authMailActionFailed,
                actionType: key.actionType,
                surface: surface,
                retryAfterSeconds: nil,
                duplicateSuppressed: false
            )
        }
        AppHapticFeedback.questFailed()
    }

    /// 현재 confirmation 단계에서 idle 상태가 되더라도 성공 안내 문구를 유지하기 위한 override를 생성합니다.
    /// - Parameter email: confirmation 상태의 대상 이메일입니다.
    /// - Returns: idle일 때만 유지할 성공 설명 문구이며, 그 외 상태면 `nil`입니다.
    private func confirmationMessageOverride(for email: String) -> String? {
        if case .idle = signUpMailState {
            return AuthMailActionType.signupConfirmation.successDescription(for: email)
        }
        return nil
    }

    /// 현재 입력/confirmation 단계에 대응하는 메일 액션 고유 키를 생성합니다.
    /// - Parameter email: 키 생성에 사용할 정규화 이메일입니다.
    /// - Returns: 이메일이 비어 있지 않으면 signup confirmation 키를 반환합니다.
    private func makeSignUpMailActionKey(for email: String) -> AuthMailActionKey? {
        guard email.isEmpty == false else { return nil }
        return AuthMailActionKey(
            actionType: .signupConfirmation,
            recipient: email,
            context: "signup_sheet"
        )
    }

    /// 현재 화면 상태에서 resend 상태를 계산해야 하는 대상 이메일을 반환합니다.
    /// - Returns: confirmation 단계 이메일 또는 현재 입력 이메일의 정규화 값입니다.
    private var activeMailActionEmail: String? {
        switch signUpSheetMode {
        case .form:
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalizedEmail.isEmpty ? nil : normalizedEmail
        case .confirmation(_, let email):
            return email
        }
    }

    /// 현재 화면 상태에서 사용할 signup confirmation 메일 액션 키를 반환합니다.
    private var activeMailActionKey: AuthMailActionKey? {
        guard let activeMailActionEmail else { return nil }
        return makeSignUpMailActionKey(for: activeMailActionEmail)
    }

    /// form 단계에서 상태 카드 노출이 필요한지 여부를 반환합니다.
    private var shouldShowFormMailStatusCard: Bool {
        guard case .form = signUpSheetMode else { return false }
        guard activeMailActionEmail != nil else { return false }
        if case .idle = signUpMailState {
            return false
        }
        return true
    }

    /// 오류 객체를 사용자용 메일 액션 실패 문구로 정규화합니다.
    /// - Parameters:
    ///   - error: 정규화할 원본 오류입니다.
    ///   - actionType: 사용자 문구를 결정할 메일 액션 타입입니다.
    /// - Returns: 내부 운영 용어를 제거한 사용자용 실패 안내 문구입니다.
    private func normalizedMailActionFailureMessage(_ error: Error, actionType: AuthMailActionType) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.isEmpty == false,
              description.contains("SMTP") == false,
              description.contains("Rate Limit") == false else {
            return actionType.defaultFailureMessage()
        }
        return description
    }

    /// UI 테스트 런타임 인자로 signup 메일 상태를 강제로 주입해야 하는지 확인합니다.
    /// - Returns: 테스트 인자가 유효하면 강제할 resend 상태를, 아니면 `nil`을 반환합니다.
    private func resolvedUITestMailStateOverride() -> AuthMailResendState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-UITest.SignUpMailStateStub"),
              activeMailActionEmail != nil,
              let rawState = uiTestArgumentValue(after: "-UITest.SignUpMailStateStub") else {
            return nil
        }
        let remainingSeconds = max(Int(uiTestArgumentValue(after: "-UITest.SignUpMailRemaining") ?? "48") ?? 48, 1)
        switch rawState {
        case "sent":
            return .sent(remainingSeconds: remainingSeconds)
        case "cooldown":
            return .cooldown(remainingSeconds: remainingSeconds)
        case "rate_limited":
            return .rateLimited(remainingSeconds: remainingSeconds)
        case "failed":
            return .failed(message: "메일을 다시 보내지 못했습니다. 잠시 후 다시 시도해주세요.")
        default:
            return nil
        }
    }

    /// 특정 UI 테스트 런타임 인자 뒤에 이어지는 값을 읽어옵니다.
    /// - Parameter flag: 값을 읽고 싶은 런타임 인자 플래그입니다.
    /// - Returns: 다음 위치에 값이 있으면 문자열을, 없으면 `nil`을 반환합니다.
    private func uiTestArgumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// 메일 액션 결과를 metric/log 파이프라인으로 보냅니다.
    /// - Parameters:
    ///   - event: 기록할 메트릭 이벤트 타입입니다.
    ///   - actionType: 메일 액션 종류입니다.
    ///   - surface: 사용자가 요청을 발생시킨 화면/진입점입니다.
    ///   - retryAfterSeconds: 서버 또는 상태기계가 계산한 남은 대기 시간입니다.
    ///   - duplicateSuppressed: 중복 탭/중복 요청이 억제된 경우 `true`입니다.
    private func trackAuthMailEvent(
        _ event: AppMetricEvent,
        actionType: AuthMailActionType,
        surface: String,
        retryAfterSeconds: Int?,
        duplicateSuppressed: Bool
    ) {
        let payload: [String: String] = [
            "action_type": actionType.analyticsKey,
            "surface": surface,
            "retry_after_seconds": retryAfterSeconds.map(String.init) ?? "none",
            "duplicate_suppressed": duplicateSuppressed ? "true" : "false"
        ]
        metricTracker.track(event, payload: payload)
        #if DEBUG
        print("[AuthMailMetric] event=\(event.rawValue) action=\(actionType.analyticsKey) surface=\(surface) retryAfter=\(retryAfterSeconds.map(String.init) ?? "none") duplicateSuppressed=\(duplicateSuppressed)")
        #endif
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

protocol SignUpEmailValidationServicing {
    /// 서버 RPC를 호출해 이메일 사용 가능 여부를 확인합니다.
    /// - Parameter email: 중복 검사를 수행할 정규화 이메일 문자열입니다.
    /// - Returns: 사용 가능한 이메일이면 `true`, 이미 가입되어 있으면 `false`입니다.
    func checkEmailAvailability(email: String) async throws -> Bool
}

enum SignUpEmailValidationServiceError: LocalizedError {
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

struct SignUpEmailAvailabilityResponseDTO: Decodable {
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
    }
}

struct SupabaseSignUpEmailValidationService: SignUpEmailValidationServicing {
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
