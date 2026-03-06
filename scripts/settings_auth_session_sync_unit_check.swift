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
    "dogArea/Views/ProfileSettingView/SettingViewModel.swift",
    "dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+SessionSync.swift"
])

assertTrue(
    source.contains("bindAuthSessionSync()"),
    "setting view model should bind auth-session change notifications"
)
assertTrue(
    source.contains("NotificationCenter.default.publisher(for: .authSessionDidChange)"),
    "setting view model should subscribe to auth session change notification"
)
assertTrue(
    source.contains("private func handleAuthSessionDidChange()"),
    "setting view model should provide auth session change handler"
)
assertTrue(
    source.contains("guard authSessionStore.currentTokenSession() != nil else"),
    "auth session handler should detect guest downgrade by token absence"
)
assertTrue(
    source.contains("userInfo = nil"),
    "auth session handler should clear cached user info on guest downgrade"
)

print("PASS: settings auth session sync unit checks")
