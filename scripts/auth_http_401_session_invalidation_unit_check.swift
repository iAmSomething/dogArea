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

let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(
    infra.contains("let authorization = await resolvedAuthorizationHeader(config: config)"),
    "http client should resolve authorization context before request"
)
assertTrue(
    infra.contains("usedAuthenticatedAccessToken: authorization.usedAuthenticatedAccessToken"),
    "http client should pass authenticated-token context to invalidation guard"
)
assertTrue(
    infra.contains("private func shouldInvalidateTokenSession("),
    "http client should define token session invalidation guard"
)
assertTrue(
    infra.contains("if case .auth = endpoint"),
    "invalidation guard should treat auth endpoint failures as immediate invalidation"
)
assertTrue(
    infra.contains("validateAccessTokenRemotely(accessToken: accessToken, config: config)"),
    "invalidation guard should validate token remotely before clearing local session"
)
assertTrue(
    infra.contains("preserve local token session: remote auth user check is still valid"),
    "invalidation guard should preserve token session when auth probe confirms validity"
)
assertTrue(
    infra.contains("skip local token invalidation: remote auth user check inconclusive"),
    "invalidation guard should avoid forced logout when auth probe is inconclusive"
)
assertTrue(
    infra.contains("private func validateAccessTokenRemotely("),
    "http client should expose remote token validation helper"
)
assertTrue(
    infra.contains("invalidate local token session from response status="),
    "http client should emit debug log when session is invalidated from 401/403"
)

print("PASS: auth http 401 session invalidation unit checks")
