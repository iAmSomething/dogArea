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

/// 여러 파일을 읽어 하나의 문자열로 합칩니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 이어붙인 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/backend-legacy-fallback-compat-sunset-plan-v1.md")
let readme = load("README.md")
let contractPolicy = load("docs/backend-contract-versioning-policy-v1.md")
let deployMatrix = load("docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md")
let requestPolicy = load("docs/backend-request-correlation-idempotency-policy-v1.md")
let secretRunbook = load("docs/backend-edge-secret-inventory-rotation-runbook-v1.md")
let areaGovernance = load("docs/area-references-data-governance.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let nearbyCompat = load("supabase/functions/nearby-presence/support/hotspot_compat.ts")
let questReadme = load("supabase/functions/quest-engine/README.md")
let authInventory = load("docs/backend-edge-auth-mode-inventory-v1.md")
let syncWalkPolicy = load("docs/sync-walk-404-fallback-policy-v1.md")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let scriptBundle = loadMany([
    "scripts/sync_walk_404_policy_unit_check.swift",
    "scripts/rival_rpc_param_compat_unit_check.swift",
    "scripts/feature_control_404_cooldown_unit_check.swift",
    "scripts/caricature_proxy_unit_check.swift",
    "scripts/backend_request_id_idempotency_unit_check.swift",
    "scripts/area_reference_catalog_seed_unit_check.swift"
])
let removedGeminiAliasMessage = "should not support the removed Gemini alias"

for token in [
    "temporary_compat_debt",
    "long_lived_safety_rail",
    "legacy_data_bridge",
    "sync_walk",
    "rpc_get_rival_leaderboard",
    "rpc_get_widget_quest_rival_summary",
    "rpc_get_nearby_hotspots",
    "requestId",
    "eventId",
    "feature-control",
    "area_references.category = legacy",
    "#479"
] {
    assertTrue(doc.contains(token), "sunset doc should mention \(token)")
}

for evidence in [
    "sync-walk.session.member",
    "sync-walk.summary.member",
    "rival-rpc.compat.member",
    "widget-hotspot.summary.member",
    "widget-quest-rival.summary.member",
    "feature-control.flags.anon",
    "feature-control.rollout_kpis.anon"
] {
    assertTrue(doc.contains(evidence), "sunset doc should mention evidence source \(evidence)")
    assertTrue(smokeRunner.contains(evidence), "smoke runner should still contain \(evidence)")
}

assertTrue(contractPolicy.contains("fallback은 `무제한 누적` 금지"), "contract policy should still define fallback accumulation rule")
assertTrue(deployMatrix.contains("sync-walk"), "deploy matrix should still cover sync-walk")
assertTrue(
    requestPolicy.contains("legacy alias `instanceId`, `target_instance_id`, `eventId`도 계속 허용합니다."),
    "request policy should still mention quest legacy aliases"
)
assertTrue(secretRunbook.contains("legacy alias는 `#479`에서 제거되었습니다."), "secret runbook should record the legacy Gemini alias removal")
assertTrue(areaGovernance.contains("`legacy`"), "area governance doc should still mention legacy category")
assertTrue(authInventory.contains("legacy compat delegate"), "auth inventory should still mention compat delegate paths")
assertTrue(syncWalkPolicy.contains("legacy route fallback: `sync_walk`"), "sync-walk policy should still mention legacy route fallback")

assertTrue(nearbyCompat.contains("signature: \"legacy\""), "nearby hotspot compat helper should still expose legacy signature path")
assertTrue(questReadme.contains("legacy alias `requestId` / `eventId` / `instanceId` / `target_instance_id`"), "quest README should still mention legacy aliases")

assertTrue(scriptBundle.contains("SyncWalkFunctionRoute.legacy"), "sync-walk unit check bundle should still cover route fallback")
assertTrue(scriptBundle.contains("delegate migration should route 3-arg leaderboard RPC"), "rival rpc unit check bundle should still cover delegate migration")
assertTrue(scriptBundle.contains("feature-control service should define cooldown duration"), "feature-control unit check bundle should still cover cooldown")
assertTrue(scriptBundle.contains("edge function should read GEMINI_API_KEY"), "caricature unit check bundle should verify the canonical Gemini key")
assertTrue(scriptBundle.contains(removedGeminiAliasMessage), "caricature unit check bundle should verify removal of the legacy Gemini alias")
assertTrue(
    scriptBundle.contains("canonical and legacy instance id aliases") &&
        scriptBundle.contains("canonical and legacy event id aliases"),
    "request key unit check bundle should still cover legacy request aliases"
)
assertTrue(scriptBundle.contains("seed_version"), "area seed unit check bundle should still cover legacy seed bridge")

assertTrue(readme.contains("docs/backend-legacy-fallback-compat-sunset-plan-v1.md"), "README should link fallback sunset doc")
assertTrue(contractPolicy.contains("docs/backend-legacy-fallback-compat-sunset-plan-v1.md"), "contract policy should link fallback sunset doc")
assertTrue(deployMatrix.contains("docs/backend-legacy-fallback-compat-sunset-plan-v1.md"), "deploy matrix should link fallback sunset doc")
assertTrue(backendCheck.contains("backend_legacy_fallback_sunset_unit_check.swift"), "backend_pr_check should run fallback sunset unit check")
assertTrue(iosPRCheck.contains("backend_legacy_fallback_sunset_unit_check.swift"), "ios_pr_check should run fallback sunset unit check")

print("PASS: backend legacy fallback sunset unit checks")
