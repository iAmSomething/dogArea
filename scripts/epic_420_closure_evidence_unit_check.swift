import Foundation

/// 조건이 참인지 검증하고 실패 시 즉시 종료합니다.
/// - Parameters:
///   - condition: 참이어야 하는 조건식입니다.
///   - message: 실패 시 출력할 설명입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 디코딩된 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let evidenceDoc = load("docs/epic-420-closure-evidence-v1.md")
let authPolicy = load("docs/backend-edge-auth-policy-v1.md")
let authInventory = load("docs/backend-edge-auth-mode-inventory-v1.md")
let contractPolicy = load("docs/backend-contract-versioning-policy-v1.md")
let highRiskMatrix = load("docs/backend-high-risk-contract-matrix-v1.md")
let smokeMatrix = load("docs/supabase-integration-smoke-matrix-v1.md")
let observabilityDoc = load("docs/backend-edge-observability-standard-v1.md")
let taxonomyDoc = load("docs/backend-edge-error-taxonomy-v1.md")
let incidentRunbook = load("docs/backend-edge-incident-runbook-v1.md")
let failureDashboard = load("docs/backend-edge-failure-dashboard-view-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosCheck = load("scripts/ios_pr_check.sh")
let readme = load("README.md")

assertTrue(evidenceDoc.contains("#420"), "evidence doc should reference epic #420")
assertTrue(evidenceDoc.contains("#419"), "evidence doc should reference issue #419")
assertTrue(evidenceDoc.contains("#417"), "evidence doc should reference issue #417")
assertTrue(evidenceDoc.contains("#416"), "evidence doc should reference issue #416")
assertTrue(evidenceDoc.contains("#418"), "evidence doc should reference issue #418")
assertTrue(evidenceDoc.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidenceDoc.contains("종료 가능"), "evidence doc should conclude that the epic can close")

assertTrue(authPolicy.contains("request_id"), "auth policy should describe request_id metadata")
assertTrue(authInventory.contains("docs/supabase-integration-smoke-matrix-v1.md"), "auth inventory should reference smoke matrix")
assertTrue(contractPolicy.contains("request_id"), "contract policy should define request_id rules")
assertTrue(highRiskMatrix.contains("sync-walk"), "high-risk matrix should include sync-walk")
assertTrue(highRiskMatrix.contains("nearby-presence"), "high-risk matrix should include nearby-presence")
assertTrue(highRiskMatrix.contains("rival-league"), "high-risk matrix should include rival-league")
assertTrue(highRiskMatrix.contains("quest-engine"), "high-risk matrix should include quest-engine")
assertTrue(smokeMatrix.contains("sync-walk"), "smoke matrix should include sync-walk validation")
assertTrue(smokeMatrix.contains("nearby-presence"), "smoke matrix should include nearby-presence validation")
assertTrue(smokeMatrix.contains("feature-control"), "smoke matrix should include feature-control validation")
assertTrue(observabilityDoc.contains("function_name"), "observability standard should define function_name metadata")
assertTrue(observabilityDoc.contains("request_id"), "observability standard should define request_id metadata")
assertTrue(taxonomyDoc.contains("error"), "error taxonomy should define backend error classes")
assertTrue(incidentRunbook.contains("request_id"), "incident runbook should use request_id for triage")
assertTrue(failureDashboard.contains("Backend Edge Failure Dashboard View v1"), "failure dashboard doc should exist")

assertTrue(backendCheck.contains("swift scripts/supabase_integration_harness_unit_check.swift"), "backend_pr_check should run the harness check")
assertTrue(backendCheck.contains("swift scripts/backend_contract_versioning_unit_check.swift"), "backend_pr_check should run the contract versioning check")
assertTrue(backendCheck.contains("swift scripts/backend_edge_observability_unit_check.swift"), "backend_pr_check should run the observability check")
assertTrue(backendCheck.contains("swift scripts/backend_edge_auth_unification_unit_check.swift"), "backend_pr_check should run the auth unification check")
assertTrue(iosCheck.contains("swift scripts/epic_420_closure_evidence_unit_check.swift"), "ios_pr_check should include the epic #420 closure check")
assertTrue(backendCheck.contains("DOGAREA_RUN_SUPABASE_SMOKE=1"), "backend_pr_check should expose live smoke execution path")
assertTrue(readme.contains("docs/epic-420-closure-evidence-v1.md"), "README should index the epic #420 closure evidence doc")

print("PASS: epic #420 closure evidence unit checks")
