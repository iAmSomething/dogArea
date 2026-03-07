import Foundation

@inline(__always)
/// 조건이 거짓이면 즉시 실패 종료합니다.
/// - Parameters:
///   - condition: 반드시 참이어야 하는 조건식입니다.
///   - message: 실패 시 stderr에 출력할 설명입니다.
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 상대 경로의 텍스트 파일을 읽어 문자열로 반환합니다.
/// - Parameter relativePath: 프로젝트 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 문자열로 디코딩한 파일 내용입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let models = load("dogArea/Source/Domain/Auth/Models/AuthMailActionModels.swift")
let stateMachine = load("dogArea/Source/Domain/Auth/Services/AuthMailActionStateMachine.swift")
let store = load("dogArea/Source/UserDefaultsSupport/AuthMailActionStateStore.swift")
let authMailService = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthMailActionService.swift")
let signupView = load("dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift")
let signupCard = load("dogArea/Views/SigningView/Components/AuthMailActionStatusCardView.swift")
let metrics = load("dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift")
let readme = load("README.md")
let doc = load("docs/auth-mail-resend-state-machine-v1.md")

assertTrue(models.contains("enum AuthMailActionType: String, Codable, CaseIterable"), "auth mail action type enum should exist")
assertTrue(models.contains("case signupConfirmation") && models.contains("case passwordReset") && models.contains("case emailChange"), "all three auth mail action types should be defined")
assertTrue(models.contains("enum AuthMailResendState: Equatable") && models.contains("case idle") && models.contains("case sending") && models.contains("case sent") && models.contains("case cooldown") && models.contains("case rateLimited") && models.contains("case failed"), "resend state machine should define idle/sending/sent/cooldown/rate_limited/failed")
assertTrue(models.contains("struct AuthMailActionKey: Hashable, Codable"), "action key model should be defined")
assertTrue(models.contains("var storageKey: String"), "action key should provide storageKey")

assertTrue(stateMachine.contains("protocol AuthMailActionStateStoring"), "state store protocol should exist")
assertTrue(stateMachine.contains("protocol AuthMailActionStateManaging"), "state machine protocol should exist")
assertTrue(stateMachine.contains("final class AuthMailActionStateMachine"), "state machine implementation should exist")
assertTrue(stateMachine.contains("func recordSuccess(") && stateMachine.contains("func recordRateLimited("), "state machine should record success and rate limits")
assertTrue(stateMachine.contains("store.removeSnapshot(for: key)"), "expired snapshots should be removed")

assertTrue(store.contains("final class AuthMailActionStateStore: AuthMailActionStateStoring"), "UserDefaults auth mail store should exist")
assertTrue(store.contains("namespace: String = \"auth.mail.resend.snapshot.v1\""), "auth mail store should use dedicated namespace")

assertTrue(authMailService.contains("enum AuthMailDispatchRequest: Equatable"), "mail dispatch request enum should exist")
assertTrue(authMailService.contains("case signupConfirmation") && authMailService.contains("case passwordReset") && authMailService.contains("case emailChange"), "dispatch request should recognize signup/reset/email change")
assertTrue(authMailService.contains(".auth(path: \"resend\")") && authMailService.contains(".auth(path: \"recover\")"), "mail dispatch service should define resend/recover endpoints")
assertTrue(authMailService.contains("SupabaseAuthError.rateLimited"), "mail dispatch service should map 429 to SupabaseAuthError.rateLimited")

assertTrue(signupView.contains("@State private var signUpSheetMode: SignUpSheetMode = .form"), "signup sheet should keep explicit form/confirmation mode")
assertTrue(signupView.contains("@State private var signUpMailState: AuthMailResendState = .idle"), "signup sheet should keep auth mail resend state")
assertTrue(signupView.contains("signUpConfirmationContent") && signupView.contains("continueToProfileSetup()"), "signup sheet should present a confirmation step before continuing")
assertTrue(signupView.contains("resendSignupConfirmationMail()"), "signup sheet should expose explicit resend action")
assertTrue(signupView.contains("allowMailActionRequest(for: actionKey, surface: \"signup_submit\")"), "signup submit should be guarded by resend state machine")
assertTrue(signupView.contains("AuthMailActionStatusCardView(") && signupView.contains("signup.mail.resend"), "signup sheet should render auth mail status card with resend CTA")
assertTrue(signupView.contains("-UITest.SignUpMailStateStub"), "signup sheet should support UI test override for mail states")

assertTrue(signupCard.contains("struct AuthMailActionStatusCardView: View"), "signup auth mail status card view should exist")
assertTrue(signupCard.contains("프로필 입력 계속"), "auth mail status card should support continue CTA")

assertTrue(metrics.contains("case authMailActionSucceeded") && metrics.contains("case authMailActionRateLimited") && metrics.contains("case authMailActionFailed") && metrics.contains("case authMailActionSuppressed"), "metric tracker should include auth mail events")

assertTrue(readme.contains("docs/auth-mail-resend-state-machine-v1.md"), "README should index auth mail resend doc")
assertTrue(doc.contains("idle") && doc.contains("sending") && doc.contains("sent") && doc.contains("cooldown") && doc.contains("rate_limited") && doc.contains("failed"), "doc should describe full resend state machine")
assertTrue(doc.contains("Retry-After") && doc.contains("fallback cooldown"), "doc should define retry-after precedence and fallback cooldown")
assertTrue(doc.contains("sheet dismiss / reopen") && doc.contains("background 복귀"), "doc should define persistence and resume behavior")
assertTrue(doc.contains("429") && doc.contains("네트워크 실패") && doc.contains("중복 탭"), "doc should include QA scenarios for 429/network/duplicate tap")

print("PASS: auth mail resend state machine unit checks")
