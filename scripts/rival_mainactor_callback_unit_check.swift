import Foundation

@inline(__always)
/// Asserts the provided condition and exits with failure when it is false.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to true.
///   - message: Failure reason printed to stderr when assertion fails.
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
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
    source.contains("Task { @MainActor [weak self] in\n                guard let self else { return }\n                self.refreshHotspots(force: false)\n                self.refreshLeaderboard(force: false)\n            }"),
    "Polling timer should hop to MainActor before refreshing Rival state"
)
assertTrue(
    source.contains("Task { @MainActor [weak self] in\n                self?.handleAuthSessionDidChange()\n            }"),
    "Auth session observer should hop to MainActor before mutating Rival state"
)

print("PASS: rival mainactor callback unit checks")
