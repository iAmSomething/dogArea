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

let core = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let edge = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseEdgeSupportServices.swift")
let sync = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let presenceQuest = load("dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift")
let widgetArea = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift")
let authAsset = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift")
let pbxproj = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(core.contains("struct SupabaseHTTPClient"), "core file should retain shared HTTP client")
assertTrue(core.contains("protocol HotspotWidgetSnapshotSyncing"), "core file should retain shared protocol surface")
assertTrue(!core.contains("struct FeatureControlService"), "core file should not retain feature-control implementation")
assertTrue(!core.contains("struct SupabaseSyncOutboxTransport"), "core file should not retain sync transport implementation")
assertTrue(!core.contains("struct NearbyPresenceService"), "core file should not retain nearby presence implementation")
assertTrue(!core.contains("final class DefaultQuestRivalWidgetSnapshotSyncService"), "core file should not retain widget sync implementation")
assertTrue(!core.contains("final class SupabaseAccountDeletionService"), "core file should not retain auth/account implementation")

assertTrue(edge.contains("struct FeatureControlService"), "edge service file should define feature-control service")
assertTrue(edge.contains("struct CaricatureEdgeClient"), "edge service file should define caricature client")
assertTrue(sync.contains("struct SupabaseSyncOutboxTransport"), "sync service file should define walk sync transport")
assertTrue(sync.contains("struct SupabaseProfileSyncTransport"), "sync service file should define profile sync transport")
assertTrue(presenceQuest.contains("struct NearbyPresenceService"), "presence/quest file should define nearby presence service")
assertTrue(presenceQuest.contains("struct RivalLeagueService"), "presence/quest file should define rival league service")
assertTrue(presenceQuest.contains("struct QuestRivalWidgetSummaryService"), "presence/quest file should define quest/rival summary service")
assertTrue(widgetArea.contains("final class DefaultQuestRivalWidgetSnapshotSyncService"), "widget file should define quest widget snapshot sync service")
assertTrue(widgetArea.contains("struct TerritoryWidgetSummaryService"), "widget file should define territory widget summary service")
assertTrue(widgetArea.contains("struct HotspotWidgetSummaryService"), "widget file should define hotspot widget summary service")
assertTrue(widgetArea.contains("final class SupabaseAreaReferenceRepository"), "widget file should define area reference repository")
assertTrue(authAsset.contains("final class SupabaseAccountDeletionService"), "auth/asset file should define account deletion service")
assertTrue(authAsset.contains("final class DeviceAppleCredentialAuthService"), "auth/asset file should define apple credential auth service")
assertTrue(authAsset.contains("final class SupabaseProfileImageRepository"), "auth/asset file should define profile image repository")

assertTrue(pbxproj.contains("SupabaseServices"), "project should register SupabaseServices group")
assertTrue(pbxproj.contains("SupabaseEdgeSupportServices.swift in Sources"), "project should build edge support services")
assertTrue(pbxproj.contains("SupabaseSyncServices.swift in Sources"), "project should build sync services")
assertTrue(pbxproj.contains("SupabasePresenceAndQuestServices.swift in Sources"), "project should build presence/quest services")
assertTrue(pbxproj.contains("SupabaseWidgetAndAreaServices.swift in Sources"), "project should build widget/area services")
assertTrue(pbxproj.contains("SupabaseAuthAndAssetServices.swift in Sources"), "project should build auth/asset services")

print("PASS: supabase infrastructure service split unit checks")
