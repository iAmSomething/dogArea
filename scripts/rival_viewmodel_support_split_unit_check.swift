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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

func lineCount(_ source: String) -> Int {
    source.split(separator: "\n", omittingEmptySubsequences: false).count
}

let mainPath = "dogArea/Views/ProfileSettingView/RivalTabViewModel.swift"
let sessionPath = "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SessionLifecycle.swift"
let sharingPath = "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift"
let moderationPath = "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+ModerationAndLocation.swift"

let main = load(mainPath)
let session = load(sessionPath)
let sharing = load(sharingPath)
let moderation = load(moderationPath)

assertTrue(lineCount(main) <= 250, "RivalTabViewModel main file should stay slim after support split")
assertTrue(main.contains("final class RivalTabViewModel"), "main file should still own the type declaration")
assertTrue(!main.contains("func refreshHotspots(force: Bool = false)"), "main file should not keep hotspot refresh implementation inline")
assertTrue(!main.contains("func refreshLeaderboard(force: Bool = false)"), "main file should not keep leaderboard refresh implementation inline")
assertTrue(!main.contains("func locationManagerDidChangeAuthorization"), "main file should not keep CLLocation delegate implementation inline")
assertTrue(session.contains("func start()"), "session lifecycle support file should own start()")
assertTrue(session.contains("private func startAuthSessionObserverIfNeeded()"), "session lifecycle support file should own auth observer lifecycle")
assertTrue(sharing.contains("func refreshHotspots(force: Bool = false)"), "sharing support file should own hotspot refresh")
assertTrue(sharing.contains("func refreshLeaderboard(force: Bool = false)"), "sharing support file should own leaderboard refresh")
assertTrue(moderation.contains("func hideAlias(aliasCode: String)"), "moderation support file should own moderation actions")
assertTrue(moderation.contains("func locationManagerDidChangeAuthorization(_ manager: CLLocationManager)"), "moderation support file should own location delegate callbacks")

print("PASS: rival viewmodel support split unit checks")
