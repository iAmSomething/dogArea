import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
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

let authFlowSource = [
    loadMany([
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
]),
    load("dogArea/Source/AppSession/GuestDataUpgradeService.swift")
].joined(separator: "\n")
let homeViewSource = load("dogArea/Views/HomeView/HomeView.swift")

assertTrue(
    authFlowSource.contains("runUpgrade continue without local sessions"),
    "runUpgrade should continue even when local sessions are missing"
)
assertTrue(
    authFlowSource.contains("syncOutbox.requeuePermanentFailures()"),
    "force retry should support requeueing all outbox sessions without local snapshot"
)
assertTrue(
    authFlowSource.contains("let summary = await syncOutbox.flush(using: syncTransport, now: Date())"),
    "runUpgrade should still flush sync outbox"
)
assertTrue(
    authFlowSource.contains("clearPersistedReport(for: userId)"),
    "stale upgrade report should be clearable"
)
assertTrue(
    homeViewSource.contains(".onChange(of: authFlow.guestDataUpgradeResult?.executedAt)"),
    "HomeView should observe executedAt to refresh card after retry"
)

print("PASS: guest data upgrade retry unit checks")
