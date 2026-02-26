import Foundation

struct Check {
    static var failed = false

    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

let coreDataDTO = read("dogArea/Source/CoreDataDTO.swift")
let userDefaultsSource = read("dogArea/Source/UserdefaultSetting.swift")
let mapViewModel = read("dogArea/Views/MapView/MapViewModel.swift")
let syncWalkFunction = read("supabase/functions/sync-walk/index.ts")
let backfillDoc = read("docs/coredata-supabase-backfill.md")

Check.assertTrue(coreDataDTO.contains("struct WalkSessionBackfillDTO"), "backfill session DTO should exist")
Check.assertTrue(coreDataDTO.contains("struct WalkPointBackfillDTO"), "backfill point DTO should exist")
Check.assertTrue(coreDataDTO.contains("enum CoreDataSupabaseBackfillDTOConverter"), "converter should exist")
Check.assertTrue(coreDataDTO.contains("pointsJSONString"), "converter output must encode points JSON")

Check.assertTrue(userDefaultsSource.contains("func enqueueWalkStages(sessionDTO:"), "outbox enqueue should accept backfill DTO")
Check.assertTrue(userDefaultsSource.contains("\"points_json\""), "points stage must include points_json payload")
Check.assertTrue(userDefaultsSource.contains("fetchBackfillValidationSummary"), "transport should fetch remote backfill summary")
Check.assertTrue(userDefaultsSource.contains("validationPassed"), "upgrade report should include validation result")

Check.assertTrue(mapViewModel.contains("CoreDataSupabaseBackfillDTOConverter.makeSessionDTO"), "map flow should use backfill DTO converter")

Check.assertTrue(syncWalkFunction.contains("sync_walk_stage"), "sync-walk function should handle sync_walk_stage action")
Check.assertTrue(syncWalkFunction.contains("get_backfill_summary"), "sync-walk function should handle backfill summary action")
Check.assertTrue(syncWalkFunction.contains("walk_points"), "sync-walk function should write walk_points")
Check.assertTrue(syncWalkFunction.contains("onConflict: \"walk_session_id,seq_no\""), "points upsert should be idempotent")

Check.assertTrue(backfillDoc.contains("Outbox stage payload"), "backfill contract doc should define stage payload")
Check.assertTrue(backfillDoc.contains("허용 오차"), "backfill contract doc should define validation tolerance")

if Check.failed {
    exit(1)
}

print("All coredata-supabase backfill checks passed.")
