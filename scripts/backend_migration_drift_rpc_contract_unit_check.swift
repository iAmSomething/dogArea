import Foundation

/// 조건식을 검증하고 실패 시 stderr에 메시지를 출력한 뒤 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 설명입니다.
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

/// 여러 파일을 읽어 한 문자열로 병합합니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let driftScript = load("scripts/backend_migration_drift_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let harnessUnitCheck = load("scripts/supabase_integration_harness_unit_check.swift")
let readme = load("README.md")
let ciDoc = load("docs/backend-migration-drift-rpc-ci-check-v1.md")

let rivalCompatMigration = load("supabase/migrations/20260305224000_rival_rpc_postgrest_compat_fix.sql")
let rivalDelegateMigration = load("supabase/migrations/20260305231000_rival_leaderboard_three_arg_delegate.sql")
let questMigration = load("supabase/migrations/20260303120000_quest_stage2_progress_claim_engine.sql")
let territoryWidgetMigration = load("supabase/migrations/20260303190000_territory_widget_summary_rpc.sql")
let hotspotWidgetMigration = load("supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql")
let nearbyHotspotMigration = load("supabase/migrations/20260227192000_rival_privacy_hard_guard.sql")

let syncWalkSource = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-walk/support/types.ts",
    "supabase/functions/sync-walk/handlers/stage_dispatcher.ts"
])
let questEngineSource = load("supabase/functions/quest-engine/index.ts")
let featureControlSource = load("supabase/functions/feature-control/index.ts")

assertTrue(
    driftScript.contains("backend_migration_drift_rpc_contract_unit_check.swift"),
    "drift entrypoint should run the static migration/contract manifest check"
)
assertTrue(
    driftScript.contains("rival_rpc_param_compat_unit_check.swift"),
    "drift entrypoint should run rival/widget quest RPC compatibility check"
)
assertTrue(
    driftScript.contains("sync_walk_404_policy_unit_check.swift"),
    "drift entrypoint should run sync-walk fallback policy check"
)
assertTrue(
    driftScript.contains("territory_status_widget_unit_check.swift") &&
        driftScript.contains("hotspot_widget_privacy_unit_check.swift"),
    "drift entrypoint should run widget summary RPC checks"
)
assertTrue(
    driftScript.contains("quest_stage2_engine_unit_check.swift"),
    "drift entrypoint should run quest RPC contract check"
)
assertTrue(
    driftScript.contains("feature_control_404_cooldown_unit_check.swift"),
    "drift entrypoint should run feature-control availability check"
)
assertTrue(
    driftScript.contains("[backend-drift] FAIL target=") &&
        driftScript.contains("[backend-drift] PASS target="),
    "drift entrypoint should standardize PASS/FAIL output format"
)

assertTrue(
    backendPRCheck.contains("bash scripts/backend_migration_drift_check.sh"),
    "backend_pr_check should invoke the backend drift entrypoint"
)
assertTrue(
    iosPRCheck.contains("backend_migration_drift_rpc_contract_unit_check.swift"),
    "ios_pr_check should include the backend drift manifest unit check"
)

assertTrue(
    rivalCompatMigration.contains("create or replace function public.rpc_get_rival_leaderboard(payload jsonb)") &&
        rivalCompatMigration.contains("create or replace function public.rpc_get_widget_quest_rival_summary(payload jsonb)"),
    "rival/widget quest compat migration should define jsonb wrapper RPCs"
)
assertTrue(
    rivalDelegateMigration.contains("create or replace function public.rpc_get_rival_leaderboard(") &&
        rivalDelegateMigration.contains("jsonb_build_object("),
    "rival delegate migration should keep positional leaderboard compatibility route"
)
assertTrue(
    questMigration.contains("create or replace function public.rpc_issue_quest_instances") &&
        questMigration.contains("create or replace function public.rpc_apply_quest_progress_event") &&
        questMigration.contains("create or replace function public.rpc_claim_quest_reward") &&
        questMigration.contains("create or replace function public.rpc_transition_quest_status"),
    "quest migration should define the core quest RPC set"
)
assertTrue(
    territoryWidgetMigration.contains("create or replace function public.rpc_get_widget_territory_summary"),
    "territory widget migration should define widget territory summary RPC"
)
assertTrue(
    hotspotWidgetMigration.contains("create or replace function public.rpc_get_widget_hotspot_summary"),
    "hotspot widget migration should define widget hotspot summary RPC"
)
assertTrue(
    nearbyHotspotMigration.contains("create or replace function public.rpc_get_nearby_hotspots") &&
        nearbyHotspotMigration.contains("in_center_lat") &&
        nearbyHotspotMigration.contains("in_center_lng") &&
        nearbyHotspotMigration.contains("in_radius_km") &&
        nearbyHotspotMigration.contains("in_now_ts"),
    "nearby hotspot migration should define the latest in_* RPC signature"
)

assertTrue(
    syncWalkSource.contains("get_backfill_summary") &&
        syncWalkSource.contains("sync_walk_stage") &&
        syncWalkSource.contains("dispatchSyncWalkStage"),
    "sync-walk source should retain summary/session stage entry contracts"
)
assertTrue(
    questEngineSource.contains("list_active") &&
        questEngineSource.contains("claim_reward") &&
        questEngineSource.contains("transition_status"),
    "quest engine source should retain core quest action contracts"
)
assertTrue(
    featureControlSource.contains("get_flags") &&
        featureControlSource.contains("get_rollout_kpis"),
    "feature-control source should expose the expected availability actions"
)

for smokeCase in [
    "sync-walk.session.member",
    "sync-walk.summary.member",
    "rival-rpc.compat.member",
    "widget-territory.summary.member",
    "widget-hotspot.summary.member",
    "widget-quest-rival.summary.member",
    "quest-engine.list_active.member",
    "feature-control.flags.anon",
    "feature-control.rollout_kpis.anon"
] {
    assertTrue(smokeRunner.contains(smokeCase), "smoke matrix should include \(smokeCase)")
}

assertTrue(
    harnessUnitCheck.contains("widget-territory.summary.member") &&
        harnessUnitCheck.contains("widget-hotspot.summary.member") &&
        harnessUnitCheck.contains("widget-quest-rival.summary.member"),
    "integration harness unit check should track widget summary smoke cases"
)

assertTrue(
    ciDoc.contains("bash scripts/backend_migration_drift_check.sh"),
    "CI doc should expose backend_migration_drift_check entrypoint"
)
assertTrue(
    ciDoc.contains("widget-territory.summary.member") &&
        ciDoc.contains("widget-hotspot.summary.member") &&
        ciDoc.contains("widget-quest-rival.summary.member"),
    "CI doc should document widget summary smoke cases"
)
assertTrue(
    readme.contains("docs/backend-migration-drift-rpc-ci-check-v1.md"),
    "README should link the backend drift/contract CI doc"
)
assertTrue(
    readme.contains("bash scripts/backend_migration_drift_check.sh"),
    "README should expose backend migration drift entrypoint"
)

print("PASS: backend migration drift/rpc contract unit checks")
