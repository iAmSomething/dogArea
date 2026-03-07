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

let facade = load("dogArea/Source/UserdefaultSetting.swift")
let project = load("dogArea.xcodeproj/project.pbxproj")

let expectedFiles = [
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift"
]

for path in expectedFiles {
    assertTrue(
        FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path),
        "\(path) should exist after second split"
    )
    assertTrue(project.contains((path as NSString).lastPathComponent), "project should reference \((path as NSString).lastPathComponent)")
}

assertTrue(project.contains("UserDefaultsSupport"), "project should define UserDefaultsSupport group")
assertTrue(facade.contains("class UserdefaultSetting"), "UserdefaultSetting facade should remain")
assertTrue(facade.contains("profileStore: ProfileStoring"), "UserdefaultSetting facade should still inject ProfileStoring")
assertTrue(facade.contains("petSelectionStore: PetSelectionStoring"), "UserdefaultSetting facade should still inject PetSelectionStoring")
assertTrue(facade.contains("walkSessionMetadataStore: WalkSessionMetadataStore"), "UserdefaultSetting facade should still inject WalkSessionMetadataStore")
assertTrue(!facade.contains("final class FeatureFlagStore"), "UserdefaultSetting facade should not retain FeatureFlagStore implementation")
assertTrue(!facade.contains("final class AppMetricTracker"), "UserdefaultSetting facade should not retain AppMetricTracker implementation")
assertTrue(!facade.contains("final class DefaultMapPreferenceStore"), "UserdefaultSetting facade should not retain map preference store implementation")
assertTrue(!facade.contains("final class DefaultAppEventCenter"), "UserdefaultSetting facade should not retain event center implementation")
assertTrue(!facade.contains("final class SyncOutboxStore"), "UserdefaultSetting facade should not retain sync outbox implementation")
assertTrue(!facade.contains("struct PetInfo"), "UserdefaultSetting facade should not retain pet model implementation")
assertTrue(!facade.contains("struct UserInfo"), "UserdefaultSetting facade should not retain user model implementation")

print("PASS: userdefault second split unit checks")
