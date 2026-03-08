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

let migration = load("supabase/migrations/20260309043000_realtime_retention_cleanup_rollout.sql")
let rolloutDoc = load("docs/backend-realtime-retention-cleanup-rollout-v1.md")
let retentionDoc = load("docs/backend-realtime-moderation-retention-policy-v1.md")
let schedulerDoc = load("docs/backend-scheduler-ops-standard-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosCheck = load("scripts/ios_pr_check.sh")

for token in [
    "view_realtime_retention_delete_debt",
    "rpc_cleanup_realtime_retention",
    "realtime_retention_cleanup_hourly",
    "nearby_presence",
    "widget_hotspot_summary_cache",
    "privacy_guard_audit_logs",
    "live_presence_abuse_states",
    "live_presence_abuse_device_windows",
    "live_presence_abuse_events",
    "rival_abuse_audit_logs"
] {
    assertTrue(migration.contains(token), "migration should contain \(token)")
}

assertTrue(migration.contains("'17 * * * *'"), "migration should schedule hourly cleanup at minute 17")
assertTrue(migration.contains("grant execute on function public.rpc_cleanup_realtime_retention(timestamptz) to service_role;"), "migration should grant execute on cleanup RPC to service_role")
assertTrue(migration.contains("grant select on public.view_realtime_retention_delete_debt to service_role;"), "migration should grant view access to service_role")

for token in [
    "#470",
    "rpc_cleanup_realtime_retention",
    "view_realtime_retention_delete_debt",
    "realtime_retention_cleanup_hourly",
    "Verification Query",
    "select public.rpc_cleanup_realtime_retention(now());",
    "from cron.job"
] {
    assertTrue(rolloutDoc.contains(token), "rollout doc should contain \(token)")
}

assertTrue(retentionDoc.contains("#470"), "retention policy doc should reference rollout issue #470")
assertTrue(retentionDoc.contains("rpc_cleanup_realtime_retention"), "retention policy doc should mention cleanup RPC")
assertTrue(retentionDoc.contains("view_realtime_retention_delete_debt"), "retention policy doc should mention delete debt view")
assertTrue(schedulerDoc.contains("realtime.retention_cleanup"), "scheduler doc should document realtime retention cleanup job")
assertTrue(readme.contains("docs/backend-realtime-retention-cleanup-rollout-v1.md"), "README should link retention rollout doc")
assertTrue(backendCheck.contains("backend_realtime_retention_cleanup_rollout_unit_check.swift"), "backend_pr_check should run rollout unit check")
assertTrue(iosCheck.contains("backend_realtime_retention_cleanup_rollout_unit_check.swift"), "ios_pr_check should run rollout unit check")

print("PASS: backend realtime retention cleanup rollout is documented and wired")
