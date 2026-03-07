import Foundation

/// 조건식을 검증하고 실패 시 stderr에 메시지를 출력한 뒤 종료합니다.
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

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let schedulerDoc = load("docs/backend-scheduler-ops-standard-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let realtimeOpsDoc = load("docs/realtime-ops-rollout-killswitch-v1.md")
let incidentRunbook = load("docs/backend-edge-incident-runbook-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

let seasonMigration = load("supabase/migrations/20260301090000_season_stage2_batch_pipeline.sql")
let rivalMigration = load("supabase/migrations/20260227212000_rival_fair_league_matching.sql")
let livePresenceMigration = load("supabase/migrations/20260305103000_walk_live_presence_schema_rpc_ttl_rls.sql")
let weatherDoc = load("docs/weather-feedback-loop-v1.md")
let questMigration = load("supabase/migrations/20260303120000_quest_stage2_progress_claim_engine.sql")

for term in [
    "season.daily_decay",
    "season.finalize",
    "rival.weekly_refresh",
    "live_presence.ttl_cleanup",
    "weather.feedback_kpi_review",
    "quest.expiry_review"
] {
    assertTrue(schedulerDoc.contains(term), "scheduler ops doc should include \(term)")
}

for term in [
    "UTC",
    "재시도",
    "수동 재실행",
    "실패 감지",
    "확인 SQL"
] {
    assertTrue(schedulerDoc.contains(term), "scheduler ops doc should describe \(term)")
}

assertTrue(schedulerDoc.contains("rpc_apply_season_daily_decay"), "scheduler ops doc should reference season daily decay RPC")
assertTrue(schedulerDoc.contains("rpc_finalize_season"), "scheduler ops doc should reference season finalize RPC")
assertTrue(schedulerDoc.contains("rpc_refresh_rival_leagues"), "scheduler ops doc should reference rival refresh RPC")
assertTrue(schedulerDoc.contains("rpc_cleanup_walk_live_presence"), "scheduler ops doc should reference live presence cleanup RPC")
assertTrue(schedulerDoc.contains("view_weather_feedback_kpis_7d"), "scheduler ops doc should reference weather KPI verification view")
assertTrue(schedulerDoc.contains("quest_instances") && schedulerDoc.contains("expires_at"), "scheduler ops doc should reference quest expiry verification query")
assertTrue(schedulerDoc.contains("walk_live_presence_ttl_cleanup"), "scheduler ops doc should mention the pg_cron cleanup job name")
assertTrue(schedulerDoc.contains("bash scripts/backend_migration_drift_check.sh"), "scheduler ops doc should connect to drift gate")

assertTrue(migrationDoc.contains("docs/backend-scheduler-ops-standard-v1.md"), "supabase migration doc should link scheduler ops standard doc")
assertTrue(realtimeOpsDoc.contains("docs/backend-scheduler-ops-standard-v1.md"), "realtime ops doc should link scheduler ops standard doc")
assertTrue(incidentRunbook.contains("#427") && incidentRunbook.contains("bash scripts/backend_pr_check.sh"), "incident runbook should still point operators to backend checks")
assertTrue(readme.contains("docs/backend-scheduler-ops-standard-v1.md"), "README should link scheduler ops standard doc")

assertTrue(backendCheck.contains("backend_scheduler_ops_unit_check.swift"), "backend_pr_check should run scheduler ops unit check")
assertTrue(iosPRCheck.contains("backend_scheduler_ops_unit_check.swift"), "ios_pr_check should run scheduler ops unit check")

assertTrue(seasonMigration.contains("settlement_delay_hours integer not null default 2"), "season migration should define settlement delay baseline")
assertTrue(seasonMigration.contains("create or replace function public.rpc_apply_season_daily_decay"), "season migration should define daily decay RPC")
assertTrue(seasonMigration.contains("create or replace function public.rpc_finalize_season"), "season migration should define finalize RPC")
assertTrue(rivalMigration.contains("weekly_refresh_interval_days integer not null default 7"), "rival migration should define weekly refresh baseline")
assertTrue(rivalMigration.contains("create or replace function public.rpc_refresh_rival_leagues"), "rival migration should define refresh RPC")
assertTrue(livePresenceMigration.contains("walk_live_presence_ttl_cleanup"), "live presence migration should define cron job name")
assertTrue(livePresenceMigration.contains("create or replace function public.rpc_cleanup_walk_live_presence"), "live presence migration should define cleanup RPC")
assertTrue(weatherDoc.contains("view_weather_feedback_kpis_7d"), "weather feedback doc should define KPI view")
assertTrue(questMigration.contains("create or replace function public.quest_scope_expires_at"), "quest migration should define quest expiry baseline")

print("PASS: backend scheduler ops unit checks")
