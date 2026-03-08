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

/// 저장소 루트 기준 상대 경로의 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/auth-service-mail-channel-separation-policy-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

for heading in [
    "# Auth Service Mail Channel Separation Policy v1",
    "## 메일 종류 분류표",
    "## Auth 메일 경로 제한",
    "## Service Mail Path 초안",
    "## 발신 도메인 / 발신자 정책",
    "## Secret / Ownership 분리 원칙",
    "## 운영 위험 분리",
    "## 설정 화면 연계 기준",
    "## Service Mail 도입 체크리스트",
    "## DoD"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for mailType in [
    "회원가입 확인 메일",
    "비밀번호 재설정 메일",
    "이메일 변경 확인 메일",
    "초대 메일",
    "고객지원 문의 회신 메일",
    "버그리포트 접수 메일",
    "버그리포트 회신 메일",
    "운영 공지 메일",
    "마케팅 / 리텐션 메일"
] {
    assertTrue(doc.contains(mailType), "doc should classify \(mailType)")
}

for requiredChannelRule in [
    "회원가입 확인 메일 | `Auth SMTP`",
    "비밀번호 재설정 메일 | `Auth SMTP`",
    "이메일 변경 확인 메일 | `Auth SMTP`",
    "초대 메일 | `Service Mail API`",
    "고객지원 문의 회신 메일 | `Service Mail API`",
    "버그리포트 접수 메일 | `Service Mail API`",
    "버그리포트 회신 메일 | `Service Mail API`",
    "운영 공지 메일 | `Service Mail API`",
    "마케팅 / 리텐션 메일 | `Service Mail API`"
] {
    assertTrue(doc.contains(requiredChannelRule), "doc should define channel rule \(requiredChannelRule)")
}

for requirement in [
    "`app / ops trigger -> Edge Function -> external mail API`",
    "auth@auth.dogarea.app",
    "support@support.dogarea.app",
    "notice@notice.dogarea.app",
    "news@updates.dogarea.app",
    "Supabase Dashboard > Auth > Emails > SMTP Settings",
    "Edge Function runtime secret",
    "빨리 붙이려고 Auth SMTP를 재활용",
    "설정 화면",
    "bug report 접수 / 회신: `Service Mail API`"
] {
    assertTrue(doc.contains(requirement), "doc should include requirement \(requirement)")
}

assertTrue(readme.contains("docs/auth-service-mail-channel-separation-policy-v1.md"), "README should index auth service mail channel separation doc")
assertTrue(iosPRCheck.contains("auth_service_mail_channel_separation_unit_check.swift"), "ios_pr_check should run auth service mail channel separation unit check")
assertTrue(backendPRCheck.contains("auth_service_mail_channel_separation_unit_check.swift"), "backend_pr_check should run auth service mail channel separation unit check")

print("PASS: auth service mail channel separation unit checks")
