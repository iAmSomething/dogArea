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
let configurePath = root.appendingPathComponent("dogArea/Views/GlobalViews/AlertView/CustomAlertConfigure.swift")
let configureSource = String(decoding: try! Data(contentsOf: configurePath), as: UTF8.self)
let viewModelPath = root.appendingPathComponent("dogArea/Views/GlobalViews/AlertView/CustomAlertViewModel.swift")
let viewModelSource = String(decoding: try! Data(contentsOf: viewModelPath), as: UTF8.self)
let mapAlertPath = root.appendingPathComponent("dogArea/Views/MapView/MapSubViews/MapAlertSubView.swift")
let mapAlertSource = String(decoding: try! Data(contentsOf: mapAlertPath), as: UTF8.self)

assertTrue(
    configureSource.contains("case loggedOut") && configureSource.contains("case authRequired"),
    "AlertActionType should distinguish logged-out and auth-required alert states"
)
assertTrue(
    configureSource.contains("static func loggedOutAlert(") &&
    configureSource.contains("static func authRequiredAlert("),
    "AlertModel should provide dedicated factory helpers for auth alert states"
)
assertTrue(
    configureSource.contains("TODO: 로그인 추가 시 권한 없음 case 추가") == false,
    "Legacy auth alert TODO should be removed once explicit auth alert states are implemented"
)
assertTrue(
    viewModelSource.contains("type: AlertActionType = .loggedOut"),
    "CustomAlertViewModel default state should use the explicit loggedOut alert type"
)
assertTrue(
    mapAlertSource.contains("case .loggedOut, .authRequired:"),
    "MapAlertSubView should handle both auth alert states"
)

print("PASS: custom alert auth state unit checks")
