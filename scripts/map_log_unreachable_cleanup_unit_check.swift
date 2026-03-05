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
    source.contains("private func logNearbyHotspotErrorIfNeeded(_ error: Error)"),
    "map view model should expose nearby hotspot error log helper"
)
assertTrue(
    source.contains("private func logVisibilitySyncErrorIfNeeded(_ error: Error)"),
    "map view model should expose visibility error log helper"
)
assertTrue(
    source.contains("#else\n        let now = Date()"),
    "debug/release log branches should be separated with #else path"
)
assertTrue(
    source.contains("lastNearbyHotspotErrorLogAt = Date()\n        #else"),
    "nearby hotspot debug log path should no longer return before #endif"
)
assertTrue(
    source.contains("lastVisibilitySyncErrorLogAt = Date()\n        #else"),
    "visibility debug log path should no longer return before #endif"
)
assertTrue(
    !source.contains("lastNearbyHotspotErrorLogAt = Date()\n        return\n        #endif"),
    "nearby hotspot logger should not include unreachable code pattern"
)
assertTrue(
    !source.contains("lastVisibilitySyncErrorLogAt = Date()\n        return\n        #endif"),
    "visibility logger should not include unreachable code pattern"
)

print("PASS: map log unreachable cleanup unit checks")
