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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let standardDoc = load("docs/backend-edge-observability-standard-v1.md")
let taxonomyDoc = load("docs/backend-edge-error-taxonomy-v1.md")
let runbookDoc = load("docs/backend-edge-incident-runbook-v1.md")
let matrixDoc = load("docs/backend-edge-observability-adoption-matrix-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let caricature = load("supabase/functions/caricature/index.ts")
let edgeAuthHelper = load("supabase/functions/_shared/edge_auth.ts")
let nearbyPresence = loadMany([
    "supabase/functions/nearby-presence/index.ts",
    "supabase/functions/nearby-presence/support/types.ts",
    "supabase/functions/nearby-presence/support/privacy_audit.ts",
    "supabase/functions/nearby-presence/support/hotspot_compat.ts",
    "supabase/functions/nearby-presence/handlers/hotspot_handler.ts",
    "supabase/functions/nearby-presence/handlers/live_presence_handlers.ts"
])
let syncWalk = load("supabase/functions/sync-walk/index.ts")
let questEngine = load("supabase/functions/quest-engine/index.ts")
let featureControl = load("supabase/functions/feature-control/index.ts")
let uploadProfileImage = load("supabase/functions/upload-profile-image/index.ts")

for field in ["function_name", "request_id", "version", "latency_ms", "auth_mode", "fallback_used", "rpc_name"] {
    assertTrue(standardDoc.contains(field), "standard doc should define \(field) field")
}
assertTrue(standardDoc.contains("request_received"), "standard doc should define request_received event")
assertTrue(standardDoc.contains("request_succeeded"), "standard doc should define request_succeeded event")
assertTrue(standardDoc.contains("request_failed"), "standard doc should define request_failed event")
assertTrue(standardDoc.contains("service_role_proxy"), "standard doc should define auth_mode values")
assertTrue(standardDoc.contains("policy_key"), "standard doc should define policy key metadata")
assertTrue(standardDoc.contains("cooldown_key"), "standard doc should define cooldown metadata")

for category in ["auth", "contract", "validation", "unavailable", "privacy", "upstream", "abuse"] {
    assertTrue(taxonomyDoc.contains("### 1. auth") || category != "auth", "taxonomy doc should keep category headers")
    assertTrue(taxonomyDoc.contains(category), "taxonomy doc should mention category \(category)")
}
for code in ["UNAUTHORIZED", "INVALID_JSON", "INVALID_PAYLOAD", "SERVER_MISCONFIGURED", "PRIVACY_GUARD_BLOCKED", "STORAGE_UPLOAD_FAILED", "ABUSE_BLOCKED"] {
    assertTrue(taxonomyDoc.contains(code), "taxonomy doc should include canonical code \(code)")
}

for term in ["function_name", "request_id", "fallback_used", "rpc_name", "404 / function not deployed", "anon retry / auth downgrade", "nearby suppression / privacy guard", "provider fallback"] {
    assertTrue(runbookDoc.contains(term), "runbook doc should include \(term)")
}

for functionName in ["caricature", "nearby-presence", "sync-walk", "sync-profile", "rival-league", "quest-engine", "feature-control", "upload-profile-image"] {
    assertTrue(matrixDoc.contains("`\(functionName)`"), "adoption matrix should include \(functionName)")
}
assertTrue(matrixDoc.contains("Wave 1") && matrixDoc.contains("Wave 2") && matrixDoc.contains("Wave 3"), "adoption matrix should describe staged adoption")

assertTrue(caricature.contains("request_id") && caricature.contains("fallback_used") && caricature.contains("latency_ms"), "caricature should expose advanced observability metadata in source")
assertTrue(edgeAuthHelper.contains("function_name") && edgeAuthHelper.contains("request_id") && edgeAuthHelper.contains("auth_mode"), "shared edge auth helper should expose observability metadata in auth failures")
assertTrue(edgeAuthHelper.contains("AUTH_SESSION_INVALID") && edgeAuthHelper.contains("AUTH_MODE_NOT_ALLOWED"), "shared edge auth helper should expose canonical auth error codes")
assertTrue(nearbyPresence.contains("suppression_reason") && nearbyPresence.contains("abuse_reason"), "nearby presence should expose privacy and abuse metadata in source")
assertTrue(nearbyPresence.contains("console.error(\"nearby hotspot rpc failed\""), "nearby presence should log hotspot rpc failure")
assertTrue(syncWalk.contains("resolveEdgeAuthContext"), "sync-walk should route auth failures through shared helper")
assertTrue(questEngine.contains("resolveCanonicalRequestId") && questEngine.contains("request_id: requestId"), "quest-engine should expose canonical request id trace mentioned in the matrix")
assertTrue(featureControl.contains("json({ error: \"SERVER_MISCONFIGURED\" }"), "feature-control should expose legacy error shape covered by the matrix")
assertTrue(uploadProfileImage.contains("UPLOAD_FAILED") && uploadProfileImage.contains("PUBLIC_URL_FAILED"), "upload-profile-image should expose storage failure codes")

assertTrue(readme.contains("docs/backend-edge-observability-standard-v1.md"), "README should link backend edge observability standard doc")
assertTrue(readme.contains("docs/backend-edge-error-taxonomy-v1.md"), "README should link backend edge error taxonomy doc")
assertTrue(readme.contains("docs/backend-edge-incident-runbook-v1.md"), "README should link backend edge incident runbook doc")
assertTrue(readme.contains("docs/backend-edge-observability-adoption-matrix-v1.md"), "README should link backend edge adoption matrix doc")
assertTrue(backendCheck.contains("backend_edge_observability_unit_check.swift"), "backend_pr_check should run backend edge observability unit check")
assertTrue(iosPRCheck.contains("backend_edge_observability_unit_check.swift"), "ios_pr_check should run backend edge observability unit check")

print("PASS: backend edge observability unit checks")
