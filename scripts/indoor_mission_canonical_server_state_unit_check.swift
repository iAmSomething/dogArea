import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let homeMissionModels = load("dogArea/Source/Domain/Home/Models/HomeMissionModels.swift")
let indoorMissionStore = load("dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift")
let indoorMissionPresentationService = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPresentationService.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeIndoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let homeSessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let presenceAndQuestServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift")
let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let syncWalkTypes = load("supabase/functions/sync-walk/support/types.ts")
let pointsPostProcessing = load("supabase/functions/sync-walk/handlers/points_stage_post_processing.ts")
let pointsStage = load("supabase/functions/sync-walk/handlers/points_stage.ts")
let migration = load("supabase/migrations/20260310131000_indoor_mission_canonical_server_state.sql")
let summaryHotfixMigration = load("supabase/migrations/20260311154000_indoor_mission_summary_owner_ambiguity_hotfix.sql")
let actionEasyDayHotfixMigration = load("supabase/migrations/20260311161000_indoor_mission_action_easyday_ambiguity_hotfix.sql")
let doc = load("docs/indoor-mission-canonical-server-state-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(homeMissionModels.contains("enum IndoorMissionBoardSource"), "home mission models should define indoor mission board source")
assertTrue(homeMissionModels.contains("struct IndoorMissionCanonicalSummarySnapshot"), "home mission models should define canonical summary snapshot")
assertTrue(homeMissionModels.contains("struct IndoorMissionCanonicalMissionSnapshot"), "home mission models should define canonical mission snapshot")
assertTrue(homeMissionModels.contains("protocol IndoorMissionCanonicalSummaryServicing"), "home mission models should define canonical service protocol")
assertTrue(homeMissionModels.contains("protocol IndoorMissionCanonicalSummaryStoreProtocol"), "home mission models should define canonical store protocol")
assertTrue(homeMissionModels.contains("canonicalMissionInstanceId"), "mission card model should expose canonical mission instance id")
assertTrue(homeMissionModels.contains("source: IndoorMissionBoardSource"), "mission card and board should expose ownership source")

assertTrue(indoorMissionStore.contains("func buildBoard(from summary: IndoorMissionCanonicalSummarySnapshot)"), "indoor mission store should build board from canonical summary")
assertTrue(indoorMissionStore.contains("final class IndoorMissionCanonicalSummaryStore"), "indoor mission store should include canonical summary store")
assertTrue(indoorMissionStore.contains("indoor.mission.canonical.summary.cache.v1"), "canonical summary store should persist indoor mission cache")

assertTrue(indoorMissionPresentationService.contains("mission.claimable ??"), "presentation service should prefer canonical claimable state when present")

assertTrue(homeViewModel.contains("let indoorMissionCanonicalSummaryStore: IndoorMissionCanonicalSummaryStoreProtocol"), "home viewmodel should inject indoor mission canonical store")
assertTrue(homeViewModel.contains("let indoorMissionCanonicalSummaryService: IndoorMissionCanonicalSummaryServicing"), "home viewmodel should inject indoor mission canonical service")
assertTrue(homeViewModel.contains("var latestIndoorMissionCanonicalSummary: IndoorMissionCanonicalSummarySnapshot? = nil"), "home viewmodel should keep latest indoor mission canonical summary")
assertTrue(homeViewModel.contains("var indoorMissionCanonicalSummaryTask: Task<Void, Never>? = nil"), "home viewmodel should manage canonical summary task lifecycle")
assertTrue(homeSessionLifecycle.contains("latestIndoorMissionCanonicalSummary = indoorMissionCanonicalSummaryStore.loadSummary"), "session lifecycle should preload indoor mission canonical cache")

assertTrue(homeIndoorMissionFlow.contains("IndoorMissionCanonicalSummaryConstants"), "home indoor mission flow should define canonical cache age")
assertTrue(homeIndoorMissionFlow.contains("indoorMissionCanonicalSummaryStore.loadFreshSummary"), "home indoor mission flow should load fresh indoor mission canonical cache")
assertTrue(homeIndoorMissionFlow.contains("refreshIndoorMissionCanonicalSummaryIfNeeded"), "home indoor mission flow should refresh indoor mission canonical summary")
assertTrue(homeIndoorMissionFlow.contains("indoorMissionCanonicalSummaryService.recordAction"), "home indoor mission flow should submit action through canonical service")
assertTrue(homeIndoorMissionFlow.contains("indoorMissionCanonicalSummaryService.claimReward"), "home indoor mission flow should submit claim through canonical service")
assertTrue(homeIndoorMissionFlow.contains("indoorMissionCanonicalSummaryService.activateEasyDay"), "home indoor mission flow should activate easy day through canonical service")
assertTrue(homeIndoorMissionFlow.contains("\"mode\": \"server_canonical\""), "home indoor mission flow should tag canonical path metrics")
assertTrue(homeIndoorMissionFlow.contains("\"mode\": \"guest_fallback\""), "home indoor mission flow should preserve guest fallback metrics")

assertTrue(presenceAndQuestServices.contains("struct SupabaseIndoorMissionCanonicalSummaryService"), "supabase services should define indoor mission canonical service")
assertTrue(presenceAndQuestServices.contains("rpc/rpc_get_indoor_mission_summary"), "supabase service should call indoor mission summary RPC")
assertTrue(presenceAndQuestServices.contains("rpc/rpc_record_indoor_mission_action"), "supabase service should call indoor mission action RPC")
assertTrue(presenceAndQuestServices.contains("rpc/rpc_claim_indoor_mission_reward"), "supabase service should call indoor mission reward claim RPC")
assertTrue(presenceAndQuestServices.contains("rpc/rpc_activate_indoor_easy_day"), "supabase service should call indoor mission easy day RPC")

assertTrue(syncWalkTypes.contains("export type IndoorMissionCanonicalSummaryDTO"), "sync-walk support types should define indoor mission canonical summary dto")
assertTrue(pointsPostProcessing.contains("loadIndoorMissionCanonicalSummary"), "points post processing should load indoor mission canonical summary")
assertTrue(pointsPostProcessing.contains("rpc_get_indoor_mission_summary"), "points post processing should call indoor mission summary RPC")
assertTrue(pointsStage.contains("indoor_mission_canonical_summary"), "points stage response should include indoor mission canonical summary")
assertTrue(syncServices.contains("indoorMissionCanonicalSummary"), "sync transport should decode indoor mission canonical summary")
assertTrue(syncServices.contains("persistIndoorMissionCanonicalSummaryIfNeeded"), "sync transport should persist indoor mission canonical summary")
assertTrue(syncServices.contains("IndoorMissionCanonicalSummaryStore.shared.save(snapshot)"), "sync transport should save indoor mission canonical summary cache")

assertTrue(migration.contains("owner_indoor_mission_daily_state"), "migration should create daily state table")
assertTrue(migration.contains("owner_indoor_mission_instances"), "migration should create mission instances table")
assertTrue(migration.contains("owner_indoor_mission_action_events"), "migration should create action event ledger")
assertTrue(migration.contains("owner_indoor_mission_claims"), "migration should create claim ledger")
assertTrue(migration.contains("rpc_get_indoor_mission_summary(payload jsonb)"), "migration should define summary RPC")
assertTrue(migration.contains("rpc_record_indoor_mission_action(payload jsonb)"), "migration should define action RPC")
assertTrue(migration.contains("rpc_claim_indoor_mission_reward(payload jsonb)"), "migration should define claim RPC")
assertTrue(migration.contains("rpc_activate_indoor_easy_day(payload jsonb)"), "migration should define easy day RPC")
assertTrue(migration.contains("grant execute on function public.rpc_get_indoor_mission_summary(jsonb)"), "migration should grant summary RPC execution")
assertTrue(summaryHotfixMigration.contains("#variable_conflict use_column"), "indoor mission summary hotfix should force column precedence")
assertTrue(summaryHotfixMigration.contains("rpc_get_indoor_mission_summary(payload jsonb)"), "indoor mission summary hotfix should replace summary RPC")
assertTrue(summaryHotfixMigration.contains("grant execute on function public.rpc_get_indoor_mission_summary(jsonb)"), "indoor mission summary hotfix should preserve execute grant")
assertTrue(actionEasyDayHotfixMigration.contains("#variable_conflict use_column"), "indoor mission action/easy-day hotfix should force column precedence")
assertTrue(actionEasyDayHotfixMigration.contains("rpc_record_indoor_mission_action(payload jsonb)"), "indoor mission action/easy-day hotfix should replace action RPC")
assertTrue(actionEasyDayHotfixMigration.contains("rpc_activate_indoor_easy_day(payload jsonb)"), "indoor mission action/easy-day hotfix should replace easy-day RPC")
assertTrue(actionEasyDayHotfixMigration.contains("grant execute on function public.rpc_record_indoor_mission_action(jsonb)"), "indoor mission action hotfix should preserve execute grant")
assertTrue(actionEasyDayHotfixMigration.contains("grant execute on function public.rpc_activate_indoor_easy_day(jsonb)"), "indoor mission easy-day hotfix should preserve execute grant")

assertTrue(doc.contains("canonical source를 서버로 일원화"), "doc should describe server canonical ownership")
assertTrue(doc.contains("`rpc_get_indoor_mission_summary(payload jsonb)`"), "doc should document summary RPC")
assertTrue(doc.contains("`rpc_record_indoor_mission_action(payload jsonb)`"), "doc should document action RPC")
assertTrue(doc.contains("`rpc_claim_indoor_mission_reward(payload jsonb)`"), "doc should document claim RPC")
assertTrue(doc.contains("`rpc_activate_indoor_easy_day(payload jsonb)`"), "doc should document easy day RPC")
assertTrue(doc.contains("`sync-walk` points stage"), "doc should describe sync-walk propagation")
assertTrue(doc.contains("guest 또는 cloudSync 불가"), "doc should define guest fallback policy")
assertTrue(doc.contains("`30분`"), "doc should define cache expiry")
assertTrue(doc.contains("멀티디바이스"), "doc should define multi-device consistency")

assertTrue(readme.contains("docs/indoor-mission-canonical-server-state-v1.md"), "README should index indoor mission canonical server state doc")
assertTrue(iosPRCheck.contains("swift scripts/indoor_mission_canonical_server_state_unit_check.swift"), "ios_pr_check should run indoor mission canonical server state unit check")
assertTrue(backendPRCheck.contains("swift scripts/indoor_mission_canonical_server_state_unit_check.swift"), "backend_pr_check should run indoor mission canonical server state unit check")

print("PASS: indoor mission canonical server state unit checks")
