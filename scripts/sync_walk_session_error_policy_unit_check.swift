import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 내 텍스트 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter path: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to load \(path)\n", stderr)
        exit(1)
    }
    return contents
}

/// 조건식이 거짓이면 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let sessionStage = load("supabase/functions/sync-walk/handlers/session_stage.ts")
let sessionPolicy = load("supabase/functions/sync-walk/support/session_error_policy.ts")
let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let outboxDoc = load("docs/walk-sync-consistency-outbox-v1.md")
let backfillDoc = load("docs/coredata-supabase-backfill.md")
let policyDoc = load("docs/sync-walk-session-stage-error-policy-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(sessionStage.contains("validateSessionStagePayload"), "session stage should validate payload before DB upsert")
assertTrue(sessionStage.contains("classifySessionStageDatabaseFailure"), "session stage should classify DB failures")
assertTrue(sessionStage.contains("postgres_code"), "session stage log metadata should include postgres code")

for requiredCode in [
    "PET_ID_REQUIRED",
    "SESSION_INVALID_PET_REFERENCE",
    "SESSION_TIME_RANGE_INVALID",
    "SESSION_OWNERSHIP_CONFLICT",
    "SESSION_CONFLICT",
    "SESSION_TRANSIENT_DB_FAILURE",
    "SESSION_UNKNOWN_DB_FAILURE"
] {
    assertTrue(sessionPolicy.contains(requiredCode), "session policy should define \(requiredCode)")
}

assertTrue(sessionPolicy.contains("status: 422"), "session policy should use 422 for permanent payload/schema failures")
assertTrue(sessionPolicy.contains("status: 409"), "session policy should use 409 for ownership/conflict failures")
assertTrue(sessionPolicy.contains("status: 503"), "session policy should use 503 for transient DB failures")
assertTrue(sessionPolicy.contains("version: \"2026-03-11.v1\""), "session policy should stamp response version")

assertTrue(syncServices.contains("case 409:"), "sync transport should branch on 409")
assertTrue(syncServices.contains("return .permanent(.conflict)"), "sync transport should treat 409 as permanent conflict")
assertTrue(syncServices.contains("case 400, 422:"), "sync transport should branch on 422")
assertTrue(syncServices.contains("return .permanent(.schemaMismatch)"), "sync transport should treat 422 as permanent schema mismatch")

assertTrue(outboxDoc.contains("permanent"), "outbox doc should describe permanent failure handling")
assertTrue(outboxDoc.contains("같은 세션의 후속 stage도 함께 `permanentFailed`"), "outbox doc should document same-session stage quarantine")
assertTrue(backfillDoc.contains("`422`"), "backfill doc should document 422 permanent classification")
assertTrue(backfillDoc.contains("`409`"), "backfill doc should document 409 permanent classification")

assertTrue(policyDoc.contains("investigate-missing-pet"), "policy doc should preserve missing pet reproduction evidence")
assertTrue(policyDoc.contains("investigate-invalid-pet"), "policy doc should preserve invalid pet reproduction evidence")
assertTrue(policyDoc.contains("investigate-reverse-time-valid-pet"), "policy doc should preserve reverse time reproduction evidence")
assertTrue(policyDoc.contains("#686"), "policy doc should reference issue #686")
assertTrue(policyDoc.contains("#687"), "policy doc should reference issue #687")

assertTrue(backendCheck.contains("sync_walk_session_error_policy_unit_check.swift"), "backend_pr_check should run session error policy check")
assertTrue(iosPRCheck.contains("sync_walk_session_error_policy_unit_check.swift"), "ios_pr_check should run session error policy check")

print("PASS: sync-walk session error policy unit checks")
