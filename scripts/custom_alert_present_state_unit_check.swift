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
    source.contains("func callAlert(type: AlertActionType)"),
    "callAlert should exist in CustomAlertViewModel"
)
assertTrue(
    source.contains("func callCustomAlert(") &&
    source.contains("model: AlertModel") &&
    source.contains("leftAction: @escaping () -> Void") &&
    source.contains("rightAction: @escaping () -> Void = {}"),
    "callCustomAlert should exist in CustomAlertViewModel"
)
assertTrue(
    source.contains("isAlert = true"),
    "Alert presentation state should be set explicitly to true"
)
assertTrue(
    source.contains("isAlert.toggle()") == false,
    "Alert presentation should not use toggle to avoid accidental dismissals"
)

print("PASS: custom alert present state unit checks")
