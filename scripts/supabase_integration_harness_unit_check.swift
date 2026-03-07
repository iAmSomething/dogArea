import Foundation

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 설명입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let harnessLib = load("scripts/lib/supabase_integration_harness.sh")
let matrixDoc = load("docs/supabase-integration-smoke-matrix-v1.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(harnessLib.contains("harness_load_env"), "integration harness library should load Supabase env")
assertTrue(harnessLib.contains("harness_login_member"), "integration harness library should support member login")
assertTrue(harnessLib.contains("harness_expect_status"), "integration harness library should expose status assertion helper")
assertTrue(harnessLib.contains("harness_expect_not_status"), "integration harness library should expose non-status assertion helper")

assertTrue(smokeRunner.contains("functions/v1/sync-profile"), "smoke matrix should include sync-profile route")
assertTrue(smokeRunner.contains("functions/v1/sync-walk"), "smoke matrix should include sync-walk route")
assertTrue(smokeRunner.contains("functions/v1/nearby-presence"), "smoke matrix should include nearby-presence route")
assertTrue(smokeRunner.contains("functions/v1/rival-league"), "smoke matrix should include rival-league route")
assertTrue(smokeRunner.contains("functions/v1/quest-engine"), "smoke matrix should include quest-engine route")
assertTrue(smokeRunner.contains("functions/v1/feature-control"), "smoke matrix should include feature-control route")
assertTrue(smokeRunner.contains("rpc_get_rival_leaderboard"), "smoke matrix should include rival RPC compatibility case")
assertTrue(smokeRunner.contains("sync-profile.permission.user_mismatch"), "smoke matrix should include permission mismatch case")
assertTrue(smokeRunner.contains("invalid_token"), "smoke matrix should include invalid token cases")

assertTrue(backendCheck.contains("supabase_integration_harness_unit_check.swift"), "backend PR check should run structure unit check")
assertTrue(backendCheck.contains("run_supabase_smoke_matrix.sh"), "backend PR check should connect to live smoke runner")
assertTrue(backendCheck.contains("DOGAREA_RUN_SUPABASE_SMOKE"), "backend PR check should guard live smoke behind explicit opt-in")

assertTrue(matrixDoc.contains("DOGAREA_TEST_EMAIL"), "integration smoke doc should document member credential env")
assertTrue(matrixDoc.contains("DOGAREA_SUPABASE_CASE_FILTER"), "integration smoke doc should document case filter env")
assertTrue(matrixDoc.contains("rival-rpc.compat.member"), "integration smoke doc should document RPC compatibility case")
assertTrue(matrixDoc.contains("401"), "integration smoke doc should describe unauthorized expectations")

assertTrue(readme.contains("docs/supabase-integration-smoke-matrix-v1.md"), "README should link integration smoke doc")
assertTrue(readme.contains("bash scripts/backend_pr_check.sh"), "README should expose backend check entrypoint")
assertTrue(iosPRCheck.contains("supabase_integration_harness_unit_check.swift"), "ios_pr_check should include integration harness structure check")

print("PASS: supabase integration harness unit checks")
