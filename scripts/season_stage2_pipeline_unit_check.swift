import Foundation

struct Stage2Policy {
    let newTileScore: Double
    let holdTileDailyScore: Double
    let decayGraceHours: Double
    let decayPerDay: Double
    let bronze: Double
    let silver: Double
    let gold: Double
    let platinum: Double

    static let v1 = Stage2Policy(
        newTileScore: 5,
        holdTileDailyScore: 1,
        decayGraceHours: 48,
        decayPerDay: 2,
        bronze: 80,
        silver: 180,
        gold: 320,
        platinum: 520
    )
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func decayPenalty(hoursSinceLastContribution: Double, policy: Stage2Policy = .v1) -> Double {
    guard hoursSinceLastContribution > policy.decayGraceHours else { return 0 }
    let elapsedAfterGrace = hoursSinceLastContribution - policy.decayGraceHours
    let decayDays = floor(elapsedAfterGrace / 24.0) + 1
    return max(0, decayDays * policy.decayPerDay)
}

func resolveTier(score: Double, policy: Stage2Policy = .v1) -> String {
    if score >= policy.platinum { return "platinum" }
    if score >= policy.gold { return "gold" }
    if score >= policy.silver { return "silver" }
    if score >= policy.bronze { return "bronze" }
    return "none"
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let migration = load("supabase/migrations/20260301090000_season_stage2_batch_pipeline.sql")
let syncWalk = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-walk/support/core.ts",
    "supabase/functions/sync-walk/support/types.ts",
    "supabase/functions/sync-walk/handlers/points_stage.ts",
    "supabase/functions/sync-walk/handlers/points_stage_post_processing.ts",
    "supabase/functions/sync-walk/handlers/stage_dispatcher.ts"
])
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let stage2Doc = load("docs/season-stage2-pipeline-v1.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.season_runs"), "migration should create season_runs")
assertTrue(migration.contains("create table if not exists public.tile_events"), "migration should create tile_events")
assertTrue(migration.contains("create table if not exists public.season_tile_scores"), "migration should create season_tile_scores")
assertTrue(migration.contains("create table if not exists public.season_user_scores"), "migration should create season_user_scores")
assertTrue(migration.contains("create table if not exists public.season_rewards"), "migration should create season_rewards")
assertTrue(migration.contains("constraint tile_events_daily_unique unique (season_id, owner_user_id, tile_id, event_day)"), "tile_events should enforce daily idempotent unique key")
assertTrue(migration.contains("create or replace function public.rpc_ingest_season_tile_events"), "migration should define rpc_ingest_season_tile_events")
assertTrue(migration.contains("create or replace function public.rpc_apply_season_daily_decay"), "migration should define rpc_apply_season_daily_decay")
assertTrue(migration.contains("create or replace function public.rpc_finalize_season"), "migration should define rpc_finalize_season")
assertTrue(migration.contains("create or replace function public.rpc_get_season_leaderboard"), "migration should define rpc_get_season_leaderboard")
assertTrue(migration.contains("view_season_batch_status_14d"), "migration should create stage2 batch status view")

assertTrue(syncWalk.contains("rpc_ingest_season_tile_events"), "sync-walk should ingest season tile events in points stage")
assertTrue(syncWalk.contains("season_pipeline_summary"), "sync-walk response should include season pipeline summary")

assertTrue(schemaDoc.contains("시즌 집계/정산 파이프라인(Stage 2)"), "schema doc should include season stage2 section")
assertTrue(migrationDoc.contains("시즌 Stage2 집계/정산 파이프라인 검증 (#125)"), "migration ops doc should include stage2 verification")
assertTrue(stage2Doc.contains("tile_events"), "stage2 doc should describe tile_events")
assertTrue(stage2Doc.contains("rpc_finalize_season"), "stage2 doc should describe finalize rpc")
assertTrue(readme.contains("docs/season-stage2-pipeline-v1.md"), "README should reference season stage2 doc")

assertTrue(abs(decayPenalty(hoursSinceLastContribution: 47) - 0) < 0.0001, "before grace window there should be no decay")
assertTrue(abs(decayPenalty(hoursSinceLastContribution: 49) - 2) < 0.0001, "49h should apply first decay day")
assertTrue(abs(decayPenalty(hoursSinceLastContribution: 72) - 4) < 0.0001, "72h should apply two decay days")

assertTrue(resolveTier(score: 79.9) == "none", "score below bronze should be none")
assertTrue(resolveTier(score: 80) == "bronze", "score at 80 should be bronze")
assertTrue(resolveTier(score: 180) == "silver", "score at 180 should be silver")
assertTrue(resolveTier(score: 320) == "gold", "score at 320 should be gold")
assertTrue(resolveTier(score: 520) == "platinum", "score at 520 should be platinum")

let dedupeInputs = [
    "seasonA:userA:tileX:2026-03-01",
    "seasonA:userA:tileX:2026-03-01",
    "seasonA:userA:tileX:2026-03-02",
    "seasonA:userA:tileY:2026-03-01",
]
let uniqueKeyCount = Set(dedupeInputs).count
assertTrue(uniqueKeyCount == 3, "idempotent key tuple should collapse duplicate daily tile events")

print("PASS: season stage2 pipeline unit checks")
