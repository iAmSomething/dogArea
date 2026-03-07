import Foundation

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 검증 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 파일을 UTF-8 문자열로 읽어옵니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 디코딩된 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

/// 여러 파일을 순서대로 읽어 한 문자열로 병합합니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let helper = load("supabase/functions/_shared/request_keys.ts")
let syncWalk = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-walk/support/types.ts",
    "supabase/functions/sync-walk/handlers/session_stage.ts",
    "supabase/functions/sync-walk/handlers/points_stage.ts",
    "supabase/functions/sync-walk/handlers/meta_stage.ts",
    "supabase/functions/sync-walk/handlers/backfill_summary.ts"
])
let nearbyPresence = loadMany([
    "supabase/functions/nearby-presence/index.ts",
    "supabase/functions/nearby-presence/support/types.ts",
    "supabase/functions/nearby-presence/support/visibility.ts",
    "supabase/functions/nearby-presence/handlers/live_presence_handlers.ts",
    "supabase/functions/nearby-presence/handlers/hotspot_handler.ts"
])
let questEngine = load("supabase/functions/quest-engine/index.ts")
let presenceQuestService = load("dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift")
let policyDoc = load("docs/backend-request-correlation-idempotency-policy-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(helper.contains("resolveCanonicalRequestId"), "shared request key helper should define canonical request id resolver")
assertTrue(helper.contains("resolveCanonicalIdempotencyKey"), "shared request key helper should define canonical idempotency resolver")
assertTrue(helper.contains("request_id") && helper.contains("action_id"), "shared helper should support request_id and action_id aliases")
assertTrue(helper.contains("idempotency_key") && helper.contains("idempotencyKey"), "shared helper should support snake/camel idempotency aliases")

assertTrue(syncWalk.contains("resolveCanonicalRequestId"), "sync-walk should resolve canonical request_id")
assertTrue(syncWalk.contains("resolveCanonicalIdempotencyKey"), "sync-walk should resolve canonical idempotency_key")
assertTrue(syncWalk.contains("request_id"), "sync-walk responses should expose request_id")
assertTrue(syncWalk.contains("idempotency_key"), "sync-walk stage responses should expose idempotency_key")

assertTrue(nearbyPresence.contains("resolveCanonicalRequestId"), "nearby-presence should resolve canonical request_id")
assertTrue(nearbyPresence.contains("resolveCanonicalIdempotencyKey"), "nearby-presence should resolve canonical idempotency key")
assertTrue(nearbyPresence.contains("action_id"), "nearby-presence should allow action_id alias")
assertTrue(nearbyPresence.contains("request_id: context.requestId"), "nearby-presence responses should expose request_id")
assertTrue(nearbyPresence.contains("idempotency_key"), "nearby-presence live upsert should carry canonical idempotency key")

assertTrue(questEngine.contains("resolveCanonicalRequestId"), "quest-engine should resolve canonical request_id")
assertTrue(questEngine.contains("resolveCanonicalIdempotencyKey"), "quest-engine should resolve canonical idempotency/event key")
assertTrue(questEngine.contains("instance_id") && questEngine.contains("target_instance_id"), "quest-engine should accept canonical and legacy instance id aliases")
assertTrue(questEngine.contains("event_id") && questEngine.contains("eventId"), "quest-engine should accept canonical and legacy event id aliases")
assertTrue(questEngine.contains("request_id: requestId"), "quest-engine success responses should expose request_id")

assertTrue(presenceQuestService.contains("payload[\"request_id\"] = idempotencyKey"), "nearby presence iOS service should send canonical request_id")
assertTrue(presenceQuestService.contains("payload[\"idempotency_key\"] = idempotencyKey"), "nearby presence iOS service should send canonical idempotency_key")
assertTrue(presenceQuestService.contains("\"instance_id\": canonicalQuestId"), "quest claim iOS service should send canonical instance_id")
assertTrue(presenceQuestService.contains("\"request_id\": normalizedRequestId"), "quest claim iOS service should send canonical request_id")

assertTrue(policyDoc.contains("`request_id`"), "policy doc should define request_id canonical name")
assertTrue(policyDoc.contains("`idempotency_key`"), "policy doc should define idempotency_key canonical name")
assertTrue(policyDoc.contains("`event_id`"), "policy doc should define event_id role")
assertTrue(policyDoc.contains("`action_id`"), "policy doc should define action_id translation rule")
assertTrue(policyDoc.contains("supabase/functions/_shared/request_keys.ts"), "policy doc should reference shared request key helper")

assertTrue(readme.contains("docs/backend-request-correlation-idempotency-policy-v1.md"), "README should link request/idempotency policy doc")
assertTrue(backendCheck.contains("backend_request_id_idempotency_unit_check.swift"), "backend_pr_check should run request/idempotency check")
assertTrue(iosPRCheck.contains("backend_request_id_idempotency_unit_check.swift"), "ios_pr_check should run request/idempotency check")

print("PASS: backend request_id/idempotency_key unit checks")
