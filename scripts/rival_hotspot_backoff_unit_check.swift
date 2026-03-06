import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let source = try String(contentsOf: sourceURL, encoding: .utf8)

assertTrue(source.contains("private let hotspotMinimumRefreshInterval: TimeInterval = 10"), "hotspot refresh interval should be throttled to 10 seconds")
assertTrue(source.contains("private let leaderboardMinimumRefreshInterval: TimeInterval = 10"), "leaderboard refresh interval should be throttled to 10 seconds")
assertTrue(source.contains("private var hotspotFailureRetryAt: Date = .distantPast"), "hotspot failure retry gate should exist")
assertTrue(source.contains("private func applyHotspotFailureBackoff"), "hotspot failure backoff helper should exist")
assertTrue(source.contains("private func shouldSkipHotspotRefresh(force: Bool, now: Date) -> Bool"), "hotspot skip helper should exist")
assertTrue(source.contains("guard isHotspotRefreshing == false else { return }"), "hotspot refresh should block overlapping requests")
assertTrue(source.contains("guard isLeaderboardRefreshing == false else { return }"), "leaderboard refresh should block overlapping requests")
let didUpdateStart = source.range(of: "func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])")
assertTrue(didUpdateStart != nil, "didUpdateLocations delegate should exist")
if let didUpdateStart {
    let didUpdateBody = String(source[didUpdateStart.lowerBound...])
    assertTrue(didUpdateBody.contains("refreshHotspots(force: false)"), "didUpdateLocations should trigger hotspot refresh")
    assertTrue(!didUpdateBody.contains("refreshLeaderboard(force: false)"), "didUpdateLocations should not trigger leaderboard refresh on every location tick")
}

print("PASS: rival hotspot backoff unit checks")
