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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let auth = load("dogArea/Source/ProfileRepository.swift")
let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let defaults = loadMany([
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

assertTrue(auth.contains("struct AuthTokenSession"), "auth store should define token session model")
assertTrue(auth.contains("persist(tokenSession:"), "auth session store should persist token sessions")
assertTrue(auth.contains("currentTokenSession()"), "auth session store should read token sessions")
assertTrue(auth.contains("clearTokenSession()"), "auth session store should clear only token sessions")
assertTrue(auth.contains("AuthCredentialResult"), "auth layer should return credential result containing session")
assertTrue(auth.contains("sessionStore.persist(tokenSession:"), "auth use case should store token session on login")

assertTrue(
    infra.contains("resolvedAuthorizationHeader"),
    "supabase http client should resolve authorization header context from session"
)
assertTrue(infra.contains("grant_type=refresh_token"), "supabase http client should refresh expired access tokens")
assertTrue(infra.contains("SupabaseRefreshTokenRequestDTO"), "supabase http client should send refresh token payload")
assertTrue(infra.contains("authSessionStore.persist(tokenSession:"), "refresh flow should persist rotated token session")
assertTrue(infra.contains(".syncAuthRefreshSucceeded"), "refresh flow should track syncAuthRefreshSucceeded metric")
assertTrue(infra.contains(".syncAuthRefreshFailed"), "refresh flow should track syncAuthRefreshFailed metric")
assertTrue(defaults.contains("case syncAuthRefreshSucceeded = \"sync_auth_refresh_succeeded\""), "metric enum should define sync_auth_refresh_succeeded")
assertTrue(defaults.contains("case syncAuthRefreshFailed = \"sync_auth_refresh_failed\""), "metric enum should define sync_auth_refresh_failed")

print("PASS: auth session autologin unit checks")
