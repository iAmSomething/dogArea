import Foundation

@inline(__always)
/// Asserts that the given condition is true and terminates on failure.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to true.
///   - message: Failure reason printed to stderr when the assertion fails.
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

let source = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift"
])

assertTrue(
    source.contains("private func normalizedAuthRateLimitMessage("),
    "Supabase auth flow should provide a normalized 429 message helper"
)
assertTrue(
    source.contains("normalizedAuthRateLimitMessage(\n                    path: path,\n                    upstreamMessage: responseMessage,\n                    errorCode: responseErrorCode\n                )"),
    "429 branch should call normalizedAuthRateLimitMessage with path/message/errorCode"
)
assertTrue(
    source.contains("회원가입 요청이 너무 자주 발생해 일시적으로 제한되었습니다."),
    "signup-specific rate limit fallback message should exist"
)
assertTrue(
    source.contains("로그인 요청이 너무 자주 발생해 일시적으로 제한되었습니다."),
    "signin-specific rate limit fallback message should exist"
)

print("PASS: auth rate limit message unit checks")
