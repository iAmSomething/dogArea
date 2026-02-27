import Foundation

struct CatchupPolicy {
    let inactivityThresholdHours: Double
    let buffActiveHours: Double
    let boostRate: Double
    let weeklyIssueLimit: Int
    let seasonEndBlockHours: Double

    static let v1 = CatchupPolicy(
        inactivityThresholdHours: 72,
        buffActiveHours: 48,
        boostRate: 0.20,
        weeklyIssueLimit: 1,
        seasonEndBlockHours: 24
    )
}

struct BuffGrant {
    let grantedAtHour: Double
    let status: String
}

enum CatchupDecision: Equatable {
    case granted(expiresAtHour: Double)
    case blocked(reason: String)
}

func evaluateCatchupDecision(
    nowHour: Double,
    seasonWeekEndHour: Double,
    lastActivityHour: Double?,
    weeklyGrants: [BuffGrant],
    policy: CatchupPolicy = .v1
) -> CatchupDecision {
    let blockWindowStart = seasonWeekEndHour - policy.seasonEndBlockHours
    if nowHour >= blockWindowStart {
        return .blocked(reason: "season_end_window")
    }

    let weeklyIssuedCount = weeklyGrants.filter { $0.status == "active" || $0.status == "expired" }.count
    if weeklyIssuedCount >= policy.weeklyIssueLimit {
        return .blocked(reason: "weekly_limit_reached")
    }

    guard let lastActivityHour else {
        return .blocked(reason: "no_prior_activity")
    }

    let inactivityHours = nowHour - lastActivityHour
    if inactivityHours < policy.inactivityThresholdHours {
        return .blocked(reason: "insufficient_inactivity")
    }

    return .granted(expiresAtHour: nowHour + policy.buffActiveHours)
}

func catchupBonus(newTileScore: Double, isActive: Bool, scoreBlocked: Bool, policy: CatchupPolicy = .v1) -> Double {
    guard isActive, scoreBlocked == false else { return 0 }
    return newTileScore * policy.boostRate
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

let migration = load("supabase/migrations/20260227223000_season_comeback_catchup_buff.sql")
let syncWalkFunction = load("supabase/functions/sync-walk/index.ts")
let userDefaultsStore = load("dogArea/Source/UserdefaultSetting.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let doc = load("docs/season-comeback-catchup-buff-v1.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.season_catchup_buff_policies"), "migration should create season_catchup_buff_policies")
assertTrue(migration.contains("create table if not exists public.season_catchup_buff_grants"), "migration should create season_catchup_buff_grants")
assertTrue(migration.contains("season_end_block_hours"), "migration should include season_end_block_hours policy")
assertTrue(migration.contains("weekly_issue_limit"), "migration should include weekly_issue_limit policy")
assertTrue(migration.contains("catchup_bonus"), "migration should return catchup_bonus")
assertTrue(migration.contains("catchup_buff_active"), "migration should return catchup_buff_active")
assertTrue(migration.contains("view_season_catchup_buff_kpis_14d"), "migration should define catchup KPI view")

assertTrue(syncWalkFunction.contains("catchup_bonus"), "sync-walk dto should include catchup_bonus")
assertTrue(syncWalkFunction.contains("catchup_buff_active"), "sync-walk dto should include catchup_buff_active")
assertTrue(syncWalkFunction.contains("catchup_buff_expires_at"), "sync-walk dto should include catchup_buff_expires_at")

assertTrue(userDefaultsStore.contains("seasonCatchupBuffSnapshot"), "UserdefaultSetting should persist season catchup snapshot")
assertTrue(userDefaultsStore.contains("seasonCatchupBuffDidUpdateNotification"), "UserdefaultSetting should expose catchup notification")
assertTrue(homeViewModel.contains("seasonCatchupBuffStatusMessage"), "HomeViewModel should expose catchup status message")
assertTrue(homeView.contains("seasonCatchupBuffStatusMessage"), "HomeView should render catchup status banner")

assertTrue(doc.contains("72시간"), "catchup doc should describe 72-hour inactivity policy")
assertTrue(doc.contains("48h"), "catchup doc should describe 48-hour active window")
assertTrue(doc.contains("+20%"), "catchup doc should describe +20 percent boost")
assertTrue(schemaDoc.contains("season_catchup_buff_policies"), "schema doc should include catchup policy table")
assertTrue(migrationDoc.contains("season_catchup_buff_grants"), "migration ops doc should include catchup grants verification")
assertTrue(readme.contains("docs/season-comeback-catchup-buff-v1.md"), "README should reference catchup doc")

let granted = evaluateCatchupDecision(
    nowHour: 200,
    seasonWeekEndHour: 240,
    lastActivityHour: 120,
    weeklyGrants: []
)
if case .granted(let expiresAt) = granted {
    assertTrue(abs(expiresAt - 248) < 0.0001, "granted decision should set 48-hour expiry")
} else {
    assertTrue(false, "72-hour inactivity should grant catchup buff")
}

let insufficientInactivity = evaluateCatchupDecision(
    nowHour: 200,
    seasonWeekEndHour: 240,
    lastActivityHour: 150,
    weeklyGrants: []
)
assertTrue(insufficientInactivity == .blocked(reason: "insufficient_inactivity"), "recent activity should block catchup grant")

let weeklyLimitBlocked = evaluateCatchupDecision(
    nowHour: 200,
    seasonWeekEndHour: 240,
    lastActivityHour: 100,
    weeklyGrants: [BuffGrant(grantedAtHour: 170, status: "active")]
)
assertTrue(weeklyLimitBlocked == .blocked(reason: "weekly_limit_reached"), "weekly issue limit should block second grant")

let seasonEndBlocked = evaluateCatchupDecision(
    nowHour: 219,
    seasonWeekEndHour: 240,
    lastActivityHour: 100,
    weeklyGrants: []
)
assertTrue(seasonEndBlocked == .blocked(reason: "season_end_window"), "season end window should block new grant")

let boosted = catchupBonus(newTileScore: 15, isActive: true, scoreBlocked: false)
assertTrue(abs(boosted - 3.0) < 0.0001, "new tile score should receive +20 percent boost when active")
assertTrue(catchupBonus(newTileScore: 15, isActive: false, scoreBlocked: false) == 0, "inactive catchup should not add bonus")
assertTrue(catchupBonus(newTileScore: 15, isActive: true, scoreBlocked: true) == 0, "blocked session should not add catchup bonus")

print("PASS: season comeback catchup unit checks")
