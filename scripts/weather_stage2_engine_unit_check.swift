import Foundation

struct WeatherStage2Policy {
    let dailyReplacementLimit: Int
    let weeklyShieldLimit: Int
}

struct WeatherStage2Decision: Equatable {
    let applied: Bool
    let shieldApplied: Bool
    let blockedReason: String?
}

func applyStage2Decision(
    riskLevel: String,
    replacementsToday: Int,
    shieldsUsedThisWeek: Int,
    policy: WeatherStage2Policy
) -> WeatherStage2Decision {
    guard ["caution", "bad", "severe"].contains(riskLevel) else {
        return .init(applied: false, shieldApplied: false, blockedReason: "risk_clear_or_unknown")
    }
    if replacementsToday >= policy.dailyReplacementLimit {
        return .init(applied: false, shieldApplied: false, blockedReason: "daily_limit_reached")
    }
    let shieldApplied = shieldsUsedThisWeek < policy.weeklyShieldLimit
    return .init(applied: true, shieldApplied: shieldApplied, blockedReason: nil)
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

let migration = load("supabase/migrations/20260228003000_weather_replacement_shield_engine.sql")
let syncWalk = load("supabase/functions/sync-walk/index.ts")
let policyDoc = load("docs/weather-replacement-shield-engine-v1.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let report = load("docs/cycle-134-weather-stage2-engine-report-2026-02-27.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.weather_replacement_runtime_policies"), "migration should create weather replacement runtime policy table")
assertTrue(migration.contains("create table if not exists public.weather_replacement_mappings"), "migration should create weather replacement mappings table")
assertTrue(migration.contains("create table if not exists public.weather_replacement_histories"), "migration should create weather replacement histories table")
assertTrue(migration.contains("create table if not exists public.weather_shield_ledgers"), "migration should create weather shield ledger table")
assertTrue(migration.contains("create or replace function public.rpc_apply_weather_replacement"), "migration should define weather replacement rpc")
assertTrue(migration.contains("daily_limit_reached"), "migration should return daily limit block reason")
assertTrue(migration.contains("risk_clear_or_unknown"), "migration should return clear risk block reason")
assertTrue(migration.contains("view_weather_replacement_audit_14d"), "migration should define weather replacement audit view")

assertTrue(syncWalk.contains("rpc_apply_weather_replacement"), "sync-walk should call weather replacement rpc")
assertTrue(syncWalk.contains("weather_replacement_summary"), "sync-walk response should include weather replacement summary")

assertTrue(policyDoc.contains("주당 1회"), "policy doc should define weekly shield limit")
assertTrue(policyDoc.contains("일일 치환 최대 1회"), "policy doc should define daily replacement limit")
assertTrue(policyDoc.contains("원 퀘스트"), "policy doc should preserve source quest in history")
assertTrue(schemaDoc.contains("weather_replacement_runtime_policies"), "schema doc should include weather replacement policy table")
assertTrue(migrationDoc.contains("rpc_apply_weather_replacement"), "migration ops doc should include weather replacement rpc verification")
assertTrue(readme.contains("docs/weather-replacement-shield-engine-v1.md"), "README should reference weather stage2 doc")
assertTrue(report.contains("#134"), "cycle report should reference issue #134")

let policy = WeatherStage2Policy(dailyReplacementLimit: 1, weeklyShieldLimit: 1)
let clearBlocked = applyStage2Decision(riskLevel: "clear", replacementsToday: 0, shieldsUsedThisWeek: 0, policy: policy)
assertTrue(clearBlocked == .init(applied: false, shieldApplied: false, blockedReason: "risk_clear_or_unknown"), "clear risk should not trigger replacement")

let firstBad = applyStage2Decision(riskLevel: "bad", replacementsToday: 0, shieldsUsedThisWeek: 0, policy: policy)
assertTrue(firstBad == .init(applied: true, shieldApplied: true, blockedReason: nil), "first bad-risk replacement should apply with shield")

let secondSameDay = applyStage2Decision(riskLevel: "bad", replacementsToday: 1, shieldsUsedThisWeek: 1, policy: policy)
assertTrue(secondSameDay == .init(applied: false, shieldApplied: false, blockedReason: "daily_limit_reached"), "second replacement same day should be blocked")

let nextDaySameWeek = applyStage2Decision(riskLevel: "severe", replacementsToday: 0, shieldsUsedThisWeek: 1, policy: policy)
assertTrue(nextDaySameWeek == .init(applied: true, shieldApplied: false, blockedReason: nil), "same week second replacement should apply without shield")

print("PASS: weather stage2 engine unit checks")
