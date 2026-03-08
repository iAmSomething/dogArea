import Foundation

/// 조건이 거짓이면 stderr에 메시지를 출력하고 즉시 실패합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 시 출력할 설명 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 상대 경로의 UTF-8 텍스트 파일을 로드합니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let evidenceDoc = load("docs/epic-123-closure-evidence-v1.md")
let epicBody = load("docs/game-layer-observability-qa-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let backendCheck = load("scripts/backend_pr_check.sh")

assertTrue(evidenceDoc.contains("#123"), "evidence doc should reference epic #123")
assertTrue(evidenceDoc.contains("#411"), "evidence doc should reference issue #411")
assertTrue(evidenceDoc.contains("#206"), "evidence doc should reference issue #206")
assertTrue(evidenceDoc.contains("#247"), "evidence doc should reference issue #247")

assertTrue(evidenceDoc.contains("bash scripts/backend_pr_check.sh"), "evidence doc should record backend_pr_check execution")
assertTrue(evidenceDoc.contains("bash scripts/ios_pr_check.sh"), "evidence doc should record ios_pr_check execution")
assertTrue(evidenceDoc.contains("view_game_layer_kpis_7d"), "evidence doc should reference KPI view")
assertTrue(evidenceDoc.contains("view_rollout_kpis_24h"), "evidence doc should reference rollout KPI view")
assertTrue(evidenceDoc.contains("rival-privacy-policy-stage1-v1.md"), "evidence doc should reference rival privacy policy doc")
assertTrue(evidenceDoc.contains("hotspot-widget-privacy-mapping-v1.md"), "evidence doc should reference hotspot widget privacy doc")
assertTrue(evidenceDoc.contains("모두 충족"), "evidence doc should conclude DoD is satisfied")
assertTrue(evidenceDoc.contains("닫을 수"), "evidence doc should conclude the epic can be closed")

assertTrue(epicBody.contains("view_game_layer_kpis_7d"), "observability spec should still expose KPI view")
assertTrue(readme.contains("docs/epic-123-closure-evidence-v1.md"), "README should index epic #123 closure evidence doc")
assertTrue(iosCheck.contains("swift scripts/epic_123_closure_evidence_unit_check.swift"), "ios_pr_check should run epic #123 closure evidence check")
assertTrue(backendCheck.contains("swift scripts/epic_123_closure_evidence_unit_check.swift"), "backend_pr_check should run epic #123 closure evidence check")

print("PASS: epic #123 closure evidence unit checks")
