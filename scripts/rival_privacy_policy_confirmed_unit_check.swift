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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let rivalViewModel = loadMany([
    "dogArea/Views/ProfileSettingView/RivalTabViewModel.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SessionLifecycle.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+ModerationAndLocation.swift"
])
let rivalView = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")

assertTrue(
    rivalViewModel.contains("locationSharingPolicyInitializedKeyPrefix"),
    "rival privacy policy should keep per-user initialization key prefix"
)
assertTrue(
    rivalViewModel.contains("loadLocationSharingPreference(for: currentUserId)"),
    "rival tab should resolve sharing state from session-aware policy loader"
)
assertTrue(
    rivalViewModel.contains("seededValue = true"),
    "member sharing default should seed to ON when no prior preference exists"
)
assertTrue(
    rivalViewModel.contains("visibilityOffPropagationDeadline: TimeInterval = 30"),
    "sharing OFF policy should preserve 30-second propagation window"
)
assertTrue(
    rivalViewModel.contains("syncVisibilityOffWithRetry"),
    "sharing OFF flow should retry visibility sync within propagation window"
)
assertTrue(
    rivalViewModel.contains("persistLocationSharingPreference(false, for: userId)"),
    "sharing OFF should be persisted immediately before server acknowledgement"
)
assertTrue(
    rivalViewModel.contains("preferenceStore.removeObject(forKey: locationSharingLegacyGlobalKey)"),
    "legacy global sharing key should be cleaned during migration to scoped key"
)

assertTrue(
    rivalView.contains("300m 저해상도"),
    "rival privacy UI copy should communicate 300m guest precision policy"
)
assertTrue(
    rivalView.contains("최대 30초"),
    "rival privacy UI copy should communicate OFF propagation target"
)
assertTrue(
    rivalView.contains("7일 보존 후 삭제"),
    "rival privacy UI copy should communicate withdrawal retention policy"
)

print("PASS: rival privacy policy confirmed unit checks")
