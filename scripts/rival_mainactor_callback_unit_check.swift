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
let sourceURL = root.appendingPathComponent("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let source = try String(contentsOf: sourceURL, encoding: .utf8)

assertTrue(
    source.contains("Task { @MainActor [weak self] in\n                guard let self else { return }\n                self.refreshHotspots(force: false)\n                self.refreshLeaderboard(force: false)\n            }"),
    "Polling timer should hop to MainActor before refreshing Rival state"
)
assertTrue(
    source.contains("Task { @MainActor [weak self] in\n                self?.handleAuthSessionDidChange()\n            }"),
    "Auth session observer should hop to MainActor before mutating Rival state"
)

print("PASS: rival mainactor callback unit checks")
