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

let index = load("supabase/functions/sync-walk/index.ts")
let types = load("supabase/functions/sync-walk/support/types.ts")
let core = load("supabase/functions/sync-walk/support/core.ts")
let backfill = load("supabase/functions/sync-walk/handlers/backfill_summary.ts")
let sessionStage = load("supabase/functions/sync-walk/handlers/session_stage.ts")
let metaStage = load("supabase/functions/sync-walk/handlers/meta_stage.ts")
let pointsStage = load("supabase/functions/sync-walk/handlers/points_stage.ts")
let pointsPost = load("supabase/functions/sync-walk/handlers/points_stage_post_processing.ts")
let dispatcher = load("supabase/functions/sync-walk/handlers/stage_dispatcher.ts")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(index.contains("handleBackfillSummary"), "index should delegate backfill summary to dedicated handler")
assertTrue(index.contains("dispatchSyncWalkStage"), "index should delegate sync_walk_stage dispatch")
assertTrue(index.contains("resolveEdgeAuthContext"), "index should keep auth boundary")
assertTrue(!index.contains("rpc_apply_weather_replacement"), "index should not inline points post-processing RPC calls")
assertTrue(!index.contains("from(\"walk_points\")"), "index should not persist walk points inline")

assertTrue(types.contains("type SyncWalkStageRequestContext"), "types file should define stage request context")
assertTrue(core.contains("buildBaseSession"), "core support should build base session payload")
assertTrue(core.contains("logSyncWalkStageFailure"), "core support should expose stage failure logger")

assertTrue(backfill.contains("handleBackfillSummary"), "backfill handler file should define summary handler")
assertTrue(sessionStage.contains("handleSessionStage"), "session stage file should define session handler")
assertTrue(metaStage.contains("handleMetaStage"), "meta stage file should define meta handler")
assertTrue(pointsStage.contains("handlePointsStage"), "points stage file should define points handler")
assertTrue(pointsPost.contains("runPointsStagePostProcessing"), "points post-processing file should orchestrate downstream RPC calls")
assertTrue(pointsPost.contains("rpc_score_walk_session_anti_farming"), "points post-processing should handle season scoring")
assertTrue(pointsPost.contains("rpc_ingest_season_tile_events"), "points post-processing should handle season pipeline ingest")
assertTrue(pointsPost.contains("rpc_apply_weather_replacement"), "points post-processing should handle weather replacement")
assertTrue(pointsPost.contains("rpc_apply_quest_progress_event"), "points post-processing should handle quest progress")
assertTrue(dispatcher.contains("syncWalkStageHandlers"), "stage dispatcher should define stage handler map")
assertTrue(dispatcher.contains("isSupportedSyncStage"), "stage dispatcher should validate supported stages")

assertTrue(backendCheck.contains("sync_walk_stage_handler_split_unit_check.swift"), "backend_pr_check should run sync-walk split check")
assertTrue(iosPRCheck.contains("sync_walk_stage_handler_split_unit_check.swift"), "ios_pr_check should run sync-walk split check")

print("PASS: sync-walk stage handler split unit checks")
