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
let allowlistSnippet = infra.range(of: "private static let edgeFunctionAnonRetryAllowlist").map {
    String(infra[$0.lowerBound...].prefix(180))
} ?? ""

assertTrue(
    infra.contains("private static let edgeFunctionAnonRetryAllowlist"),
    "http client should define allowlist for anon fallback retry"
)
assertTrue(
    infra.contains("\"feature-control\"")
        && infra.contains("\"nearby-presence\""),
    "anon fallback allowlist should include feature-control and nearby-presence"
)
assertTrue(
    !allowlistSnippet.contains("\"upload-profile-image\""),
    "upload-profile-image should not use anon-first or anon-retry routing because member owner binding must stay authoritative"
)
assertTrue(
    infra.contains("private func shouldRetryWithAnonAuthorization("),
    "http client should expose explicit anon retry guard"
)
assertTrue(
    infra.contains("[SupabaseHTTP] retry-anon"),
    "http client should log anon retry attempts in debug builds"
)
assertTrue(
    infra.contains("resolvedStatusCode = retryStatusCode")
        && infra.contains("resolvedData = retryData"),
    "anon retry non-2xx responses should become the final surfaced HTTP status/data"
)
assertTrue(
    infra.contains("auth-session decision status="),
    "http client should emit debug logs when auth-session invalidation uses a different status than the final anon retry response"
)
assertTrue(
    infra.contains("(anon-retry)"),
    "http client should annotate successful anon retry responses"
)

print("PASS: auth edge function anon retry unit checks")
