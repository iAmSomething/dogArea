import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 조건이 거짓일 때 출력할 설명입니다.
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

let doc = load("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md")
let readme = load("README.md")
let smokeMatrix = load("docs/supabase-integration-smoke-matrix-v1.md")
let driftDoc = load("docs/backend-migration-drift-rpc-ci-check-v1.md")
let syncWalkPolicy = load("docs/sync-walk-404-fallback-policy-v1.md")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let authSmoke = load("scripts/auth_member_401_smoke_check.sh")

for token in [
    "sync-profile",
    "sync-walk",
    "nearby-presence",
    "rival-league",
    "quest-engine",
    "feature-control",
    "upload-profile-image",
    "caricature",
    "rpc_get_rival_leaderboard",
    "rpc_get_widget_territory_summary",
    "rpc_get_widget_hotspot_summary",
    "rpc_get_widget_quest_rival_summary",
    "Tier 0",
    "Tier 1",
    "Tier 2",
    "404",
    "401",
    "Post-Deploy Priority"
] {
    assertTrue(doc.contains(token), "deploy matrix doc should mention \(token)")
}

for caseName in [
    "sync-profile.snapshot.member",
    "sync-profile.permission.user_mismatch",
    "sync-walk.session.member",
    "sync-walk.summary.member",
    "nearby-presence.hotspots.app_policy",
    "rival-league.leaderboard.member",
    "rival-rpc.compat.member",
    "quest-engine.list_active.member",
    "feature-control.flags.anon",
    "feature-control.rollout_kpis.anon",
    "widget-territory.summary.member",
    "widget-hotspot.summary.member",
    "widget-quest-rival.summary.member"
] {
    assertTrue(doc.contains(caseName), "deploy matrix doc should mention smoke case \(caseName)")
    assertTrue(smokeMatrix.contains(caseName), "smoke matrix doc should mention \(caseName)")
    assertTrue(smokeRunner.contains(caseName), "smoke runner should implement \(caseName)")
}

assertTrue(doc.contains("upload_profile member=200 app=200"), "deploy matrix doc should document upload-profile-image auth smoke case")
assertTrue(doc.contains("scripts/auth_member_401_smoke_check.sh"), "deploy matrix doc should link auth smoke script")
assertTrue(driftDoc.contains("rival-rpc.compat.member"), "drift doc should still mention rival rpc compat case")
assertTrue(syncWalkPolicy.contains("sync-walk"), "sync-walk policy doc should still exist for deploy matrix reference")
assertTrue(authSmoke.contains("upload-profile-image"), "auth smoke should still cover upload-profile-image")

assertTrue(readme.contains("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md"), "README should link deploy matrix doc")
assertTrue(smokeMatrix.contains("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md"), "smoke matrix doc should link deploy matrix doc")
assertTrue(driftDoc.contains("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md"), "drift doc should link deploy matrix doc")

assertTrue(backendPRCheck.contains("backend_edge_rpc_deploy_matrix_unit_check.swift"), "backend_pr_check should run deploy matrix check")
assertTrue(iosPRCheck.contains("backend_edge_rpc_deploy_matrix_unit_check.swift"), "ios_pr_check should run deploy matrix check")

print("PASS: backend edge rpc deployment matrix unit checks")
