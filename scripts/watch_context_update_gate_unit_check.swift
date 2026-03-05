import Foundation

@inline(__always)
/// Asserts the given condition and exits with failure when it is false.
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
let sourcePath = root.appendingPathComponent("dogArea/Views/MapView/MapViewModel.swift")
let source = String(decoding: try! Data(contentsOf: sourcePath), as: UTF8.self)

assertTrue(
    source.contains("private func resolveWatchContextSession(updateStatusText: Bool) -> WCSession?"),
    "MapViewModel should provide a shared watch context gate helper"
)
assertTrue(
    source.contains("guard watchSession.activationState == .activated else"),
    "watch context gate should require activated WCSession"
)
assertTrue(
    source.contains("guard watchSession.isPaired else"),
    "watch context gate should require paired watch on iOS"
)
assertTrue(
    source.contains("guard watchSession.isWatchAppInstalled else"),
    "watch context gate should require installed watch app on iOS"
)
assertTrue(
    source.contains("guard let watchSession = resolveWatchContextSession(updateStatusText: false) else { return }"),
    "publishWatchState should use shared watch context gate"
)
assertTrue(
    source.contains("guard let watchSession = resolveWatchContextSession(updateStatusText: true) else { return }"),
    "syncWatchContext should use shared watch context gate"
)

print("PASS: watch context update gate unit checks")
