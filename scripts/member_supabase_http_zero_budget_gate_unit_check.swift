import Foundation

/// 조건이 거짓이면 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let harnessLib = load("scripts/lib/supabase_integration_harness.sh")
let smokeRunner = load("scripts/run_supabase_smoke_matrix.sh")
let zeroBudgetDoc = load("docs/member-supabase-http-5xx-zero-budget-gate-v1.md")
let fastSmokeDoc = load("docs/pr-fast-smoke-gate-v1.md")
let nightlyDoc = load("docs/nightly-full-regression-gate-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(harnessLib.contains("HARNESS_MEMBER_REFRESH_TOKEN"), "harness should persist member refresh token")
assertTrue(harnessLib.contains("harness_expect_status_in"), "harness should expose multi-status allowlist helper")
assertTrue(harnessLib.contains("class=server_5xx"), "harness should label server 5xx failures explicitly")
assertTrue(harnessLib.contains("request_id=") || harnessLib.contains("requestId"), "harness should extract request id diagnostics")
assertTrue(harnessLib.contains("error_code="), "harness should extract error code diagnostics")
assertTrue(harnessLib.contains("key.isdigit()"), "harness json field helper should support array path access")

assertTrue(smokeRunner.contains("harness_expect_status_in \"auth.resend.signup.member_fixture\" \"200,429\""), "smoke runner should allowlist resend cooldown statuses")
assertTrue(smokeRunner.contains("harness_expect_status_in \"auth.recover.member_fixture\" \"200,429\""), "smoke runner should allowlist recover cooldown statuses")
assertTrue(smokeRunner.contains("upload-profile-image.member_owner_mismatch"), "smoke runner should keep explicit 403 mismatch case")
assertTrue(smokeRunner.contains("caricature.invalid_request.member"), "smoke runner should probe caricature route without allowing 5xx")

assertTrue(zeroBudgetDoc.contains("5xx"), "zero-budget doc should define 5xx policy")
assertTrue(zeroBudgetDoc.contains("class=server_5xx"), "zero-budget doc should mention explicit 5xx label")
assertTrue(zeroBudgetDoc.contains("backend_pr_check.sh"), "zero-budget doc should wire backend check entrypoint")
assertTrue(zeroBudgetDoc.contains("pr-fast-smoke-gate-v1.md"), "zero-budget doc should mention fast smoke linkage")
assertTrue(zeroBudgetDoc.contains("nightly-full-regression-gate-v1.md"), "zero-budget doc should mention nightly linkage")

assertTrue(fastSmokeDoc.contains("member full sweep"), "fast smoke doc should mention member full sweep")
assertTrue(fastSmokeDoc.contains("5xx zero-budget"), "fast smoke doc should mention zero-budget rule")
assertTrue(nightlyDoc.contains("member full sweep"), "nightly doc should mention member full sweep")
assertTrue(nightlyDoc.contains("5xx zero-budget"), "nightly doc should mention zero-budget rule")
assertTrue(backendCheck.contains("member_supabase_http_zero_budget_gate_unit_check.swift"), "backend_pr_check should include zero-budget unit check")
assertTrue(iosCheck.contains("member_supabase_http_zero_budget_gate_unit_check.swift"), "ios_pr_check should include zero-budget unit check")

print("PASS: member supabase http zero-budget gate unit checks")
