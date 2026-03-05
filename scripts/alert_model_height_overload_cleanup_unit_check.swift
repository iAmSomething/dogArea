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
let sourcePath = root.appendingPathComponent("dogArea/Views/GlobalViews/AlertView/CustomAlertConfigure.swift")
let source = String(decoding: try! Data(contentsOf: sourcePath), as: UTF8.self)

assertTrue(
    source.contains("func height(isShowVerticalButtons: Bool = false) -> CGFloat"),
    "AlertModel should keep height(isShowVerticalButtons:) API used by CustomAlertView"
)
assertTrue(
    source.contains("func height(_ setHeight: CGFloat) -> CGFloat") == false,
    "unused AlertModel height overload should be removed"
)

print("PASS: alert model height overload cleanup unit checks")
