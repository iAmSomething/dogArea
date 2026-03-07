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

/// 저장소 루트 기준 상대 경로의 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/backend-edge-failure-dashboard-view-v1.md")
let migration = load("supabase/migrations/20260307193000_backend_edge_failure_dashboard_view.sql")
let readme = load("README.md")
let runbook = load("docs/backend-edge-incident-runbook-v1.md")
let matrix = load("docs/backend-edge-observability-adoption-matrix-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for token in [
    "view_backend_edge_failure_dashboard_24h",
    "function_name",
    "error_code",
    "failure_category",
    "auth_mode",
    "fallback_used",
    "hour_bucket",
    "event_count",
    "affected_users",
    "avg_latency_ms",
    "p95_latency_ms",
    "data_source"
] {
    assertTrue(doc.contains(token), "dashboard doc should mention \(token)")
}

for source in [
    "caricature_jobs",
    "privacy_guard_audit_logs",
    "live_presence_abuse_events",
    "view_rollout_kpis_24h"
] {
    assertTrue(doc.contains(source), "dashboard doc should mention source \(source)")
}

for functionName in [
    "sync-walk",
    "sync-profile",
    "rival-league",
    "quest-engine",
    "feature-control",
    "upload-profile-image"
] {
    assertTrue(doc.contains(functionName), "dashboard doc should call out uncovered function \(functionName)")
}

for queryPhrase in [
    "fallback_ratio",
    "group by function_name, error_code",
    "failure_category",
    "Phase 1 SQL view"
] {
    assertTrue(doc.contains(queryPhrase), "dashboard doc should include query/view guidance for \(queryPhrase)")
}

assertTrue(migration.contains("create or replace view public.view_backend_edge_failure_dashboard_24h"), "migration should create dashboard view")
assertTrue(migration.contains("'caricature'::text as function_name"), "migration should include caricature source")
assertTrue(migration.contains("'nearby-presence'::text as function_name"), "migration should include nearby-presence source")
assertTrue(migration.contains("privacy_guard_audit_logs"), "migration should include privacy guard source")
assertTrue(migration.contains("live_presence_abuse_events"), "migration should include abuse source")
assertTrue(migration.contains("AUTH_SESSION_INVALID"), "migration should classify auth failures")
assertTrue(migration.contains("PRIVACY_K_ANON_SUPPRESSED"), "migration should classify privacy guard failures")
assertTrue(migration.contains("ABUSE_RATE_DEVICE"), "migration should classify abuse failures")
assertTrue(migration.contains("grant select on public.view_backend_edge_failure_dashboard_24h to authenticated;"), "migration should grant dashboard view select")

assertTrue(readme.contains("docs/backend-edge-failure-dashboard-view-v1.md"), "README should link dashboard doc")
assertTrue(runbook.contains("docs/backend-edge-failure-dashboard-view-v1.md"), "runbook should link dashboard doc")
assertTrue(matrix.contains("docs/backend-edge-failure-dashboard-view-v1.md"), "adoption matrix should link dashboard doc")
assertTrue(backendCheck.contains("backend_edge_failure_dashboard_unit_check.swift"), "backend_pr_check should run dashboard check")
assertTrue(iosPRCheck.contains("backend_edge_failure_dashboard_unit_check.swift"), "ios_pr_check should run dashboard check")

print("PASS: backend edge failure dashboard unit checks")
