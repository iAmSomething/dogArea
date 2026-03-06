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
let rootViewPath = root.appendingPathComponent("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let rootViewSource = String(decoding: try! Data(contentsOf: rootViewPath), as: UTF8.self)
let mapStorePath = root.appendingPathComponent("dogArea/Views/GlobalViews/BaseView/MapViewModelStore.swift")
let mapStoreSource = String(decoding: try! Data(contentsOf: mapStorePath), as: UTF8.self)
let bannerPath = root.appendingPathComponent("dogArea/Views/GlobalViews/BaseView/GuestDataUpgradeResultBanner.swift")
let bannerSource = String(decoding: try! Data(contentsOf: bannerPath), as: UTF8.self)

assertTrue(
    rootViewSource.contains("private final class MapViewModelStore") == false,
    "RootView should not define MapViewModelStore inline"
)
assertTrue(
    rootViewSource.contains("private struct GuestDataUpgradeResultBanner") == false,
    "RootView should not define GuestDataUpgradeResultBanner inline"
)
assertTrue(
    rootViewSource.contains("private let itemFormatter") == false,
    "RootView should remove unused itemFormatter global"
)
assertTrue(
    mapStoreSource.contains("final class MapViewModelStore: ObservableObject"),
    "MapViewModelStore should live in its own file"
)
assertTrue(
    bannerSource.contains("struct GuestDataUpgradeResultBanner: View"),
    "GuestDataUpgradeResultBanner should live in its own file"
)

print("PASS: root view supporting type split unit checks")
