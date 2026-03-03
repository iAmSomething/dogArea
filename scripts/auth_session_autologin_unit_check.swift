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

let auth = load("dogArea/Source/ProfileRepository.swift")
let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(auth.contains("struct AuthTokenSession"), "auth store should define token session model")
assertTrue(auth.contains("persist(tokenSession:"), "auth session store should persist token sessions")
assertTrue(auth.contains("currentTokenSession()"), "auth session store should read token sessions")
assertTrue(auth.contains("clearTokenSession()"), "auth session store should clear only token sessions")
assertTrue(auth.contains("AuthCredentialResult"), "auth layer should return credential result containing session")
assertTrue(auth.contains("sessionStore.persist(tokenSession:"), "auth use case should store token session on login")

assertTrue(infra.contains("authorizationHeaderValue"), "supabase http client should resolve authorization header from session")
assertTrue(infra.contains("grant_type=refresh_token"), "supabase http client should refresh expired access tokens")
assertTrue(infra.contains("SupabaseRefreshTokenRequestDTO"), "supabase http client should send refresh token payload")
assertTrue(infra.contains("authSessionStore.persist(tokenSession:"), "refresh flow should persist rotated token session")

print("PASS: auth session autologin unit checks")
