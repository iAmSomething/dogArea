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
    source.contains("private func applyWatchAction(_ envelope: WatchActionEnvelope)"),
    "typed watch action handler should remain in MapViewModel"
)
assertTrue(
    source.contains("private func applyWatchAction(_ action: String)") == false,
    "legacy string-based watch action handler should be removed"
)

print("PASS: watch legacy string path cleanup unit checks")
