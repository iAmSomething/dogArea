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

let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(
    infra.contains("refresh retryable-failure: keep current access token"),
    "retryable refresh failure should keep current access token instead of anon fallback"
)
assertTrue(
    infra.contains("return current.accessToken"),
    "validAccessToken should return current access token on retryable refresh failure"
)
assertTrue(
    infra.contains("return .retryableFailure") && infra.contains("decode-failed"),
    "refresh decode failure should be classified as retryable"
)
assertTrue(
    infra.contains("func isTerminalRefreshFailure(statusCode: Int, data: Data) -> Bool"),
    "refresh flow should distinguish terminal refresh failures by payload"
)
assertTrue(
    infra.contains("func refreshFailureMessage(from data: Data) -> String"),
    "refresh flow should normalize failure payload before terminal decision"
)
assertTrue(
    infra.contains("if normalized.contains(\"invalid_grant\") { return true }"),
    "invalid_grant should remain terminal and clear session"
)

print("PASS: auth refresh resilience unit checks")
