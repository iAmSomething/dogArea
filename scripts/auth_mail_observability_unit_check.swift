import Foundation

/// 조건이 거짓이면 실패 메시지를 stderr에 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 조건이 거짓일 때 출력할 오류 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/auth-mail-observability-metric-alert-request-key-v1.md")
let tracker = load("dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift")
let runbook = load("docs/backend-edge-incident-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

for heading in [
    "# Auth Mail Observability Metric / Alert / Request Key v1",
    "## 최소 수집 대상",
    "## Canonical metric event 이름",
    "## Request Key / Correlation 기준",
    "## Dashboard 최소 패널",
    "## Alert 초안",
    "## 사용자 문의 대응 필드"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for action in ["signup_confirmation", "password_reset", "email_change"] {
    assertTrue(doc.contains(action), "doc should include action_type \(action)")
}

for key in ["request_id", "mail_action_key", "provider_message_id", "provider_event_id", "recipient_hash"] {
    assertTrue(doc.contains("`\(key)`"), "doc should define key \(key)")
}

for event in [
    "auth_mail_send_attempted",
    "auth_mail_send_accepted",
    "auth_mail_action_rate_limited",
    "auth_mail_action_failed",
    "auth_mail_action_suppressed",
    "auth_mail_provider_bounce",
    "auth_mail_provider_reject",
    "auth_mail_provider_deferred"
] {
    assertTrue(doc.contains("`\(event)`"), "doc should include event \(event)")
    let enumCase = event
        .split(separator: "_")
        .enumerated()
        .map { index, component in
            index == 0 ? String(component) : component.prefix(1).uppercased() + component.dropFirst()
        }
        .joined()
    assertTrue(tracker.contains("case \(enumCase) = \"\(event)\""), "AppMetricTracker should define \(event)")
}

for requirement in [
    "시간당 발송 수",
    "action별 성공률",
    "429 비율",
    "bounce / reject / deferred 비율",
    "retry_after_seconds 분포"
] {
    assertTrue(doc.contains(requirement), "doc should define dashboard requirement \(requirement)")
}

for alertRule in [
    "signup confirmation success rate `< 97%` for `15m`",
    "`429 ratio > 5%` for `15m`",
    "`bounce ratio > 2%` for `30m`",
    "`reject ratio > 3%` for `30m`"
] {
    assertTrue(doc.contains(alertRule), "doc should define alert \(alertRule)")
}

assertTrue(runbook.contains("### auth mail / deliverability"), "incident runbook should include auth mail deliverability section")
for field in ["request_id", "mail_action_key", "provider_message_id", "provider_event_id", "retry_after_seconds"] {
    assertTrue(runbook.contains("`\(field)`"), "incident runbook should mention \(field)")
}

assertTrue(readme.contains("docs/auth-mail-observability-metric-alert-request-key-v1.md"), "README should index auth mail observability doc")
assertTrue(iosPRCheck.contains("auth_mail_observability_unit_check.swift"), "ios_pr_check should run auth mail observability unit check")
assertTrue(backendPRCheck.contains("auth_mail_observability_unit_check.swift"), "backend_pr_check should run auth mail observability unit check")

print("PASS: auth mail observability unit checks")
