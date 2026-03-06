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
    "dogArea/Views/ProfileSettingView/RivalTabViewModel.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SessionLifecycle.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+ModerationAndLocation.swift"
])

assertTrue(
    source.contains("authSessionObserver: NSObjectProtocol? = nil"),
    "rival tab should keep an auth-session observer token"
)
assertTrue(
    source.contains("startAuthSessionObserverIfNeeded()"),
    "rival tab should start auth-session observer on tab activation"
)
assertTrue(
    source.contains("private func startAuthSessionObserverIfNeeded()"),
    "rival tab should define observer start helper"
)
assertTrue(
    source.contains("forName: .authSessionDidChange"),
    "rival tab observer should subscribe auth session changes"
)
assertTrue(
    source.contains("private func handleAuthSessionDidChange()"),
    "rival tab should define auth-session sync handler"
)
assertTrue(
    source.contains("refreshSessionContext()"),
    "auth-session sync handler should refresh rival session context immediately"
)
assertTrue(
    source.contains("private func stopAuthSessionObserver()"),
    "rival tab should define observer cleanup helper"
)

print("PASS: rival auth session sync unit checks")
