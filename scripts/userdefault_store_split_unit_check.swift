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

let userDefaultsSetting = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let profileStore = load("dogArea/Source/ProfileStore.swift")
let petSelectionStore = load("dogArea/Source/PetSelectionStore.swift")
let walkStore = load("dogArea/Source/WalkSessionMetadataStore.swift")
let profileSyncOutboxStore = load("dogArea/Source/ProfileSyncOutboxStore.swift")
let profileRepository = load("dogArea/Source/ProfileRepository.swift")
let spec = load("docs/userdefault-store-split-v1.md")

assertTrue(profileStore.contains("final class ProfileStore"), "ProfileStore should be split into dedicated file")
assertTrue(profileStore.contains("protocol ProfileStoring"), "ProfileStore should expose protocol")
assertTrue(petSelectionStore.contains("final class PetSelectionStore"), "PetSelectionStore should be split into dedicated file")
assertTrue(petSelectionStore.contains("protocol PetSelectionStoring"), "PetSelectionStore should expose protocol")
assertTrue(walkStore.contains("final class WalkSessionMetadataStore"), "WalkSessionMetadataStore should be split into dedicated file")
assertTrue(profileSyncOutboxStore.contains("final class ProfileSyncOutboxStore"), "ProfileSyncOutboxStore should be split into dedicated file")

assertTrue(userDefaultsSetting.contains("private let profileStore: ProfileStoring"), "UserdefaultSetting should depend on ProfileStoring")
assertTrue(userDefaultsSetting.contains("private let petSelectionStore: PetSelectionStoring"), "UserdefaultSetting should depend on PetSelectionStoring")
assertTrue(userDefaultsSetting.contains("private let walkSessionMetadataStore: WalkSessionMetadataStore"), "UserdefaultSetting should depend on WalkSessionMetadataStore")
assertTrue(userDefaultsSetting.contains("petSelectionStore.setSelectedPetId"), "selected pet update should delegate to PetSelectionStore")
assertTrue(userDefaultsSetting.contains("walkSessionMetadataStore.walkPointRecordModeRawValue"), "walk record mode should delegate to WalkSessionMetadataStore")

assertTrue(profileRepository.contains("profileStore: ProfileStoring"), "ProfileRepository should use ProfileStore abstraction")
assertTrue(profileRepository.contains("petSelectionStore: PetSelectionStoring"), "ProfileRepository should use PetSelectionStore abstraction")
assertTrue(spec.contains("UserdefaultSetting"), "split spec should document UserdefaultSetting facade strategy")

print("PASS: userdefault store split unit checks")
