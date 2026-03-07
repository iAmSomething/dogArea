import Foundation

struct SeasonPolicy {
    let repeatCooldownMinutes: Int
    let baseTileScore: Double
    let newRouteBonusWeight: Double
    let suspiciousRepeatThreshold: Int
    let suspiciousMaxNoveltyRatio: Double
    let suspiciousLowMovementMeters: Double
    let suspiciousBlockEnabled: Bool

    static let v1 = SeasonPolicy(
        repeatCooldownMinutes: 30,
        baseTileScore: 1.0,
        newRouteBonusWeight: 0.7,
        suspiciousRepeatThreshold: 10,
        suspiciousMaxNoveltyRatio: 0.35,
        suspiciousLowMovementMeters: 120,
        suspiciousBlockEnabled: true
    )
}

struct PointEvent {
    let tile: String
    let minute: Int
    let distanceFromPrev: Double
}

struct ScoreSummary {
    let totalPoints: Int
    let uniqueTiles: Int
    let noveltyRatio: Double
    let repeatSuppressedCount: Int
    let totalScore: Double
    let blocked: Bool
}

func scoreSession(_ events: [PointEvent], policy: SeasonPolicy = .v1) -> ScoreSummary {
    guard events.isEmpty == false else {
        return ScoreSummary(totalPoints: 0, uniqueTiles: 0, noveltyRatio: 0, repeatSuppressedCount: 0, totalScore: 0, blocked: false)
    }

    let totalPoints = events.count
    let uniqueTiles = Set(events.map(\.tile)).count
    let noveltyRatio = Double(uniqueTiles) / Double(totalPoints)

    var lastSeenByTile: [String: Int] = [:]
    var firstHitByTile: Set<String> = []
    var repeatSuppressedCount = 0
    var totalDistance = 0.0
    var rawScore = 0.0

    for event in events {
        totalDistance += event.distanceFromPrev

        let lastSeenMinute = lastSeenByTile[event.tile]
        let isRepeatWithinCooldown: Bool
        if let lastSeenMinute {
            isRepeatWithinCooldown = (event.minute - lastSeenMinute) <= policy.repeatCooldownMinutes
        } else {
            isRepeatWithinCooldown = false
        }

        let isFirstHit = firstHitByTile.contains(event.tile) == false
        if isFirstHit {
            firstHitByTile.insert(event.tile)
        }

        let base = isRepeatWithinCooldown ? 0.0 : policy.baseTileScore
        let bonus = (isFirstHit && isRepeatWithinCooldown == false)
            ? policy.baseTileScore * policy.newRouteBonusWeight * noveltyRatio
            : 0.0

        rawScore += base + bonus
        if isRepeatWithinCooldown {
            repeatSuppressedCount += 1
        }

        lastSeenByTile[event.tile] = event.minute
    }

    let blocked = policy.suspiciousBlockEnabled
        && repeatSuppressedCount >= policy.suspiciousRepeatThreshold
        && noveltyRatio <= policy.suspiciousMaxNoveltyRatio
        && totalDistance <= policy.suspiciousLowMovementMeters

    return ScoreSummary(
        totalPoints: totalPoints,
        uniqueTiles: uniqueTiles,
        noveltyRatio: noveltyRatio,
        repeatSuppressedCount: repeatSuppressedCount,
        totalScore: blocked ? 0.0 : rawScore,
        blocked: blocked
    )
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let migration = load("supabase/migrations/20260227195500_season_anti_farming_rules.sql")
let syncWalkFunction = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-walk/support/core.ts",
    "supabase/functions/sync-walk/support/types.ts",
    "supabase/functions/sync-walk/handlers/points_stage.ts",
    "supabase/functions/sync-walk/handlers/points_stage_post_processing.ts"
])
let doc = load("docs/season-anti-farming-v1.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.season_scoring_policies"), "migration should create season_scoring_policies")
assertTrue(migration.contains("create table if not exists public.season_tile_score_events"), "migration should create season_tile_score_events")
assertTrue(migration.contains("create table if not exists public.season_score_audit_logs"), "migration should create season_score_audit_logs")
assertTrue(migration.contains("create or replace function public.rpc_score_walk_session_anti_farming"), "migration should define season scoring rpc")
assertTrue(migration.contains("repeat_within_30m"), "migration should include repeat suppression reason")
assertTrue(migration.contains("new_route_bonus_weight"), "migration should include novelty bonus parameter")

assertTrue(syncWalkFunction.contains("rpc_score_walk_session_anti_farming"), "sync-walk function should call season scoring rpc")
assertTrue(syncWalkFunction.contains("season_score_summary"), "sync-walk response should include season score summary")

assertTrue(doc.contains("동일 타일"), "season anti-farming doc should describe repeat suppression")
assertTrue(doc.contains("신규 경로"), "season anti-farming doc should describe novelty bonus")
assertTrue(doc.contains("score_blocked"), "season anti-farming doc should describe blocking state")
assertTrue(schemaDoc.contains("시즌 안티 농사 점수"), "schema doc should include season anti-farming section")
assertTrue(migrationDoc.contains("rpc_score_walk_session_anti_farming"), "migration ops doc should include season rpc verification")
assertTrue(readme.contains("docs/season-anti-farming-v1.md"), "README should reference season anti-farming doc")

let repeatedTileEvents = [
    PointEvent(tile: "A", minute: 0, distanceFromPrev: 0),
    PointEvent(tile: "A", minute: 2, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 5, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 8, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 11, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 14, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 17, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 20, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 23, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 26, distanceFromPrev: 1),
    PointEvent(tile: "A", minute: 29, distanceFromPrev: 1)
]

let repeatedSummary = scoreSession(repeatedTileEvents)
assertTrue(repeatedSummary.repeatSuppressedCount == 10, "repeated tile entries within 30 minutes should be suppressed")
assertTrue(repeatedSummary.blocked, "high repeat + low novelty + low movement should trigger block")
assertTrue(repeatedSummary.totalScore == 0, "blocked session should have zero score")

let noveltyHighEvents = [
    PointEvent(tile: "A", minute: 0, distanceFromPrev: 30),
    PointEvent(tile: "B", minute: 5, distanceFromPrev: 40),
    PointEvent(tile: "C", minute: 10, distanceFromPrev: 35),
    PointEvent(tile: "D", minute: 15, distanceFromPrev: 32),
    PointEvent(tile: "E", minute: 20, distanceFromPrev: 28),
    PointEvent(tile: "F", minute: 25, distanceFromPrev: 36)
]

let noveltyHighSummary = scoreSession(noveltyHighEvents)
assertTrue(noveltyHighSummary.noveltyRatio > 0.9, "new route-heavy session should have high novelty ratio")
assertTrue(noveltyHighSummary.repeatSuppressedCount == 0, "new route-heavy session should not be suppressed")
assertTrue(noveltyHighSummary.blocked == false, "new route-heavy session should not be blocked")
assertTrue(noveltyHighSummary.totalScore > 6.0, "new route-heavy session should receive base + novelty bonus")

print("PASS: season anti-farming unit checks")
