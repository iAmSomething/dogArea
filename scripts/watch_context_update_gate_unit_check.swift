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

func load(_ relativePath: String) -> String {
    let path = root.appendingPathComponent(relativePath)
    return String(decoding: try! Data(contentsOf: path), as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let source = loadMany([
    "dogArea/Views/MapView/MapViewModel.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift"
])

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
