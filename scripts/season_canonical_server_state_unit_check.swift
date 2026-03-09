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

let summaryModel = load("dogArea/Source/Domain/Season/Models/SeasonCanonicalSummary.swift")
let summaryStore = load("dogArea/Source/Domain/Season/Stores/SeasonCanonicalSummaryStore.swift")
let summaryService = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSeasonServices.swift")
let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeIndoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let homeSessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let homeSeasonCanonical = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SeasonCanonical.swift")
let homePresentationState = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let seasonResultOverlay = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonResultOverlayView.swift")
let appMetrics = load("dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift")
let migration = load("supabase/migrations/20260309120000_season_canonical_server_state.sql")
let pointsStage = load("supabase/functions/sync-walk/handlers/points_stage.ts")
let pointsPostProcessing = load("supabase/functions/sync-walk/handlers/points_stage_post_processing.ts")
let syncWalkTypes = load("supabase/functions/sync-walk/support/types.ts")
let doc = load("docs/season-canonical-server-state-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(summaryModel.contains("struct SeasonCanonicalSummarySnapshot"), "summary model should define canonical season snapshot")
assertTrue(summaryModel.contains("struct SeasonCanonicalCompletedSnapshot"), "summary model should define completed season snapshot")
assertTrue(summaryModel.contains("struct SeasonRewardClaimServerResult"), "summary model should define reward claim result")
assertTrue(summaryModel.contains("protocol SeasonCanonicalSummaryServicing"), "summary model should define service protocol")

assertTrue(summaryStore.contains("protocol SeasonCanonicalSummaryStoreProtocol"), "summary store protocol should exist")
assertTrue(summaryStore.contains("season.canonical.summary.latest.v1"), "summary store should persist latest canonical summary cache")
assertTrue(summaryStore.contains("guard snapshot.ownerUserId == normalizedUserId else { return nil }"), "summary store should reject other-user cache reads")
assertTrue(summaryStore.contains("func applyClaimResult(_ result: SeasonRewardClaimServerResult, for userId: String?)"), "summary store should apply reward claim result")

assertTrue(summaryService.contains("rpc/rpc_get_owner_season_summary"), "supabase season service should call summary RPC")
assertTrue(summaryService.contains("rpc/rpc_claim_season_reward"), "supabase season service should call reward claim RPC")
assertTrue(summaryService.contains("in_request_id"), "reward claim RPC payload should include idempotent request id")

assertTrue(syncServices.contains("seasonCanonicalSummary"), "sync transport should decode canonical season summary")
assertTrue(syncServices.contains("persistSeasonCanonicalSummaryIfNeeded"), "sync transport should persist canonical season summary")
assertTrue(syncServices.contains("SeasonCanonicalSummaryStore.shared.save(snapshot)"), "sync transport should save member season summary cache")

assertTrue(pointsStage.contains("season_canonical_summary"), "sync-walk points response should return season canonical summary")
assertTrue(pointsPostProcessing.contains("loadSeasonCanonicalSummary"), "points post processing should fetch season canonical summary")
assertTrue(pointsPostProcessing.contains("rpc_get_owner_season_summary"), "points post processing should call summary RPC")
assertTrue(syncWalkTypes.contains("export type SeasonCanonicalSummaryDTO"), "sync-walk support types should define season canonical summary dto")

assertTrue(homeViewModel.contains("let seasonCanonicalSummaryStore: SeasonCanonicalSummaryStoreProtocol"), "home viewmodel should inject season canonical store")
assertTrue(homeViewModel.contains("let seasonCanonicalSummaryService: SeasonCanonicalSummaryServicing"), "home viewmodel should inject season canonical service")
assertTrue(homeViewModel.contains("var latestSeasonCanonicalSummary: SeasonCanonicalSummarySnapshot? = nil"), "home viewmodel should keep latest canonical summary")
assertTrue(homeIndoorMissionFlow.contains("refreshSeasonCanonicalSummaryIfNeeded"), "home indoor mission flow should refresh season canonical summary")
assertTrue(homeIndoorMissionFlow.contains("markSeasonCanonicalOptimisticWindow"), "home indoor mission flow should start optimistic window")
assertTrue(homeSessionLifecycle.contains("seasonCanonicalSummaryService.claimReward"), "home session lifecycle should claim rewards through season canonical service")
assertTrue(homeSessionLifecycle.contains("seasonCanonicalSummaryStore.applyClaimResult"), "home session lifecycle should update season canonical cache after claim")
assertTrue(homeSeasonCanonical.contains("seasonCanonicalMismatchDetected"), "home season canonical extension should log parity mismatches")
assertTrue(homeSeasonCanonical.contains("shouldPreferOptimisticLocalSeasonSummary"), "home season canonical extension should define optimistic window rule")

assertTrue(homePresentationState.contains("case unavailable"), "home presentation state should expose unavailable reward status")
assertTrue(seasonResultOverlay.contains("rewardStatus == .pending || rewardStatus == .failed"), "season result overlay should only expose retry for pending/failed")
assertTrue(seasonResultOverlay.contains("case .unavailable:"), "season result overlay should render unavailable status")

assertTrue(appMetrics.contains("case seasonCanonicalRefreshed"), "app metrics should track season canonical refresh")
assertTrue(appMetrics.contains("case seasonCanonicalMismatchDetected"), "app metrics should track season canonical mismatches")
assertTrue(appMetrics.contains("case seasonRewardClaimSucceeded"), "app metrics should track season reward claim success")
assertTrue(appMetrics.contains("case seasonRewardClaimFailed"), "app metrics should track season reward claim failure")

assertTrue(migration.contains("rpc_get_owner_season_summary(payload jsonb)"), "migration should define season summary RPC")
assertTrue(migration.contains("rpc_claim_season_reward(payload jsonb)"), "migration should define season reward claim RPC")
assertTrue(migration.contains("claim_request_id"), "migration should add reward claim request id")
assertTrue(migration.contains("idx_season_rewards_owner_claim_request"), "migration should enforce reward claim idempotency index")
assertTrue(migration.contains("grant execute on function public.rpc_get_owner_season_summary(jsonb)"), "migration should grant summary RPC execution")
assertTrue(migration.contains("grant execute on function public.rpc_claim_season_reward(jsonb)"), "migration should grant reward claim RPC execution")

assertTrue(doc.contains("canonical source를 서버로 일원화"), "doc should describe server canonical ownership")
assertTrue(doc.contains("`rpc_get_owner_season_summary(payload jsonb)`"), "doc should document summary RPC")
assertTrue(doc.contains("`rpc_claim_season_reward(payload jsonb)`"), "doc should document reward claim RPC")
assertTrue(doc.contains("guest 또는 cloudSync 불가"), "doc should define guest fallback policy")
assertTrue(doc.contains("`30분`"), "doc should define season cache expiry")
assertTrue(doc.contains("Parity / Diff 관측성"), "doc should describe parity observability")
assertTrue(doc.contains("멀티디바이스"), "doc should describe multi-device consistency")
assertTrue(doc.contains("`sync-walk` points stage"), "doc should describe sync-walk propagation")

assertTrue(readme.contains("docs/season-canonical-server-state-v1.md"), "README should index season canonical server state doc")
assertTrue(iosPRCheck.contains("swift scripts/season_canonical_server_state_unit_check.swift"), "ios_pr_check should run season canonical server state unit check")
assertTrue(backendPRCheck.contains("swift scripts/season_canonical_server_state_unit_check.swift"), "backend_pr_check should run season canonical server state unit check")

print("PASS: season canonical server state unit checks")
