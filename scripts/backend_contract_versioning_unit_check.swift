import Foundation

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 stderr에 출력할 설명입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트를 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let policy = load("docs/backend-contract-versioning-policy-v1.md")
let matrix = load("docs/backend-high-risk-contract-matrix-v1.md")
let smokeDoc = load("docs/supabase-integration-smoke-matrix-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let nearbyPresence = load("supabase/functions/nearby-presence/index.ts")
let rivalLeague = load("supabase/functions/rival-league/index.ts")
let rivalCompat = load("supabase/migrations/20260305224000_rival_rpc_postgrest_compat_fix.sql")
let hotspotWidgetMigration = load("supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql")
let territoryWidgetMigration = load("supabase/migrations/20260303190000_territory_widget_summary_rpc.sql")

assertTrue(policy.contains("version"), "policy should define version field rule")
assertTrue(policy.contains("request_id"), "policy should define request_id rule")
assertTrue(policy.contains("ok"), "policy should define ok envelope field")
assertTrue(policy.contains("error"), "policy should define error envelope field")
assertTrue(policy.contains("code"), "policy should define error code field")
assertTrue(policy.contains("message"), "policy should define error message field")
assertTrue(policy.contains("payload jsonb"), "policy should define jsonb payload wrapper rule")
assertTrue(policy.contains("2개 앱 릴리즈 또는 14일"), "policy should define deprecation minimum window")
assertTrue(policy.contains("Breaking"), "policy should document breaking change criteria")
assertTrue(policy.contains("Non-breaking"), "policy should document non-breaking criteria")

for endpoint in ["sync-walk", "nearby-presence", "rival-league", "quest-engine", "rpc_get_widget_quest_rival_summary"] {
    assertTrue(matrix.contains(endpoint), "matrix should include \(endpoint)")
}
assertTrue(matrix.contains("rpc_get_widget_territory_summary"), "matrix should include territory widget RPC")
assertTrue(matrix.contains("rpc_get_widget_hotspot_summary"), "matrix should include hotspot widget RPC")
assertTrue(matrix.contains("rpc_get_nearby_hotspots"), "matrix should include nearby hotspot RPC compatibility note")
assertTrue(matrix.contains("rpc_get_rival_leaderboard(payload jsonb)"), "matrix should declare jsonb leaderboard canonical path")
assertTrue(matrix.contains("top-level 유지"), "matrix should preserve top-level response keys for compatibility")

assertTrue(nearbyPresence.contains("getNearbyHotspotsWithCompatRPC"), "nearby presence should still expose hotspot RPC compat helper")
assertTrue(nearbyPresence.contains("in_center_lat") && nearbyPresence.contains("center_lat"), "nearby presence should document latest and legacy hotspot RPC signatures in source")
assertTrue(rivalLeague.contains("payload:"), "rival league should call leaderboard RPC through payload wrapper")
assertTrue(rivalCompat.contains("rpc_get_rival_leaderboard(payload jsonb)"), "compat migration should define jsonb leaderboard wrapper")
assertTrue(rivalCompat.contains("rpc_get_widget_quest_rival_summary(payload jsonb)"), "compat migration should define widget quest/rival jsonb wrapper")
assertTrue(hotspotWidgetMigration.contains("rpc_get_widget_hotspot_summary"), "hotspot widget migration should exist for matrix coverage")
assertTrue(territoryWidgetMigration.contains("rpc_get_widget_territory_summary"), "territory widget migration should exist for matrix coverage")

assertTrue(smokeDoc.contains("rival-rpc.compat.member"), "smoke doc should keep rival rpc compatibility coverage")
assertTrue(smokeDoc.contains("quest-engine.list_active.member"), "smoke doc should keep quest-engine smoke coverage")
assertTrue(backendCheck.contains("backend_contract_versioning_unit_check.swift"), "backend_pr_check should run contract versioning unit check")
assertTrue(iosPRCheck.contains("backend_contract_versioning_unit_check.swift"), "ios_pr_check should run contract versioning unit check")
assertTrue(readme.contains("docs/backend-contract-versioning-policy-v1.md"), "README should link backend contract policy doc")
assertTrue(readme.contains("docs/backend-high-risk-contract-matrix-v1.md"), "README should link backend contract matrix doc")

print("PASS: backend contract versioning unit checks")
