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

/// 여러 파일을 읽어 하나의 문자열로 병합합니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/widget-summary-rpc-common-response-model-v1.md")
let readme = load("README.md")
let highRiskMatrix = load("docs/backend-high-risk-contract-matrix-v1.md")
let versionPolicy = load("docs/backend-contract-versioning-policy-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

let territoryMigration = load("supabase/migrations/20260303190000_territory_widget_summary_rpc.sql")
let hotspotMigration = load("supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql")
let questRivalMigration = loadMany([
    "supabase/migrations/20260303203100_widget_quest_rival_summary_rpc.sql",
    "supabase/migrations/20260305224000_rival_rpc_postgrest_compat_fix.sql"
])
let widgetServices = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift"
])

for rpc in [
    "rpc_get_widget_territory_summary",
    "rpc_get_widget_hotspot_summary",
    "rpc_get_widget_quest_rival_summary"
] {
    assertTrue(doc.contains(rpc), "widget summary response model doc should include \(rpc)")
}

for field in [
    "has_data",
    "refreshed_at",
    "status",
    "message",
    "context",
    "version",
    "summary_type",
    "summary"
] {
    assertTrue(doc.contains(field), "widget summary response model doc should define \(field)")
}

assertTrue(doc.contains("Phase 1") && doc.contains("Phase 2") && doc.contains("Phase 3") && doc.contains("Phase 4"), "doc should define staged rollout phases")
assertTrue(doc.contains("top-level decode"), "doc should describe current app top-level decode dependency")
assertTrue(doc.contains("payload jsonb"), "doc should discuss wrapper canonical path")

assertTrue(territoryMigration.contains("has_data") && territoryMigration.contains("refreshed_at"), "territory widget rpc should expose has_data/refreshed_at")
assertTrue(hotspotMigration.contains("has_data") && hotspotMigration.contains("refreshed_at") && hotspotMigration.contains("is_cached") && hotspotMigration.contains("server_policy"), "hotspot widget rpc should expose hotspot meta fields")
assertTrue(questRivalMigration.contains("has_data") && questRivalMigration.contains("refreshed_at"), "quest/rival widget rpc should expose has_data/refreshed_at")
assertTrue(questRivalMigration.contains("rpc_get_widget_quest_rival_summary(payload jsonb)"), "quest/rival widget rpc should already have payload jsonb compat path")

assertTrue(widgetServices.contains("struct TerritoryWidgetSummaryDTO"), "infra should define territory widget summary dto")
assertTrue(widgetServices.contains("struct HotspotWidgetSummaryDTO"), "infra should define hotspot widget summary dto")
assertTrue(widgetServices.contains("struct QuestRivalWidgetSummaryDTO"), "infra should define quest/rival widget summary dto")
assertTrue(widgetServices.contains("case hasData = \"has_data\""), "current widget services should decode has_data from top-level")
assertTrue(widgetServices.contains("case refreshedAt = \"refreshed_at\""), "current widget services should decode refreshed_at from top-level")
assertTrue(widgetServices.contains("rpc/rpc_get_widget_territory_summary"), "territory widget service should call territory rpc")
assertTrue(widgetServices.contains("rpc/rpc_get_widget_hotspot_summary"), "hotspot widget service should call hotspot rpc")
assertTrue(widgetServices.contains("rpc/rpc_get_widget_quest_rival_summary"), "quest/rival widget service should call quest/rival rpc")

assertTrue(readme.contains("docs/widget-summary-rpc-common-response-model-v1.md"), "README should link widget summary response model doc")
assertTrue(highRiskMatrix.contains("docs/widget-summary-rpc-common-response-model-v1.md"), "high-risk matrix should reference widget summary response model doc")
assertTrue(versionPolicy.contains("widget summary RPC"), "version policy should continue to include widget summary RPC family")
assertTrue(backendCheck.contains("widget_summary_rpc_response_model_unit_check.swift"), "backend_pr_check should run widget summary response model check")
assertTrue(iosPRCheck.contains("widget_summary_rpc_response_model_unit_check.swift"), "ios_pr_check should run widget summary response model check")

print("PASS: widget summary rpc response model unit checks")
