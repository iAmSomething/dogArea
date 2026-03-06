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
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])

assertTrue(
    source.contains("@Published private(set) var sessionStateSnapshot: AppSessionState = AppFeatureGate.currentSession()"),
    "auth flow should expose a published session state snapshot"
)
assertTrue(
    source.contains("var sessionState: AppSessionState {\n        sessionStateSnapshot\n    }"),
    "auth flow sessionState should read from published snapshot"
)
assertTrue(
    source.contains("func refresh() {\n        syncSessionStateSnapshot()"),
    "refresh should sync session snapshot before branch decisions"
)
assertTrue(
    source.contains("func startReauthenticationFlow() {\n        authSessionStore.clearTokenSession()\n        syncSessionStateSnapshot()"),
    "reauth flow should sync session snapshot right after token session clear"
)
assertTrue(
    source.contains("func completeSignIn() {\n        syncSessionStateSnapshot()"),
    "completeSignIn should sync session snapshot for immediate UI refresh"
)
assertTrue(
    source.contains("private func syncSessionStateSnapshot()"),
    "auth flow should define a dedicated session snapshot sync helper"
)

print("PASS: auth flow session snapshot unit checks")
