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

let migration = load("supabase/migrations/20260303190000_territory_widget_summary_rpc.sql")
let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift"
])
let bridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let widget = load("dogAreaWidgetExtension/WalkControlWidget.swift")
let bundle = load("dogAreaWidgetExtension/WalkControlWidgetBundle.swift")

assertTrue(migration.contains("create or replace function public.rpc_get_widget_territory_summary"), "migration should create territory widget summary rpc")
assertTrue(migration.contains("defense_scheduled_tile_count"), "migration should return defense scheduled tile count")
assertTrue(migration.contains("tile_events"), "migration should use tile_events for today metric")
assertTrue(migration.contains("season_tile_scores"), "migration should use season_tile_scores for defense metric")
assertTrue(migration.contains("grant execute on function public.rpc_get_widget_territory_summary"), "migration should grant execute on widget summary rpc")

assertTrue(infra.contains("protocol TerritoryWidgetSummaryServiceProtocol"), "infra should define territory widget summary service protocol")
assertTrue(infra.contains("struct TerritoryWidgetSummaryService"), "infra should include territory widget summary service")
assertTrue(infra.contains("rpc/rpc_get_widget_territory_summary"), "infra should call territory widget summary rpc")
assertTrue(infra.contains("DefaultTerritoryWidgetSnapshotSyncService"), "infra should include territory widget snapshot sync service")

assertTrue(bridge.contains("territorySnapshotStorageKey"), "widget bridge contract should define territory snapshot key")
assertTrue(bridge.contains("territoryWidgetKind"), "widget bridge contract should define territory widget kind")

assertTrue(snapshotStore.contains("enum TerritoryWidgetSnapshotStatus"), "snapshot store should define territory widget status enum")
assertTrue(snapshotStore.contains("struct TerritoryWidgetSummarySnapshot"), "snapshot store should define territory summary snapshot")
assertTrue(snapshotStore.contains("final class DefaultTerritoryWidgetSnapshotStore"), "snapshot store should include territory snapshot storage implementation")

assertTrue(widget.contains("struct TerritoryStatusTimelineProvider"), "widget extension should provide territory timeline provider")
assertTrue(widget.contains("struct TerritoryStatusWidget"), "widget extension should define territory widget")
assertTrue(widget.contains("supportedFamilies([.systemSmall, .systemMedium])"), "territory widget should support small and medium families")
assertTrue(bundle.contains("TerritoryStatusWidget()"), "widget bundle should register territory status widget")

print("PASS: territory status widget unit checks")
