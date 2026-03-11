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
assertTrue(harnessLib.contains("harness_expect_status_in"), "integration harness library should expose allowlist status assertion helper")
assertTrue(harnessLib.contains("harness_expect_not_status"), "integration harness library should expose non-status assertion helper")
assertTrue(harnessLib.contains("HARNESS_MEMBER_REFRESH_TOKEN"), "integration harness library should preserve member refresh token")
assertTrue(harnessLib.contains("class=server_5xx"), "integration harness library should mark unexpected 5xx explicitly")
assertTrue(harnessLib.contains("request_id="), "integration harness library should emit request id diagnostics")
assertTrue(harnessLib.contains("error_code="), "integration harness library should emit error code diagnostics")

assertTrue(smokeRunner.contains("functions/v1/sync-profile"), "smoke matrix should include sync-profile route")
assertTrue(smokeRunner.contains("functions/v1/sync-walk"), "smoke matrix should include sync-walk route")
assertTrue(smokeRunner.contains("functions/v1/nearby-presence"), "smoke matrix should include nearby-presence route")
assertTrue(smokeRunner.contains("functions/v1/rival-league"), "smoke matrix should include rival-league route")
assertTrue(smokeRunner.contains("functions/v1/quest-engine"), "smoke matrix should include quest-engine route")
assertTrue(smokeRunner.contains("functions/v1/feature-control"), "smoke matrix should include feature-control route")
assertTrue(smokeRunner.contains("functions/v1/caricature"), "smoke matrix should include caricature route")
assertTrue(smokeRunner.contains("functions/v1/upload-profile-image"), "smoke matrix should include upload-profile-image route")
assertTrue(smokeRunner.contains("rpc_get_rival_leaderboard"), "smoke matrix should include rival RPC compatibility case")
assertTrue(smokeRunner.contains("rpc_get_widget_territory_summary"), "smoke matrix should include widget territory summary RPC case")
assertTrue(smokeRunner.contains("rpc_get_widget_hotspot_summary"), "smoke matrix should include widget hotspot summary RPC case")
assertTrue(smokeRunner.contains("rpc_get_widget_quest_rival_summary"), "smoke matrix should include widget quest/rival summary RPC case")
assertTrue(smokeRunner.contains("rpc_get_indoor_mission_summary"), "smoke matrix should include indoor mission summary RPC case")
assertTrue(smokeRunner.contains("rpc_record_indoor_mission_action"), "smoke matrix should include indoor mission action RPC case")
assertTrue(smokeRunner.contains("rpc_claim_indoor_mission_reward"), "smoke matrix should include indoor mission claim RPC case")
assertTrue(smokeRunner.contains("rpc_activate_indoor_easy_day"), "smoke matrix should include indoor mission easy day RPC case")
assertTrue(smokeRunner.contains("rpc_get_weather_replacement_summary"), "smoke matrix should include weather summary RPC case")
assertTrue(smokeRunner.contains("rpc_submit_weather_feedback"), "smoke matrix should include weather feedback RPC case")
assertTrue(smokeRunner.contains("rpc_get_owner_season_summary"), "smoke matrix should include season summary RPC case")
assertTrue(smokeRunner.contains("rpc_claim_season_reward"), "smoke matrix should include season claim RPC case")
assertTrue(smokeRunner.contains("auth.user.member"), "smoke matrix should include auth user member case")
assertTrue(smokeRunner.contains("auth.refresh.member"), "smoke matrix should include auth refresh member case")
assertTrue(smokeRunner.contains("auth.resend.signup.member_fixture"), "smoke matrix should include resend allowlist case")
assertTrue(smokeRunner.contains("auth.recover.member_fixture"), "smoke matrix should include recover allowlist case")
assertTrue(smokeRunner.contains("signup-email-availability.member"), "smoke matrix should include signup email availability case")
assertTrue(smokeRunner.contains("nearby-presence.visibility.get.member"), "smoke matrix should include visibility get case")
assertTrue(smokeRunner.contains("nearby-presence.visibility.set.member"), "smoke matrix should include visibility set case")
assertTrue(smokeRunner.contains("nearby-presence.hotspots.member"), "smoke matrix should include member hotspot case")
assertTrue(smokeRunner.contains("feature-control.flags.member"), "smoke matrix should include member feature flag case")
assertTrue(smokeRunner.contains("upload-profile-image.member_owner_mismatch"), "smoke matrix should include upload owner mismatch case")
assertTrue(smokeRunner.contains("caricature.invalid_request.member"), "smoke matrix should include caricature invalid request probe")
assertTrue(
    smokeRunner.contains("widget_territory_member") &&
        smokeRunner.contains("rpc_get_widget_territory_summary") &&
        smokeRunner.contains("in_now_ts"),
    "smoke matrix should call widget territory summary via payload wrapper"
)
assertTrue(
    smokeRunner.contains("widget_hotspot_member") &&
        smokeRunner.contains("rpc_get_widget_hotspot_summary") &&
        smokeRunner.contains("in_radius_km") &&
        smokeRunner.contains("in_now_ts"),
    "smoke matrix should call widget hotspot summary via payload wrapper"
)
assertTrue(smokeRunner.contains("sync-profile.permission.user_mismatch"), "smoke matrix should include permission mismatch case")
assertTrue(smokeRunner.contains("invalid_token"), "smoke matrix should include invalid token cases")

