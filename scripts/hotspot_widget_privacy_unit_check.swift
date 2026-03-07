import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let migration = load("supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql")
let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift"
])
let model = load("dogArea/Source/Domain/Map/Models/MapModel.swift")
let bridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let store = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let widget = loadMany([
    "dogAreaWidgetExtension/Shared/WidgetPresentationSupport.swift",
    "dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift"
])
let bundle = load("dogAreaWidgetExtension/WalkControlWidgetBundle.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let policyDoc = load("docs/hotspot-widget-privacy-mapping-v1.md")

assertTrue(migration.contains("create table if not exists public.widget_hotspot_summary_cache"), "migration should create hotspot summary cache table")
assertTrue(migration.contains("create or replace function public.rpc_get_widget_hotspot_summary"), "migration should create hotspot widget summary rpc")
assertTrue(migration.contains("rate_limited_cache"), "migration should include rate-limit cache policy")
assertTrue(migration.contains("privacy_mode"), "migration should include privacy mode field")
assertTrue(migration.contains("suppression_reason"), "migration should include suppression reason field")
assertTrue(migration.contains("grant execute on function public.rpc_get_widget_hotspot_summary"), "migration should grant execute to rpc")

assertTrue(infra.contains("struct HotspotWidgetSummaryDTO"), "infra should define hotspot widget summary dto")
assertTrue(infra.contains("protocol HotspotWidgetSummaryServiceProtocol"), "infra should define hotspot widget summary protocol")
assertTrue(infra.contains("struct HotspotWidgetSummaryService"), "infra should include hotspot widget summary service")
assertTrue(infra.contains("rpc/rpc_get_widget_hotspot_summary"), "infra should call hotspot summary rpc")
assertTrue(infra.contains("DefaultHotspotWidgetSnapshotSyncService"), "infra should include hotspot widget snapshot sync service")
assertTrue(infra.contains("privacy_mode"), "nearby service should decode privacy_mode")
assertTrue(infra.contains("suppression_reason"), "nearby service should decode suppression_reason")

assertTrue(model.contains("privacyMode"), "nearby hotspot dto should include privacy mode")
assertTrue(model.contains("suppressionReason"), "nearby hotspot dto should include suppression reason")

assertTrue(bridge.contains("hotspotSnapshotStorageKey"), "bridge contract should define hotspot snapshot key")
assertTrue(bridge.contains("hotspotWidgetKind"), "bridge contract should define hotspot widget kind")
assertTrue(store.contains("enum HotspotWidgetSnapshotStatus"), "snapshot store should define hotspot widget status")
assertTrue(store.contains("final class DefaultHotspotWidgetSnapshotStore"), "snapshot store should define hotspot snapshot store")

assertTrue(rootView.contains("syncHotspotWidgetSnapshot"), "root view should sync hotspot widget snapshot on lifecycle")
assertTrue(widget.contains("struct HotspotStatusTimelineProvider"), "widget extension should include hotspot timeline provider")
assertTrue(widget.contains("struct HotspotStatusWidget"), "widget extension should include hotspot widget")
assertTrue(bundle.contains("HotspotStatusWidget()"), "widget bundle should register hotspot widget")
assertTrue(widget.contains("signalDistributionSummary"), "widget should summarize distribution without raw counts")
assertTrue(widget.contains("stageChip"), "widget should render stage chips")
assertTrue(widget.contains("지역 트렌드 단계를 확인할 수 있어요"), "guest card should describe trend-only exposure")
assertTrue(widget.contains("개인 좌표/정밀 카운트는 제공하지 않습니다"), "widget policy footnote should mention no precise count exposure")
assertTrue(widget.contains("k-익명 정책으로 백분위 단계만 제공됩니다"), "widget should include k-anon copy")
assertTrue(!widget.contains("Text(\"높음 \\(summary.highCellCount)"), "widget should not expose raw stage counts on text")
assertTrue(!widget.contains("cellMetric(title:"), "widget should not expose numeric metric tiles")

assertTrue(policyDoc.contains("# 핫스팟 위젯 프라이버시 매핑 v1"), "policy doc should exist with title")
assertTrue(policyDoc.contains("| `full` | `null` |"), "policy doc should define full visibility row")
assertTrue(policyDoc.contains("| `percentile_only` | `k_anon` |"), "policy doc should define k-anon mapping row")
assertTrue(policyDoc.contains("| `guarded` | `sensitive_mask` |"), "policy doc should define sensitive mask mapping row")
assertTrue(policyDoc.contains("| `guest` | `guest_mode` |"), "policy doc should define guest mapping row")
assertTrue(policyDoc.contains("좌표 미노출"), "policy doc should explicitly document coordinate suppression")

print("PASS: hotspot widget privacy unit checks")
