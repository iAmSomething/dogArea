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

let doc = load("docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

for heading in [
    "# Auth SMTP Provider Selection / DNS / Secret Checklist v1",
    "## 비교 후보",
    "## 결론",
    "## 후보 비교표",
    "## 최종 1안: Resend",
    "## DNS 체크리스트",
    "## Supabase Custom SMTP 설정 체크리스트",
    "## Secret / 설정값 체크리스트",
    "## Rollout 직전 체크리스트",
    "## 공식 소스"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for provider in ["Resend", "Postmark", "SES"] {
    assertTrue(doc.contains(provider), "doc should compare provider \(provider)")
}

for requirement in [
    "SPF",
    "DKIM",
    "DMARC",
    "sender domain",
    "bounce / return-path / custom MAIL FROM",
    "SMTP Host",
    "SMTP Port",
    "SMTP User",
    "SMTP Pass"
] {
    assertTrue(doc.contains(requirement), "doc should include checklist item \(requirement)")
}

assertTrue(doc.contains("DogArea의 **1안은 `Resend`** 로 고정합니다."), "doc should explicitly select Resend as primary provider")
assertTrue(doc.contains("Postmark 미선정 사유"), "doc should explain why Postmark is not primary")
assertTrue(doc.contains("SES 미선정 사유"), "doc should explain why SES is not primary")

for source in [
    "https://resend.com/pricing",
    "https://postmarkapp.com/pricing",
    "https://aws.amazon.com/ses/pricing/",
    "https://supabase.com/docs/guides/auth/auth-smtp"
] {
    assertTrue(doc.contains(source), "doc should include source \(source)")
}

assertTrue(readme.contains("docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md"), "README should link auth smtp provider checklist doc")
assertTrue(iosPRCheck.contains("auth_smtp_provider_checklist_unit_check.swift"), "ios_pr_check should run auth smtp provider unit check")
assertTrue(backendPRCheck.contains("auth_smtp_provider_checklist_unit_check.swift"), "backend_pr_check should run auth smtp provider unit check")

print("PASS: auth smtp provider checklist unit checks")
