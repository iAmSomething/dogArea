import Foundation

enum RivalLeague: String {
    case onboarding
    case light
    case mid
    case hardcore
}

struct RivalPolicy {
    let lightMaxPercentile: Double
    let midMaxPercentile: Double
    let minSessionsForRanked: Int
    let minSamplePerLeague: Int

    static let v1 = RivalPolicy(
        lightMaxPercentile: 0.33,
        midMaxPercentile: 0.66,
        minSessionsForRanked: 2,
        minSamplePerLeague: 3
    )
}

struct RivalUserActivity {
    let id: String
    let sessionCount: Int
    let activityScore: Double
}

struct RivalAssignment {
    let id: String
    let league: RivalLeague
    let effectiveLeague: RivalLeague
}

func percentileRank(index: Int, total: Int) -> Double {
    guard total > 1 else { return 1.0 }
    return Double(index) / Double(total - 1)
}

func assignLeagues(activities: [RivalUserActivity], policy: RivalPolicy = .v1) -> [RivalAssignment] {
    let ranked = activities.sorted {
        if $0.activityScore == $1.activityScore {
            return $0.id < $1.id
        }
        return $0.activityScore < $1.activityScore
    }

    var base: [(String, RivalLeague)] = []
    for (index, activity) in ranked.enumerated() {
        if activity.sessionCount < policy.minSessionsForRanked {
            base.append((activity.id, .onboarding))
            continue
        }
        let percentile = percentileRank(index: index, total: ranked.count)
        if percentile <= policy.lightMaxPercentile {
            base.append((activity.id, .light))
        } else if percentile <= policy.midMaxPercentile {
            base.append((activity.id, .mid))
        } else {
            base.append((activity.id, .hardcore))
        }
    }

    let counts = Dictionary(grouping: base, by: { $0.1 }).mapValues(\.count)

    func fallback(_ league: RivalLeague) -> RivalLeague {
        guard league != .onboarding else { return .onboarding }
        guard (counts[league] ?? 0) < policy.minSamplePerLeague else { return league }
        switch league {
        case .light, .hardcore:
            return .mid
        case .mid:
            return (counts[.hardcore] ?? 0) >= (counts[.light] ?? 0) ? .hardcore : .light
        case .onboarding:
            return .onboarding
        }
    }

    return base.map { item in
        .init(id: item.0, league: item.1, effectiveLeague: fallback(item.1))
    }
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

let migration = load("supabase/migrations/20260227212000_rival_fair_league_matching.sql")
let edgeFunction = load("supabase/functions/rival-league/index.ts")
let doc = load("docs/rival-fair-league-v1.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.rival_league_policies"), "migration should create rival_league_policies")
assertTrue(migration.contains("create table if not exists public.rival_league_assignments"), "migration should create rival_league_assignments")
assertTrue(migration.contains("create table if not exists public.rival_league_history"), "migration should create rival_league_history")
assertTrue(migration.contains("rpc_refresh_rival_leagues"), "migration should define rival weekly refresh rpc")
assertTrue(migration.contains("rpc_get_my_rival_league"), "migration should define rival league query rpc")
assertTrue(migration.contains("view_rival_league_distribution_current"), "migration should expose rival league distribution view")

assertTrue(edgeFunction.contains("get_my_league"), "rival edge function should expose get_my_league action")
assertTrue(edgeFunction.contains("rpc_get_my_rival_league"), "rival edge function should call rival league rpc")

assertTrue(doc.contains("최근 `14일`"), "rival doc should define 14-day lookback")
assertTrue(doc.contains("주 1회"), "rival doc should define weekly cadence")
assertTrue(doc.contains("effective_league"), "rival doc should include fallback effective league contract")
assertTrue(schemaDoc.contains("라이벌 공정 리그 매칭"), "schema doc should include rival league section")
assertTrue(migrationDoc.contains("rpc_refresh_rival_leagues"), "ops doc should include rival refresh verification")
assertTrue(checklist.contains("effective_league"), "release checklist should include rival fallback scenario")
assertTrue(readme.contains("docs/rival-fair-league-v1.md"), "README should reference rival fair league doc")

let activities: [RivalUserActivity] = [
    .init(id: "u1", sessionCount: 5, activityScore: 8),
    .init(id: "u2", sessionCount: 4, activityScore: 12),
    .init(id: "u3", sessionCount: 4, activityScore: 18),
    .init(id: "u4", sessionCount: 3, activityScore: 25),
    .init(id: "u5", sessionCount: 3, activityScore: 27),
    .init(id: "u6", sessionCount: 1, activityScore: 2),
    .init(id: "u7", sessionCount: 6, activityScore: 40),
    .init(id: "u8", sessionCount: 7, activityScore: 60)
]

let assignments = assignLeagues(activities: activities)
let onboarding = assignments.filter { $0.league == .onboarding }
assertTrue(onboarding.count == 1, "low-session users should stay in onboarding league")

let hasFallback = assignments.contains { $0.league != $0.effectiveLeague }
assertTrue(hasFallback, "insufficient sample leagues should be merged through effective league fallback")

let highActivity = assignments.first(where: { $0.id == "u8" })
assertTrue(highActivity?.league == .hardcore, "top activity user should be assigned to hardcore league")

print("PASS: rival league matching unit checks")
