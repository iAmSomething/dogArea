import Foundation

/// 조건식을 검증하고 실패 시 오류 메시지를 출력한 뒤 프로세스를 종료합니다.
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

let index = load("supabase/functions/nearby-presence/index.ts")
let types = load("supabase/functions/nearby-presence/support/types.ts")
let core = load("supabase/functions/nearby-presence/support/core.ts")
let hotspotCompat = load("supabase/functions/nearby-presence/support/hotspot_compat.ts")
let livePresence = load("supabase/functions/nearby-presence/support/live_presence.ts")
let privacyAudit = load("supabase/functions/nearby-presence/support/privacy_audit.ts")
let visibility = load("supabase/functions/nearby-presence/support/visibility.ts")
let hotspotHandler = load("supabase/functions/nearby-presence/handlers/hotspot_handler.ts")
let livePresenceHandlers = load("supabase/functions/nearby-presence/handlers/live_presence_handlers.ts")
let dispatcher = load("supabase/functions/nearby-presence/handlers/action_dispatcher.ts")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(index.contains("dispatchNearbyPresenceAction"), "index should delegate action handling to dispatcher")
assertTrue(index.contains("isSupportedNearbyPresenceAction"), "index should validate supported nearby actions")
assertTrue(index.contains("resolveEdgeAuthContext"), "index should retain auth boundary")
assertTrue(!index.contains("rpc_get_nearby_hotspots"), "index should not inline hotspot RPC compat path")
assertTrue(!index.contains("privacy_guard_audit_logs"), "index should not inline privacy audit inserts")

assertTrue(types.contains("type ResponseHotspotDTO"), "types file should define hotspot response contract")
assertTrue(types.contains("type ResponseLivePresenceDTO"), "types file should define live presence response contract")
assertTrue(core.contains("geohashEncode"), "core support should keep geohash utility")
assertTrue(core.contains("asUUIDArray"), "core support should keep request normalization helpers")
assertTrue(hotspotCompat.contains("getNearbyHotspotsWithCompatRPC"), "hotspot compat file should define compat helper")
assertTrue(hotspotCompat.contains("in_center_lat") && hotspotCompat.contains("center_lat"), "hotspot compat should keep latest and legacy RPC signatures")
assertTrue(livePresence.contains("upsertLivePresence"), "live presence support should define upsert helper")
assertTrue(livePresence.contains("rpc_upsert_walk_live_presence"), "live presence support should call live presence RPC")
assertTrue(privacyAudit.contains("insertHotspotPrivacyAuditLog"), "privacy audit file should define hotspot audit logger")
assertTrue(privacyAudit.contains("insertLivePresencePrivacyAuditLog"), "privacy audit file should define live audit logger")
assertTrue(visibility.contains("handleSetVisibility"), "visibility support should define set_visibility handler")
assertTrue(visibility.contains("handleUpsertPresence"), "visibility support should define legacy upsert_presence handler")
assertTrue(hotspotHandler.contains("handleGetHotspots"), "hotspot handler file should define get_hotspots handler")
assertTrue(livePresenceHandlers.contains("handleUpsertLivePresence"), "live presence handler file should define upsert_live_presence handler")
assertTrue(livePresenceHandlers.contains("handleGetLivePresence"), "live presence handler file should define get_live_presence handler")
assertTrue(dispatcher.contains("nearbyPresenceActionHandlers"), "dispatcher should define action handler map")

assertTrue(backendCheck.contains("nearby_presence_handler_split_unit_check.swift"), "backend_pr_check should run nearby-presence split check")
assertTrue(iosPRCheck.contains("nearby_presence_handler_split_unit_check.swift"), "ios_pr_check should run nearby-presence split check")

print("PASS: nearby-presence handler split unit checks")
