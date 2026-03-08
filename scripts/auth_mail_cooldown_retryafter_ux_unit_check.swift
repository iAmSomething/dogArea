import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 참이어야 하는 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 텍스트 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/auth-mail-cooldown-retry-after-ux-v1.md")
let stateDoc = load("docs/auth-mail-resend-state-machine-v1.md")
let models = load("dogArea/Source/Domain/Auth/Models/AuthMailActionModels.swift")
let service = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthMailActionService.swift")
let signupView = load("dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

for heading in [
    "# Auth Mail Cooldown / Retry-After UX v1",
    "## 액션별 cooldown 정책",
    "## 상태 모델",
    "## Duplicate Tap / Duplicate Request Guard",
    "## Retry-After 우선순위",
    "## 낙관적 전송 금지",
    "## 사용자 문구 원칙",
    "## Metric / Log 기준",
    "## QA 시나리오",
    "## DoD"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for requiredLine in [
    "signup_confirmation::<email>::signup_sheet",
    "password_reset::<email>::reset_sheet",
    "email_change::<email>::settings_email_change",
    "회원가입 확인 메일 | `signup_confirmation::<email>::signup_sheet` | `signup_sheet` | `60s` | `인증 메일 다시 보내기`",
    "비밀번호 재설정 메일 | `password_reset::<email>::reset_sheet` | `password_reset_sheet` | `75s` | `재설정 메일 다시 보내기`",
    "이메일 변경 확인 메일 | `email_change::<email>::settings_email_change` | `settings_email_change` | `90s` | `변경 확인 메일 다시 보내기`",
    "중복 탭 방지 규칙",
    "duplicate_suppressed=true",
    "서버 응답 `Retry-After`",
    "실제 서버 `2xx` 응답을 받은 뒤에만 `sent` 상태 진입",
    "`SMTP`",
    "`over_email_send_rate_limit`"
] {
    assertTrue(doc.contains(requiredLine), "doc should include rule \(requiredLine)")
}

for qaScenario in [
    "### 1. signup 성공",
    "### 2. signup `429`",
    "### 3. password reset `429`",
    "### 4. email change `429`",
    "### 5. 네트워크 실패",
    "### 6. 중복 탭",
    "### 7. dismiss / reopen",
    "### 8. background 복귀"
] {
    assertTrue(doc.contains(qaScenario), "doc should include QA scenario \(qaScenario)")
}

assertTrue(stateDoc.contains("password reset") && stateDoc.contains("email change"), "state machine doc should already mention reset and email change flows")
assertTrue(models.contains("case passwordReset = \"password_reset\"") && models.contains("return 75") && models.contains("return 90"), "auth models should define password reset and email change fallback cooldowns")
assertTrue(models.contains("재설정 메일 다시 보내기") && models.contains("변경 확인 메일 다시 보내기"), "auth models should define action-specific resend copy")
assertTrue(service.contains("Retry-After") && service.contains("SupabaseAuthError.rateLimited"), "service should prioritize Retry-After and map 429")
assertTrue(signupView.contains("allowMailActionRequest(for: actionKey, surface: \"signup_submit\")") && signupView.contains("duplicate_suppressed"), "signup view should suppress duplicate mail actions and track payload")

assertTrue(readme.contains("docs/auth-mail-cooldown-retry-after-ux-v1.md"), "README should index auth mail cooldown doc")
assertTrue(iosPRCheck.contains("auth_mail_cooldown_retryafter_ux_unit_check.swift"), "ios_pr_check should run auth mail cooldown unit check")
assertTrue(backendPRCheck.contains("auth_mail_cooldown_retryafter_ux_unit_check.swift"), "backend_pr_check should run auth mail cooldown unit check")

print("PASS: auth mail cooldown retry-after UX unit checks")
