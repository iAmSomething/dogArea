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
let mapViewModelStore = load("dogArea/Views/GlobalViews/BaseView/MapViewModelStore.swift")

assertTrue(
    rootView.contains("private var isAuthenticationOverlayActive: Bool"),
    "RootView should compute authentication overlay visibility"
)
assertTrue(
    rootView.contains(".onChange(of: isAuthenticationOverlayActive)"),
    "RootView should react to overlay visibility changes"
)
assertTrue(
    rootView.contains("mapViewModelStore.suspendForAuthenticationOverlay()"),
    "RootView should suspend map view model while auth overlay is active"
)
assertTrue(
    rootView.contains("accessibilityIdentifier(\"screen.map.suspended\")"),
    "RootView should render suspended placeholder instead of MapView during auth overlay"
)
assertTrue(
    mapViewModelStore.contains("func suspendForAuthenticationOverlay()"),
    "MapViewModelStore should provide explicit overlay suspension API"
)

print("PASS: signin metal overlay guard unit checks")
