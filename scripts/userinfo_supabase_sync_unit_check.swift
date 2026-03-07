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

let migration = load("supabase/migrations/20260227000000_user_pet_profile_fields_sync.sql")
let edgeFunction = load("supabase/functions/sync-profile/index.ts")
let userdefaultSetting = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift",
    "dogArea/Source/ProfileSyncOutboxStore.swift",
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let profileRepository = load("dogArea/Source/ProfileRepository.swift")
let settingViewModel = loadMany([
    "dogArea/Views/ProfileSettingView/SettingViewModel.swift",
    "dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+ProfileEditing.swift",
    "dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+PetManagement.swift"
])
let signingViewModel = load("dogArea/Views/SigningView/SigningViewModel.swift")
let syncSpec = load("docs/userinfo-supabase-sync-v1.md")
let schemaSpec = load("docs/supabase-schema-v1.md")

assertTrue(migration.contains("profile_message"), "migration must add profiles.profile_message")
assertTrue(migration.contains("age_years"), "migration must add pets.age_years")
assertTrue(migration.contains("pets_gender_allowed_check"), "migration must enforce pets gender constraint")
assertTrue(migration.contains("pets_age_years_range_check"), "migration must enforce pets age range check")

assertTrue(edgeFunction.contains("sync_profile_stage"), "edge function must support sync_profile_stage action")
assertTrue(edgeFunction.contains("get_profile_snapshot"), "edge function must support get_profile_snapshot action")
assertTrue(edgeFunction.contains("INVALID_AGE_RANGE"), "edge function must validate age range")

assertTrue(userdefaultSetting.contains("ProfileSyncOutboxStore"), "app must define profile sync outbox store")
assertTrue(userdefaultSetting.contains("sync.profile.outbox.items.v1"), "profile sync outbox key must be fixed")
assertTrue(userdefaultSetting.contains("SupabaseProfileSyncTransport"), "app must define profile sync transport")
assertTrue(userdefaultSetting.contains("ProfileSyncCoordinator"), "app must define profile sync coordinator")
assertTrue(profileRepository.contains("protocol ProfileRepository"), "app must define profile repository protocol")
assertTrue(profileRepository.contains("DefaultProfileRepository"), "app must define default profile repository implementation")
assertTrue(profileRepository.contains("enqueueSnapshot"), "repository should enqueue profile sync")
assertTrue(profileRepository.contains("flushIfNeeded"), "repository should flush profile sync")

assertTrue(settingViewModel.contains("profileRepository.save"), "profile edit save should use profile repository")
assertTrue(signingViewModel.contains("profileRepository.save"), "signup save should use profile repository")

assertTrue(syncSpec.contains("#114"), "sync spec must reference issue #114")
assertTrue(syncSpec.contains("sync.profile.outbox.items.v1"), "sync spec must document outbox storage key")
assertTrue(schemaSpec.contains("profile_message"), "schema spec must include profile_message")
assertTrue(schemaSpec.contains("age_years"), "schema spec must include age_years")

print("PASS: userinfo supabase sync unit checks")
