import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 검증 실패 시 출력할 설명입니다.
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

let runbook = load("docs/backend-deploy-rollback-roll-forward-runbook-v1.md")
let readme = load("README.md")
let migrationDoc = load("docs/supabase-migration.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let incidentDoc = load("docs/backend-edge-incident-runbook-v1.md")
let deployMatrix = load("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for token in [
    "Decision Matrix",
    "RPC signature mismatch",
    "Edge Function route 404",
    "Edge env / secret misconfiguration",
    "Seed / test fixture contamination",
    "User data corruption",
    "roll-forward",
    "rollback",
    "write freeze",
    "npx --yes supabase migration list --linked",
    "npx --yes supabase db push --linked --dry-run",
    "DOGAREA_RUN_SUPABASE_SMOKE=1",
    "DOGAREA_AUTH_SMOKE_ITERATIONS=1",
    "seed_test_walk_data",
    "seed_geo_2km_test_data",
    "rename_geo_test_user_and_pet_names",
    "regenerate_geo_walk_patterns",
    "recenter_geo_test_points_to_yeonsu1dong",
    "seed_geo_test_additional_variants",
    "#440"
] {
    assertTrue(runbook.contains(token), "rollback runbook should mention \(token)")
}

assertTrue(schemaDoc.contains("원칙: destructive rollback 금지"), "schema doc should still define destructive rollback prohibition")
assertTrue(migrationDoc.contains("npx --yes supabase migration list --linked"), "migration doc should still define linked migration command")
assertTrue(incidentDoc.contains("rollback/roll-forward runbook"), "incident runbook should reference rollback runbook")
assertTrue(deployMatrix.contains("rollback"), "deploy matrix should still mention rollback in completion note or triage flow")

assertTrue(readme.contains("docs/backend-deploy-rollback-roll-forward-runbook-v1.md"), "README should link rollback runbook")
assertTrue(migrationDoc.contains("docs/backend-deploy-rollback-roll-forward-runbook-v1.md"), "migration doc should link rollback runbook")
assertTrue(incidentDoc.contains("docs/backend-deploy-rollback-roll-forward-runbook-v1.md"), "incident runbook should link rollback runbook")
assertTrue(deployMatrix.contains("docs/backend-deploy-rollback-roll-forward-runbook-v1.md"), "deploy matrix should link rollback runbook")

assertTrue(backendCheck.contains("backend_deploy_rollback_runbook_unit_check.swift"), "backend_pr_check should run rollback runbook check")
assertTrue(iosPRCheck.contains("backend_deploy_rollback_runbook_unit_check.swift"), "ios_pr_check should run rollback runbook check")

print("PASS: backend deploy rollback runbook unit checks")
