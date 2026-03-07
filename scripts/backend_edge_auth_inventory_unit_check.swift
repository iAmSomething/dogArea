import Foundation

/// 조건이 거짓이면 실패 메시지를 stderr에 출력하고 프로세스를 종료합니다.
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

/// 여러 파일을 읽어 하나의 문자열로 합칩니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 내용을 줄바꿈으로 이은 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let inventoryDoc = load("docs/backend-edge-auth-mode-inventory-v1.md")
let authPolicyDoc = load("docs/backend-edge-auth-policy-v1.md")
let smokeMatrixDoc = load("docs/supabase-integration-smoke-matrix-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let authSmoke = load("scripts/auth_member_401_smoke_check.sh")
let config = load("supabase/config.toml")
let functionSources = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-profile/index.ts",
    "supabase/functions/rival-league/index.ts",
    "supabase/functions/quest-engine/index.ts",
    "supabase/functions/caricature/index.ts",
    "supabase/functions/nearby-presence/index.ts",
    "supabase/functions/upload-profile-image/index.ts",
    "supabase/functions/feature-control/index.ts"
])
let migrationSources = loadMany([
    "supabase/migrations/20260227192000_rival_privacy_hard_guard.sql",
    "supabase/migrations/20260301153000_rival_stage2_leaderboard_backend.sql",
    "supabase/migrations/20260303190000_territory_widget_summary_rpc.sql",
    "supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql",
    "supabase/migrations/20260303203100_widget_quest_rival_summary_rpc.sql",
    "supabase/migrations/20260305103000_walk_live_presence_schema_rpc_ttl_rls.sql",
    "supabase/migrations/20260305152000_walk_live_presence_privacy_guard_v2.sql",
    "supabase/migrations/20260305224000_rival_rpc_postgrest_compat_fix.sql"
])

for authClass in ["member_required", "member_or_anon", "public_like_restricted", "service_role_internal"] {
    assertTrue(inventoryDoc.contains(authClass), "inventory doc should define \(authClass)")
}

for functionName in [
    "sync-walk",
    "sync-profile",
    "rival-league",
    "quest-engine",
    "caricature",
    "nearby-presence",
    "upload-profile-image",
    "feature-control"
] {
    assertTrue(inventoryDoc.contains("`\(functionName)`"), "inventory doc should list edge function \(functionName)")
}

for rpcSurface in [
    "rpc_get_nearby_hotspots",
    "rpc_get_rival_leaderboard(payload jsonb)",
    "rpc_get_widget_hotspot_summary",
    "rpc_get_widget_territory_summary",
    "rpc_get_widget_quest_rival_summary(payload jsonb)",
    "rpc_upsert_walk_live_presence(...)",
    "rpc_get_walk_live_presence(...)",
    "rpc_cleanup_walk_live_presence(timestamptz)",
    "view_rollout_kpis_24h",
    "feature_flags"
] {
    assertTrue(inventoryDoc.contains(rpcSurface), "inventory doc should list RPC/view surface \(rpcSurface)")
}

assertTrue(inventoryDoc.contains("#466"), "inventory doc should keep upload-profile-image hardening traceability")
assertTrue(inventoryDoc.contains("anon-onboarding-*"), "inventory doc should document anon onboarding namespace policy")
assertTrue(inventoryDoc.contains("UNAUTHORIZED_USER_MISMATCH"), "inventory doc should document member owner mismatch handling")
assertTrue(inventoryDoc.contains("auth_member_401_smoke_check.sh"), "inventory doc should reference auth smoke script")
assertTrue(inventoryDoc.contains("docs/supabase-integration-smoke-matrix-v1.md"), "inventory doc should reference smoke matrix doc")

assertTrue(authPolicyDoc.contains("member_required"), "auth policy doc should still define member_required")
assertTrue(authPolicyDoc.contains("member_or_anon"), "auth policy doc should still define member_or_anon")

for block in [
    "[functions.sync-walk]\nverify_jwt = false",
    "[functions.sync-profile]\nverify_jwt = false",
    "[functions.rival-league]\nverify_jwt = false",
    "[functions.quest-engine]\nverify_jwt = false",
    "[functions.nearby-presence]\nverify_jwt = false",
    "[functions.upload-profile-image]\nverify_jwt = false",
    "[functions.caricature]\nverify_jwt = false",
    "[functions.feature-control]\nverify_jwt = false"
] {
    assertTrue(config.contains(block), "supabase config should keep verify_jwt disabled for \(block)")
}

assertTrue(functionSources.contains("kind: \"member_required\""), "function sources should still contain member_required policies")
assertTrue(functionSources.contains("kind: \"member_or_anon\""), "function sources should still contain member_or_anon policies")
assertTrue(functionSources.contains("ensureAuthenticatedUserMatch"), "sync-profile mismatch guard should remain in source")
assertTrue(functionSources.contains("ownerIdRaw"), "upload-profile-image should still parse caller supplied ownerId for policy validation")
assertTrue(functionSources.contains("ensureAuthenticatedUserMatch"), "upload-profile-image should now bind ownerId to authenticated user")
assertTrue(functionSources.contains("ANON_OWNER_NAMESPACE_REQUIRED"), "upload-profile-image should enforce anon onboarding namespace")

for grant in [
    "grant execute on function public.rpc_get_nearby_hotspots(double precision, double precision, double precision, timestamptz) to anon, authenticated;",
    "grant execute on function public.rpc_get_rival_leaderboard(jsonb) to anon, authenticated, service_role;",
    "grant execute on function public.rpc_get_widget_hotspot_summary(double precision, timestamptz) to anon, authenticated, service_role;",
    "grant execute on function public.rpc_get_widget_territory_summary(timestamptz) to authenticated, service_role;",
    "grant execute on function public.rpc_get_widget_quest_rival_summary(jsonb) to authenticated, service_role;",
    "grant execute on function public.rpc_cleanup_walk_live_presence(timestamptz) to service_role;"
] {
    assertTrue(migrationSources.contains(grant), "migration sources should include grant \(grant)")
}

for smokeCase in [
    "nearby_visibility member=",
    "upload_profile member=",
    "feature_control member=",
    "rival_rpc member=",
    "sync-profile.snapshot.member",
    "sync-walk.session.member",
    "rival-league.leaderboard.member"
] {
    assertTrue(authSmoke.contains(smokeCase) || smokeMatrixDoc.contains(smokeCase), "smoke docs/scripts should cover \(smokeCase)")
}

assertTrue(readme.contains("docs/backend-edge-auth-mode-inventory-v1.md"), "README should link auth inventory doc")
assertTrue(backendCheck.contains("backend_edge_auth_inventory_unit_check.swift"), "backend_pr_check should run auth inventory unit check")
assertTrue(iosPRCheck.contains("backend_edge_auth_inventory_unit_check.swift"), "ios_pr_check should run auth inventory unit check")

print("PASS: backend edge auth inventory unit checks")
