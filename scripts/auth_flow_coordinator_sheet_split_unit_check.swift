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
let coordinatorPath = root.appendingPathComponent("dogArea/Source/AppSession/AuthFlowCoordinator.swift")
let coordinatorSource = String(decoding: try! Data(contentsOf: coordinatorPath), as: UTF8.self)
let memberSheetPath = root.appendingPathComponent("dogArea/Views/SigningView/Components/MemberUpgradeSheetView.swift")
let memberSheetSource = String(decoding: try! Data(contentsOf: memberSheetPath), as: UTF8.self)
let guestSheetPath = root.appendingPathComponent("dogArea/Views/SigningView/Components/GuestDataUpgradePromptSheetView.swift")
let guestSheetSource = String(decoding: try! Data(contentsOf: guestSheetPath), as: UTF8.self)

assertTrue(
    coordinatorSource.contains("struct MemberUpgradeSheetView") == false,
    "AuthFlowCoordinator should not define MemberUpgradeSheetView inline"
)
assertTrue(
    coordinatorSource.contains("struct GuestDataUpgradePromptSheetView") == false,
    "AuthFlowCoordinator should not define GuestDataUpgradePromptSheetView inline"
)
assertTrue(
    memberSheetSource.contains("struct MemberUpgradeSheetView: View"),
    "MemberUpgradeSheetView should live in its dedicated component file"
)
assertTrue(
    guestSheetSource.contains("struct GuestDataUpgradePromptSheetView: View"),
    "GuestDataUpgradePromptSheetView should live in its dedicated component file"
)

print("PASS: auth flow coordinator sheet split unit checks")
