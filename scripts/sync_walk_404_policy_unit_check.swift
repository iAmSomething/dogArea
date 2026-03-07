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

let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift"
])
let syncStore = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let mapVM = load("dogArea/Views/MapView/MapViewModel.swift")
let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/Cards/HomeGuestDataUpgradeCardView.swift"
])

assertTrue(
    infra.contains("private enum SyncWalkFunctionRoute"),
    "sync-walk transport should define primary/legacy route fallback"
)
assertTrue(
    infra.contains("SyncWalkFunctionRoute.legacy"),
    "sync-walk transport should attempt legacy function route on 404"
)
assertTrue(
    infra.contains("guard isSyncWalkFunctionTemporarilyUnavailable() == false else"),
    "sync-walk transport should short-circuit while function unavailability cooldown is active"
)
assertTrue(
    infra.contains("case 404:\n                    markSyncWalkFunctionTemporarilyUnavailable()\n                    return .permanent(.notConfigured)"),
    "sync-walk 404 should be treated as permanent notConfigured to prevent endless retries"
)
assertTrue(
    syncStore.contains("if code == .notConfigured {\n                    continue\n                }"),
    "outbox flush should continue draining queued stages after notConfigured permanent failure"
)
assertTrue(
    mapVM.contains("서버 기능 미배포(404)"),
    "map sync status should expose user-facing 404 fallback message"
)
assertTrue(
    homeView.contains("동기화 서버 기능이 아직 준비되지 않았어요(404)."),
    "home migration card should expose user-facing 404 fallback message"
)

print("PASS: sync-walk 404 policy unit checks")
