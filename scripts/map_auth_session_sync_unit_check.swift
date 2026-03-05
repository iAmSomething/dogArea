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

let source = load("dogArea/Views/MapView/MapViewModel.swift")

assertTrue(
    source.contains("forName: .authSessionDidChange"),
    "map view model should observe auth session changes"
)
assertTrue(
    source.contains("self?.handleAuthSessionDidChange()"),
    "auth session observer should trigger map session sync handler"
)
assertTrue(
    source.contains("private func handleAuthSessionDidChange()"),
    "map view model should define auth session sync handler"
)
assertTrue(
    source.contains("applyFeatureFlags()"),
    "auth session sync handler should reapply feature flag/session gating"
)
assertTrue(
    source.contains("refreshRenderableNearbyHotspots()"),
    "feature flag application should refresh nearby hotspot render nodes"
)

print("PASS: map auth session sync unit checks")
