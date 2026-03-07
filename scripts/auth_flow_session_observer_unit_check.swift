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

let source = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])

assertTrue(
    source.contains("private var authSessionObserver: AnyCancellable?"),
    "auth flow should keep a cancellable for auth session observer"
)
assertTrue(
    source.contains("bindAuthSessionSync()"),
    "auth flow init path should bind auth session sync"
)
assertTrue(
    source.contains("deinit {\n        authSessionObserver?.cancel()\n    }"),
    "auth flow should cancel auth session observer on deinit"
)
assertTrue(
    source.contains("private func bindAuthSessionSync()"),
    "auth flow should define auth session sync binding helper"
)
assertTrue(
    source.contains("NotificationCenter.default.publisher(for: .authSessionDidChange)"),
    "auth flow should subscribe authSessionDidChange notification"
)
assertTrue(
    source.contains("self?.refresh()"),
    "auth flow observer should trigger refresh on session updates"
)

print("PASS: auth flow session observer unit checks")
