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

let migration = load("supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql")
let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let model = load("dogArea/Source/Domain/Map/Models/MapModel.swift")
let bridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let store = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let widget = load("dogAreaWidgetExtension/WalkControlWidget.swift")
let bundle = load("dogAreaWidgetExtension/WalkControlWidgetBundle.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")

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

print("PASS: hotspot widget privacy unit checks")
