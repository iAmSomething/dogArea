import Foundation

/// 조건이 거짓이면 stderr로 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/auth-abuse-guard-policy-v1.md")
let captchaDoc = load("docs/auth-captcha-insertion-fallback-ux-v1.md")
let observabilityDoc = load("docs/auth-mail-observability-metric-alert-request-key-v1.md")
let serviceMailDoc = load("docs/auth-service-mail-channel-separation-policy-v1.md")
let config = load("supabase/config.toml")
let readme = load("README.md")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for heading in [
    "# Auth Abuse Guard Policy v1",
    "## CAPTCHA 정책",
    "## 운영 rate limit 초기값",
    "## 상향 / 하향 기준",
    "## 자동 완화 / 수동 대응 기준",
    "## 정상 사용자 보호 원칙",
    "## 관측성 기준",
    "## 앱 / 설정 / 운영 정합성 규칙",
    "## QA 시나리오",
    "## DoD"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for action in [
    "회원가입",
    "비밀번호 재설정",
    "이메일 변경",
    "초대 메일"
] {
    assertTrue(doc.contains(action), "doc should describe action \(action)")
}

for requiredLine in [
    "`signup`: **step-up CAPTCHA 채택**",
    "`password reset`: **step-up CAPTCHA 채택**",
    "`email change`: **조건부 step-up CAPTCHA 채택**",
    "`invite`: auth 경로가 아니라 `Service Mail API` 경로",
    "회원가입 확인 메일 | `60s` | `10 requests / 5m / IP` | `3 sends / 30m / email` | `120 sends / h / project` | step-up",
    "비밀번호 재설정 메일 | `90s` | `8 requests / 5m / IP` | `3 sends / 30m / email` | `90 sends / h / project` | step-up, signup보다 보수적",
    "이메일 변경 확인 메일 | `120s` | `6 requests / 5m / IP` | `2 sends / 30m / email` | `60 sends / h / project` | signed-in step-up only",
    "signup `429 ratio > 5% for 15m`",
    "local `supabase/config.toml` 값은 local CLI 테스트용이며 production canonical 값이 아닙니다.",
    "EmailSignUpSheetView",
    "duplicate_suppressed=true"
] {
    assertTrue(doc.contains(requiredLine), "doc should include rule \(requiredLine)")
}

for metric in [
    "시간당 auth mail 발송 수",
    "endpoint별 `429 ratio`",
    "같은 IP가 다수 이메일 대상으로 요청한 횟수",
    "같은 이메일에 대한 짧은 시간 내 반복 요청",
    "provider `bounce / reject / deferred`",
    "captcha step-up presented / completed / cancelled / failed"
] {
    assertTrue(doc.contains(metric), "doc should include metric \(metric)")
}

assertTrue(captchaDoc.contains("always-on CAPTCHA 금지"), "captcha doc should define always-on ban")
assertTrue(observabilityDoc.contains("auth_mail_action_rate_limited"), "observability doc should define rate limit metric")
assertTrue(serviceMailDoc.contains("초대 메일 | `Service Mail API`"), "service mail doc should classify invite mail separately")
assertTrue(config.contains("[auth.rate_limit]"), "config should define auth rate limit section")
assertTrue(config.contains("# [auth.captcha]"), "config should contain auth captcha section reference")

assertTrue(readme.contains("docs/auth-abuse-guard-policy-v1.md"), "README should index auth abuse guard policy doc")
assertTrue(backendPRCheck.contains("auth_abuse_guard_policy_unit_check.swift"), "backend_pr_check should run auth abuse guard policy unit check")
assertTrue(iosPRCheck.contains("auth_abuse_guard_policy_unit_check.swift"), "ios_pr_check should run auth abuse guard policy unit check")

print("PASS: auth abuse guard policy unit checks")
