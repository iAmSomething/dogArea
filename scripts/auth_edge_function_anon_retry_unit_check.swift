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
    infra.contains("private static let edgeFunctionAnonRetryAllowlist"),
    "http client should define allowlist for anon fallback retry"
)
assertTrue(
    infra.contains("\"feature-control\"")
        && infra.contains("\"nearby-presence\"")
        && infra.contains("\"upload-profile-image\""),
    "anon fallback allowlist should include feature-control, nearby-presence and upload-profile-image"
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
    infra.contains("(anon-retry)"),
    "http client should annotate successful anon retry responses"
)

print("PASS: auth edge function anon retry unit checks")
