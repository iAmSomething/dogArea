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
    source.contains("private func applyWatchAction(_ envelope: WatchActionEnvelope)"),
    "typed watch action handler should remain in MapViewModel"
)
assertTrue(
    source.contains("private func applyWatchAction(_ action: String)") == false,
    "legacy string-based watch action handler should be removed"
)

print("PASS: watch legacy string path cleanup unit checks")
