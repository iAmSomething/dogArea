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

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let helper = load("supabase/functions/_shared/edge_auth.ts")
let syncWalk = load("supabase/functions/sync-walk/index.ts")
let syncProfile = load("supabase/functions/sync-profile/index.ts")
let rivalLeague = load("supabase/functions/rival-league/index.ts")
let questEngine = load("supabase/functions/quest-engine/index.ts")
let nearbyPresence = load("supabase/functions/nearby-presence/index.ts")
let uploadProfileImage = load("supabase/functions/upload-profile-image/index.ts")
let caricature = load("supabase/functions/caricature/index.ts")
let featureControl = load("supabase/functions/feature-control/index.ts")
let config = load("supabase/config.toml")
let doc = load("docs/backend-edge-auth-policy-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(helper.contains("member_required"), "shared edge auth helper should define member_required policy")
assertTrue(helper.contains("member_or_anon"), "shared edge auth helper should define member_or_anon policy")
assertTrue(helper.contains("service_role_internal"), "shared edge auth helper should define service_role_internal policy")
assertTrue(helper.contains("AUTH_HEADER_MISSING"), "shared edge auth helper should define missing-header code")
assertTrue(helper.contains("AUTH_SESSION_INVALID"), "shared edge auth helper should define invalid-session code")
assertTrue(helper.contains("AUTH_MODE_NOT_ALLOWED"), "shared edge auth helper should define auth-mode code")
assertTrue(helper.contains("UNAUTHORIZED_USER_MISMATCH"), "shared edge auth helper should define user mismatch code")
assertTrue(helper.contains("claims.role === \"anon\"") && helper.contains("claims.ref === expectedRef"), "shared edge auth helper should accept anon app tokens via role/ref validation")
assertTrue(helper.contains("req.headers.get(\"apikey\")"), "shared edge auth helper should prefer request apikey for member validation")
assertTrue(helper.contains("resolveEdgeAuthContext"), "shared edge auth helper should expose auth resolver")
assertTrue(helper.contains("ensureAuthenticatedUserMatch"), "shared edge auth helper should expose mismatch guard")

for source in [syncWalk, syncProfile, rivalLeague, questEngine, nearbyPresence, uploadProfileImage, caricature, featureControl] {
    assertTrue(source.contains("resolveEdgeAuthContext"), "every high-risk function should call shared auth resolver")
}

assertTrue(syncWalk.contains("kind: \"member_required\""), "sync-walk should require member auth")
assertTrue(syncProfile.contains("kind: \"member_required\""), "sync-profile should require member auth")
assertTrue(rivalLeague.contains("kind: \"member_required\""), "rival-league should require member auth")
assertTrue(questEngine.contains("kind: \"member_required\""), "quest-engine should require member auth")
assertTrue(caricature.contains("kind: \"member_required\""), "caricature should require member auth")

assertTrue(nearbyPresence.contains("kind: \"member_or_anon\""), "nearby-presence should allow member or anon auth")
assertTrue(uploadProfileImage.contains("kind: \"member_or_anon\""), "upload-profile-image should allow member or anon auth")
assertTrue(featureControl.contains("kind: \"member_or_anon\""), "feature-control should allow member or anon auth")
assertTrue(syncProfile.contains("ensureAuthenticatedUserMatch"), "sync-profile should use shared 403 mismatch guard")

for functionName in [
    "sync-walk",
    "sync-profile",
    "rival-league",
    "quest-engine",
    "nearby-presence",
    "upload-profile-image",
    "caricature",
    "feature-control",
] {
    let block = "[functions.\(functionName)]\nverify_jwt = false"
    assertTrue(config.contains(block), "supabase/config.toml should disable verify_jwt for \(functionName)")
}

assertTrue(doc.contains("supabase/functions/_shared/edge_auth.ts"), "backend edge auth policy doc should reference shared helper")
assertTrue(doc.contains("member_required"), "backend edge auth policy doc should document member_required policy")
assertTrue(doc.contains("member_or_anon"), "backend edge auth policy doc should document member_or_anon policy")
assertTrue(doc.contains("service_role_internal"), "backend edge auth policy doc should document service_role_internal policy")
assertTrue(doc.contains("UNAUTHORIZED_USER_MISMATCH"), "backend edge auth policy doc should document 403 mismatch code")
assertTrue(doc.contains("verify_jwt = false"), "backend edge auth policy doc should document gateway verify_jwt disablement")

assertTrue(readme.contains("docs/backend-edge-auth-policy-v1.md"), "README should link backend edge auth policy doc")
assertTrue(backendCheck.contains("backend_edge_auth_unification_unit_check.swift"), "backend_pr_check should run edge auth unification check")
assertTrue(iosPRCheck.contains("backend_edge_auth_unification_unit_check.swift"), "ios_pr_check should run edge auth unification check")

print("PASS: backend edge auth unification unit checks")
