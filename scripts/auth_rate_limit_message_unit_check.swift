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
let sourcePath = root.appendingPathComponent("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let source = String(decoding: try! Data(contentsOf: sourcePath), as: UTF8.self)

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
