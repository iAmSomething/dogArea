import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")

assertTrue(
    rootView.contains("@State private var pendingWalkWidgetRoute: WalkWidgetActionRoute? = nil"),
    "RootView should keep pending widget route while auth overlay is active"
)
assertTrue(
    rootView.contains("if isAuthenticationOverlayActive {"),
    "RootView should guard walk widget dispatch when auth overlay is active"
)
assertTrue(
    rootView.contains("pendingWalkWidgetRoute = route"),
    "RootView should enqueue walk widget action during auth overlay"
)
assertTrue(
    rootView.contains("dispatchPendingWalkWidgetActionIfNeeded()"),
    "RootView should replay pending widget action after auth overlay closes"
)
assertTrue(
    rootView.contains("private func dispatchPendingWalkWidgetActionIfNeeded()"),
    "RootView should define explicit pending widget action replay helper"
)

print("PASS: auth overlay widget action defer unit checks")
