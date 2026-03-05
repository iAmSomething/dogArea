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

let source = load("dogArea/Source/UserdefaultSetting.swift")

assertTrue(
    source.contains("private let lastRefreshAtStorageKey = \"feature.flags.last_refresh_at.v1\""),
    "feature flag store should persist last refresh timestamp key"
)
assertTrue(
    source.contains("private let minimumRefreshInterval: TimeInterval = 60"),
    "feature flag store should define minimum refresh interval"
)
assertTrue(
    source.contains("func refresh(force: Bool) async -> Bool"),
    "feature flag store should support force refresh entrypoint"
)
assertTrue(
    source.contains("guard shouldSkipRefresh(force: force, now: Date()) == false else"),
    "refresh should short-circuit when throttled"
)
assertTrue(
    source.contains("persistLastRefreshAtLocked()"),
    "refresh should persist last refresh timestamp after success"
)
assertTrue(
    source.contains("private func shouldSkipRefresh(force: Bool, now: Date) -> Bool"),
    "feature flag store should expose throttle decision helper"
)

print("PASS: feature flag refresh throttle unit checks")
