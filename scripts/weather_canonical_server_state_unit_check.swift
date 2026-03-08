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

let summaryModel = load("dogArea/Source/Domain/Weather/Models/WeatherReplacementSummary.swift")
let summaryStore = load("dogArea/Source/Domain/Weather/Stores/WeatherReplacementSummaryStore.swift")
let summaryService = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseWeatherReplacementServices.swift")
let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let homeMissionModels = load("dogArea/Source/Domain/Home/Models/HomeMissionModels.swift")
let indoorMissionStore = load("dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift")
let homeIndoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let doc = load("docs/weather-canonical-server-state-v1.md")
let engineDoc = load("docs/weather-replacement-shield-engine-v1.md")
let feedbackDoc = load("docs/weather-feedback-loop-v1.md")
let migration = load("supabase/migrations/20260308103000_weather_canonical_server_state.sql")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(summaryModel.contains("struct WeatherReplacementSummarySnapshot"), "summary model should define canonical weather summary snapshot")
assertTrue(summaryModel.contains("let ownerUserId: String?"), "summary snapshot should be user-bound")
assertTrue(summaryModel.contains("protocol WeatherReplacementSummaryServicing"), "summary service protocol should exist")

assertTrue(summaryStore.contains("guard let normalizedUserId"), "summary store should refuse anonymous cache reads")
assertTrue(summaryStore.contains("weather.replacement.summary.latest.v1"), "summary store should persist latest canonical summary cache")

assertTrue(summaryService.contains("rpc/rpc_get_weather_replacement_summary"), "supabase service should call summary RPC")
assertTrue(summaryService.contains("rpc/rpc_submit_weather_feedback"), "supabase service should call feedback RPC")
assertTrue(summaryService.contains("in_request_id"), "feedback RPC payload should include idempotent request id")

assertTrue(syncServices.contains("persistWeatherReplacementSummaryIfNeeded"), "sync transport should persist canonical weather summary from sync-walk")
assertTrue(syncServices.contains("guard case .member(let userId) = AppFeatureGate.currentSession()"), "sync transport should persist canonical weather summary only for member sessions")

assertTrue(homeMissionModels.contains("case serverSummary"), "home weather source should represent server summary source")
assertTrue(indoorMissionStore.contains("serverSummary: WeatherReplacementSummarySnapshot?"), "indoor mission store should accept server summary")
assertTrue(homeIndoorMissionFlow.contains("weatherReplacementSummaryStore.loadFreshSummary"), "home flow should load cached server summary")
assertTrue(homeIndoorMissionFlow.contains("weatherReplacementSummaryService.fetchSummary"), "home flow should refresh canonical server summary")
assertTrue(homeIndoorMissionFlow.contains("weatherReplacementSummaryService.submitFeedback"), "home flow should submit feedback through server canonical path")
assertTrue(homeIndoorMissionFlow.contains("\"mode\": \"guest_fallback\""), "home flow should tag guest fallback path explicitly")

assertTrue(migration.contains("weekly_feedback_limit"), "migration should add weekly feedback limit to runtime policy")
assertTrue(migration.contains("weather_feedback_histories"), "migration should create server feedback ledger table")
assertTrue(migration.contains("rpc_get_weather_replacement_summary(payload jsonb)"), "migration should define weather summary RPC")
assertTrue(migration.contains("rpc_submit_weather_feedback(payload jsonb)"), "migration should define weather feedback RPC")
assertTrue(migration.contains("grant execute on function public.rpc_get_weather_replacement_summary(jsonb)"), "migration should grant summary RPC execution")
assertTrue(migration.contains("grant execute on function public.rpc_submit_weather_feedback(jsonb)"), "migration should grant feedback RPC execution")

assertTrue(doc.contains("canonical state를 서버로 일원화"), "doc should state server canonical ownership goal")
assertTrue(doc.contains("`rpc_get_weather_replacement_summary(payload jsonb)`"), "doc should document summary RPC")
assertTrue(doc.contains("`rpc_submit_weather_feedback(payload jsonb)`"), "doc should document feedback RPC")
assertTrue(doc.contains("guest 또는 cloudSync 불가"), "doc should define guest fallback policy")
assertTrue(doc.contains("`30분`"), "doc should define cache expiry")
assertTrue(doc.contains("멀티디바이스"), "doc should define multi-device consistency")
assertTrue(doc.contains("`sync-walk` points stage"), "doc should define sync-walk summary propagation")

assertTrue(engineDoc.contains("rpc_apply_weather_replacement"), "engine doc should still describe replacement RPC engine")
assertTrue(feedbackDoc.contains("체감 날씨 다름"), "feedback doc should still describe weather mismatch UX")

assertTrue(readme.contains("docs/weather-canonical-server-state-v1.md"), "README should index canonical weather server state doc")
assertTrue(iosPRCheck.contains("swift scripts/weather_canonical_server_state_unit_check.swift"), "ios_pr_check should run weather canonical server state unit check")
assertTrue(backendPRCheck.contains("swift scripts/weather_canonical_server_state_unit_check.swift"), "backend_pr_check should run weather canonical server state unit check")

print("PASS: weather canonical server state unit checks")
