import Foundation

/// 조건이 참인지 검증합니다.
/// - Parameters:
///   - condition: 평가할 조건식입니다.
///   - message: 실패 시 출력할 설명입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let evidence = load("docs/issues-680-681-closure-evidence-v1.md")
let contractDoc = load("docs/auth-session-signal-contract-v1.md")
let contractCheck = load("scripts/auth_session_signal_contract_unit_check.swift")
let authFlowObserverCheck = load("scripts/auth_flow_session_observer_unit_check.swift")
let settingsCheck = load("scripts/settings_auth_session_sync_unit_check.swift")
let mapCheck = load("scripts/map_auth_session_sync_unit_check.swift")
let rivalCheck = load("scripts/rival_auth_session_sync_unit_check.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#680"), "evidence doc should reference issue #680")
assertTrue(evidence.contains("#681"), "evidence doc should reference issue #681")
assertTrue(evidence.contains("#682"), "evidence doc should reference implementation PR #682")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("닫아도 된다"), "evidence doc should conclude that the issue bundle can close")
assertTrue(contractDoc.contains("signal은 항상 main actor에서만 발행한다"), "contract doc should preserve main-safe delivery rule")
assertTrue(contractDoc.contains("persistAuthenticatedSession(identity:tokenSession:)"), "contract doc should preserve logical transition persist API")
assertTrue(contractDoc.contains("dogAreaApp") && contractDoc.contains("별도 `authFlow.refresh()` observer를 다시 두지 않는다"), "contract doc should preserve root observer ownership")
assertTrue(contractCheck.contains("persistAuthenticatedSession(identity:tokenSession:)"), "contract check should cover logical transition persist API")
assertTrue(contractCheck.contains("Task { @MainActor [self] in"), "contract check should cover main-safe signal delivery")
assertTrue(authFlowObserverCheck.contains("authSessionDidChange"), "auth flow observer check should still cover auth session observer")
assertTrue(settingsCheck.contains(".authSessionDidChange"), "settings check should still cover auth session sync")
assertTrue(mapCheck.contains(".authSessionDidChange"), "map check should still cover auth session sync")
assertTrue(rivalCheck.contains(".authSessionDidChange"), "rival check should still cover auth session sync")
assertTrue(readme.contains("docs/issues-680-681-closure-evidence-v1.md"), "README should index the auth session closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issues_680_681_closure_evidence_unit_check.swift"), "ios_pr_check should include the closure evidence check")

print("PASS: issues #680 #681 closure evidence unit checks")
