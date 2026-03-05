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
let sourcePath = root.appendingPathComponent("dogArea/Views/GlobalViews/AlertView/CustomAlertViewModel.swift")
let source = String(decoding: try! Data(contentsOf: sourcePath), as: UTF8.self)

assertTrue(
    source.contains("@MainActor"),
    "CustomAlertViewModel should be isolated to MainActor"
)
assertTrue(
    source.contains("public final class CustomAlertViewModel"),
    "CustomAlertViewModel should be final to keep alert state boundary explicit"
)
assertTrue(
    source.contains("func callAlert(type: AlertActionType)") && source.contains("isAlert = true"),
    "callAlert should set explicit presentation state"
)

print("PASS: custom alert mainactor unit checks")
