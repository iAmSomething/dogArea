import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let infraPath = root.appendingPathComponent("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let infra = String(decoding: try Data(contentsOf: infraPath), as: UTF8.self)

assertTrue(
    infra.contains("retryUnauthorizedRequestWithRefreshedSessionIfNeeded("),
    "http client should define unauthorized recovery helper"
)
assertTrue(
    infra.contains("if case .auth = endpoint"),
    "unauthorized recovery helper should skip auth endpoints and handle non-auth endpoints"
)
assertTrue(
    infra.contains("shouldPreferAnonymousAuthorizationForEndpoint(endpoint)"),
    "http client should select anon authorization first for edge-function allowlist endpoints"
)
assertTrue(
    infra.contains("let refreshOutcome = await refreshCredential(config: config, refreshToken: currentSession.refreshToken)"),
    "unauthorized recovery helper should refresh credential on 401/403"
)
assertTrue(
    infra.contains("retryRequest.setValue(\"Bearer \\(tokenSession.accessToken)\", forHTTPHeaderField: \"Authorization\")"),
    "unauthorized recovery helper should retry request with refreshed access token"
)
assertTrue(
    infra.contains("(refresh-retry)"),
    "http client should annotate successful refresh retry responses"
)
assertTrue(
    infra.contains("resolvedAccessToken = refreshedAccessToken ?? resolvedAccessToken"),
    "http client should propagate refreshed access token into session invalidation guard"
)

print("PASS: auth 401 refresh retry unit checks")
