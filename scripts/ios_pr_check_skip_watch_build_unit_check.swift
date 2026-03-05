import Foundation

@inline(__always)
/// Asserts the provided condition and terminates the script when it is false.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to true.
///   - message: Failure reason printed to stderr when the assertion fails.
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let scriptPath = root.appendingPathComponent("scripts/ios_pr_check.sh")
let source = String(decoding: try! Data(contentsOf: scriptPath), as: UTF8.self)

assertTrue(
    source.contains("if [[ \"${DOGAREA_SKIP_WATCH_BUILD:-0}\" == \"1\" ]]; then"),
    "ios_pr_check should support DOGAREA_SKIP_WATCH_BUILD flag"
)
assertTrue(
    source.contains("echo \"[dogArea] DOGAREA_SKIP_WATCH_BUILD=1, skipping watchOS xcodebuild\""),
    "ios_pr_check should print a clear skip-watch message"
)
assertTrue(
    source.contains("echo \"[dogArea] building watchOS target\""),
    "ios_pr_check should retain default watchOS build path"
)

print("PASS: ios_pr_check skip watch build unit checks")