assertTrue(backendCheck.contains("supabase_integration_harness_unit_check.swift"), "backend PR check should run structure unit check")
assertTrue(backendCheck.contains("run_supabase_smoke_matrix.sh"), "backend PR check should connect to live smoke runner")
assertTrue(backendCheck.contains("DOGAREA_RUN_SUPABASE_SMOKE"), "backend PR check should guard live smoke behind explicit opt-in")

assertTrue(matrixDoc.contains("DOGAREA_TEST_EMAIL"), "integration smoke doc should document member credential env")
assertTrue(matrixDoc.contains("DOGAREA_SUPABASE_CASE_FILTER"), "integration smoke doc should document case filter env")
assertTrue(matrixDoc.contains("docs/member-supabase-http-full-sweep-v1.md"), "integration smoke doc should link member sweep doc")
assertTrue(matrixDoc.contains("docs/member-supabase-http-5xx-zero-budget-gate-v1.md"), "integration smoke doc should link zero-budget doc")
assertTrue(matrixDoc.contains("rival-rpc.compat.member"), "integration smoke doc should document RPC compatibility case")
assertTrue(matrixDoc.contains("widget-territory.summary.member"), "integration smoke doc should document widget territory RPC case")
assertTrue(matrixDoc.contains("widget-hotspot.summary.member"), "integration smoke doc should document widget hotspot RPC case")
assertTrue(matrixDoc.contains("widget-quest-rival.summary.member"), "integration smoke doc should document widget quest/rival RPC case")
assertTrue(matrixDoc.contains("upload-profile-image.member"), "integration smoke doc should document upload profile smoke case")
assertTrue(matrixDoc.contains("indoor-mission.summary.member"), "integration smoke doc should document indoor mission smoke case")
assertTrue(matrixDoc.contains("weather.summary.member"), "integration smoke doc should document weather smoke case")
assertTrue(matrixDoc.contains("season.summary.member"), "integration smoke doc should document season smoke case")
assertTrue(matrixDoc.contains("401"), "integration smoke doc should describe unauthorized expectations")
assertTrue(matrixDoc.contains("class=server_5xx"), "integration smoke doc should describe 5xx zero-budget output")

assertTrue(readme.contains("docs/supabase-integration-smoke-matrix-v1.md"), "README should link integration smoke doc")
assertTrue(readme.contains("docs/member-supabase-http-full-sweep-v1.md"), "README should link member sweep doc")
assertTrue(readme.contains("docs/member-supabase-http-5xx-zero-budget-gate-v1.md"), "README should link zero-budget doc")
assertTrue(readme.contains("bash scripts/backend_pr_check.sh"), "README should expose backend check entrypoint")
assertTrue(iosPRCheck.contains("supabase_integration_harness_unit_check.swift"), "ios_pr_check should include integration harness structure check")
assertTrue(backendCheck.contains("member_supabase_http_inventory_unit_check.swift"), "backend PR check should include member inventory unit check")
assertTrue(backendCheck.contains("member_supabase_http_zero_budget_gate_unit_check.swift"), "backend PR check should include zero-budget unit check")
assertTrue(iosPRCheck.contains("member_supabase_http_inventory_unit_check.swift"), "ios_pr_check should include member inventory unit check")
assertTrue(iosPRCheck.contains("member_supabase_http_zero_budget_gate_unit_check.swift"), "ios_pr_check should include zero-budget unit check")

print("PASS: supabase integration harness unit checks")
