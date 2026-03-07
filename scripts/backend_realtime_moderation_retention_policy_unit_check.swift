import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 조건이 거짓일 때 출력할 설명입니다.
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
/// - Returns: 각 파일 내용을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/backend-realtime-moderation-retention-policy-v1.md")
let readme = load("README.md")
let schedulerOps = load("docs/backend-scheduler-ops-standard-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let migrations = loadMany([
    "supabase/migrations/20260226095500_nearby_hotspots.sql",
    "supabase/migrations/20260227192000_rival_privacy_hard_guard.sql",
    "supabase/migrations/20260301153000_rival_stage2_leaderboard_backend.sql",
    "supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql",
    "supabase/migrations/20260305103000_walk_live_presence_schema_rpc_ttl_rls.sql",
    "supabase/migrations/20260305165000_walk_live_presence_anti_abuse_engine.sql"
])

for token in [
    "ephemeral_realtime",
    "derived_operational_state",
    "operational_audit",
    "moderation_audit",
    "preference_or_identity",
    "stale exclusion",
    "hard delete",
    "walk_live_presence",
    "nearby_presence",
    "widget_hotspot_summary_cache",
    "privacy_guard_audit_logs",
    "live_presence_abuse_states",
    "live_presence_abuse_device_windows",
    "live_presence_abuse_events",
    "rival_abuse_audit_logs"
] {
    assertTrue(doc.contains(token), "retention doc should mention \(token)")
}

for policyValue in [
    "90초 TTL",
    "10 minutes",
    "24시간",
    "30일",
    "90일",
    "7일"
] {
    assertTrue(doc.contains(policyValue), "retention doc should define policy value \(policyValue)")
}

assertTrue(doc.contains("#467"), "retention doc should reference cleanup rollout follow-up issue")
assertTrue(doc.contains("freshness policy는 있음, retention enforcement는 미완료"), "retention doc should call out nearby_presence enforcement gap")
assertTrue(doc.contains("stale exclusion을 retention enforcement로 오해하지 않는다."), "retention doc should define the stale-vs-delete rule")

assertTrue(migrations.contains("expires_at timestamptz not null default (now() + interval '90 seconds')"), "migrations should keep walk_live_presence ttl source")
assertTrue(migrations.contains("where last_seen_at >= now() - interval '10 minutes'"), "migrations should keep nearby_presence stale exclusion source")
assertTrue(migrations.contains("cache_ttl_seconds integer := 300;"), "migrations should keep widget hotspot cache TTL source")
assertTrue(migrations.contains("min_refresh_gap_seconds integer := 20;"), "migrations should keep widget hotspot min refresh gap source")
assertTrue(migrations.contains("walk_live_presence_ttl_cleanup"), "migrations should keep live presence cleanup scheduler")
assertTrue(migrations.contains("privacy_guard_audit_logs"), "migrations should define privacy guard audit logs")
assertTrue(migrations.contains("live_presence_abuse_events"), "migrations should define abuse events")
assertTrue(migrations.contains("rival_abuse_audit_logs"), "migrations should define rival abuse audit logs")

assertTrue(schedulerOps.contains("live_presence.ttl_cleanup"), "scheduler ops doc should still document live_presence ttl cleanup")
assertTrue(readme.contains("docs/backend-realtime-moderation-retention-policy-v1.md"), "README should link retention policy doc")
assertTrue(backendCheck.contains("backend_realtime_moderation_retention_policy_unit_check.swift"), "backend_pr_check should run retention policy check")
assertTrue(iosPRCheck.contains("backend_realtime_moderation_retention_policy_unit_check.swift"), "ios_pr_check should run retention policy check")

print("PASS: backend realtime/moderation retention policy unit checks")
