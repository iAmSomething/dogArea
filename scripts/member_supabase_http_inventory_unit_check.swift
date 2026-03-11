import Foundation

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let inventoryDoc = load("docs/member-supabase-http-full-sweep-v1.md")
let zeroBudgetDoc = load("docs/member-supabase-http-5xx-zero-budget-gate-v1.md")
let smokeDoc = load("docs/supabase-integration-smoke-matrix-v1.md")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

let authInfra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let authMail = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthMailActionService.swift")
let authAsset = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift")
let edgeSupport = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseEdgeSupportServices.swift")
let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let presenceQuestServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift")
let widgetAreaServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift")
let weatherServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseWeatherReplacementServices.swift")
let seasonServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSeasonServices.swift")
let signupSheet = load("dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift")

let inventoryRoutes = [
    "auth/v1/user",
    "auth/v1/token?grant_type=refresh_token",
    "auth/v1/resend",
    "auth/v1/recover",
    "functions/v1/sync-profile",
    "functions/v1/sync-walk",
    "functions/v1/nearby-presence",
    "functions/v1/quest-engine",
    "functions/v1/feature-control",
    "functions/v1/caricature",
    "functions/v1/upload-profile-image",
    "rpc/rpc_check_signup_email_availability",
    "rpc/rpc_get_rival_leaderboard",
    "rpc/rpc_get_widget_quest_rival_summary",
    "rpc/rpc_get_indoor_mission_summary",
    "rpc/rpc_record_indoor_mission_action",
    "rpc/rpc_claim_indoor_mission_reward",
    "rpc/rpc_activate_indoor_easy_day",
    "rpc/rpc_get_widget_territory_summary",
    "rpc/rpc_get_widget_hotspot_summary",
    "rpc/rpc_get_weather_replacement_summary",
    "rpc/rpc_submit_weather_feedback",
    "rpc/rpc_get_owner_season_summary",
    "rpc/rpc_claim_season_reward"
]

for route in inventoryRoutes {
    assertTrue(inventoryDoc.contains(route), "inventory doc should list \(route)")
}

assertTrue(authInfra.contains("auth(path: \"user\")"), "source should include auth/v1/user surface")
assertTrue(authInfra.contains("grant_type=refresh_token"), "source should include auth refresh surface")
assertTrue(authMail.contains("auth(path: \"resend\")"), "source should include auth/v1/resend surface")
assertTrue(authMail.contains("auth(path: \"recover\")"), "source should include auth/v1/recover surface")
assertTrue(syncServices.contains("static let primary = \"sync-walk\""), "source should include sync-walk route")
assertTrue(syncServices.contains("function(name: \"sync-profile\")"), "source should include sync-profile route")
assertTrue(presenceQuestServices.contains("function(name: \"nearby-presence\")"), "source should include nearby-presence route")
assertTrue(presenceQuestServices.contains("function(name: \"quest-engine\")"), "source should include quest-engine route")
assertTrue(edgeSupport.contains("function(name: \"feature-control\")"), "source should include feature-control route")
assertTrue(edgeSupport.contains("function(name: \"caricature\")"), "source should include caricature route")
assertTrue(authAsset.contains("function(name: \"upload-profile-image\")"), "source should include upload-profile-image route")
assertTrue(signupSheet.contains("rpc/rpc_check_signup_email_availability"), "source should include signup email availability RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_get_rival_leaderboard"), "source should include rival leaderboard RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_get_widget_quest_rival_summary"), "source should include widget quest/rival RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_get_indoor_mission_summary"), "source should include indoor summary RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_record_indoor_mission_action"), "source should include indoor action RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_claim_indoor_mission_reward"), "source should include indoor claim RPC")
assertTrue(presenceQuestServices.contains("rpc/rpc_activate_indoor_easy_day"), "source should include indoor easy day RPC")
assertTrue(widgetAreaServices.contains("rpc/rpc_get_widget_territory_summary"), "source should include widget territory RPC")
assertTrue(widgetAreaServices.contains("rpc/rpc_get_widget_hotspot_summary"), "source should include widget hotspot RPC")
assertTrue(weatherServices.contains("rpc/rpc_get_weather_replacement_summary"), "source should include weather summary RPC")
assertTrue(weatherServices.contains("rpc/rpc_submit_weather_feedback"), "source should include weather feedback RPC")
assertTrue(seasonServices.contains("rpc/rpc_get_owner_season_summary"), "source should include season summary RPC")
assertTrue(seasonServices.contains("rpc/rpc_claim_season_reward"), "source should include season claim RPC")

let requiredCases = [
    "auth.user.member",
    "auth.refresh.member",
    "auth.resend.signup.member_fixture",
    "auth.recover.member_fixture",
    "signup-email-availability.member",
    "nearby-presence.visibility.get.member",
    "nearby-presence.visibility.set.member",
    "nearby-presence.hotspots.member",
    "indoor-mission.summary.member",
    "indoor-mission.record-action.member",
    "indoor-mission.claim.member",
    "indoor-mission.easy-day.member",
    "weather.summary.member",
    "weather.feedback.member",
    "season.summary.member",
    "season.claim.member",
    "feature-control.flags.member",
    "caricature.invalid_request.member",
    "upload-profile-image.member"
]

for caseName in requiredCases {
    assertTrue(smokeRunner.contains(caseName), "smoke runner should include \(caseName)")
    assertTrue(smokeDoc.contains(caseName), "smoke doc should include \(caseName)")
}

assertTrue(smokeDoc.contains("docs/member-supabase-http-full-sweep-v1.md"), "smoke doc should link member full sweep doc")
assertTrue(smokeDoc.contains("docs/member-supabase-http-5xx-zero-budget-gate-v1.md"), "smoke doc should link zero-budget doc")
assertTrue(readme.contains("docs/member-supabase-http-full-sweep-v1.md"), "README should link member full sweep doc")
assertTrue(readme.contains("docs/member-supabase-http-5xx-zero-budget-gate-v1.md"), "README should link zero-budget doc")
assertTrue(backendPRCheck.contains("member_supabase_http_inventory_unit_check.swift"), "backend_pr_check should include member inventory check")
assertTrue(iosPRCheck.contains("member_supabase_http_inventory_unit_check.swift"), "ios_pr_check should include member inventory check")
assertTrue(zeroBudgetDoc.contains("#732"), "zero-budget doc should reference issue #732")

print("PASS: member supabase http inventory unit checks")
