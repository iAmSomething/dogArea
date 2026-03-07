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

let doc = load("docs/auth-captcha-insertion-fallback-ux-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for heading in [
    "# Auth CAPTCHA Insertion & Fallback UX v1",
    "## 액션별 적용 기준",
    "## 삽입 지점 결정",
    "## 노출 방식 비교",
    "## 최종 UX 계약",
    "## 실패 / 취소 / 네트워크 오류 UX",
    "## 접근성 기준",
    "## 정상 사용자 전환율 영향과 완화책",
    "## QA 시나리오"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for action in ["회원가입", "비밀번호 재설정", "이메일 변경"] {
    assertTrue(doc.contains(action), "doc should cover action \(action)")
}

for decision in [
    "always-on CAPTCHA 금지",
    "서버 판정 기반 step-up",
    "native explainer sheet + `ASWebAuthenticationSession`",
    "`WKWebView`는 1차 채택안에서 제외"
] {
    assertTrue(doc.contains(decision), "doc should include decision \(decision)")
}

for comparison in [
    "폼 하단에 항상 inline 노출",
    "앱 내부 `WKWebView` / 임베디드 웹뷰",
    "native explainer sheet + `ASWebAuthenticationSession`",
    "외부 Safari 완전 전환"
] {
    assertTrue(doc.contains(comparison), "doc should compare presentation mode \(comparison)")
}

for fallbackFlow in [
    "CAPTCHA 실패",
    "사용자가 취소",
    "네트워크 실패",
    "반복 실패 / 과도한 요청"
] {
    assertTrue(doc.contains(fallbackFlow), "doc should define fallback flow \(fallbackFlow)")
}

for metric in [
    "`auth_captcha_step_up_presented`",
    "`auth_captcha_step_up_completed`",
    "`auth_captcha_step_up_cancelled`",
    "`auth_captcha_step_up_failed`"
] {
    assertTrue(doc.contains(metric), "doc should propose metric \(metric)")
}

assertTrue(doc.contains("#509"), "doc should reference provider follow-up issue #509")
assertTrue(doc.contains("#510"), "doc should reference observability follow-up issue #510")
assertTrue(readme.contains("docs/auth-captcha-insertion-fallback-ux-v1.md"), "README should index CAPTCHA UX doc")
assertTrue(iosPRCheck.contains("auth_captcha_fallback_ux_unit_check.swift"), "ios_pr_check should run CAPTCHA UX unit check")

print("PASS: auth captcha fallback ux unit checks")
