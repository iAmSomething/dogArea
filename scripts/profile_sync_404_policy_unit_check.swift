import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 파일을 문자열로 읽습니다.
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

let syncServices = load("dogArea/Source/Infrastructure/Supabase/Services/SupabaseSyncServices.swift")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    syncServices.contains("case .notConfigured:\n                return .permanent(.notConfigured)"),
    "profile sync transport should classify notConfigured as permanent"
)
assertTrue(
    syncServices.contains("case 404:\n                    return .permanent(.notConfigured)"),
    "profile sync transport should classify HTTP 404 as permanent notConfigured"
)
assertTrue(
    syncServices.contains("case 400, 422:\n                    return .permanent(.schemaMismatch)"),
    "profile sync transport should keep schema mismatch as permanent"
)
assertTrue(
    backendPRCheck.contains("profile_sync_404_policy_unit_check.swift"),
    "backend_pr_check should run profile sync 404 policy check"
)
assertTrue(
    iosPRCheck.contains("profile_sync_404_policy_unit_check.swift"),
    "ios_pr_check should run profile sync 404 policy check"
)

print("PASS: profile sync 404 policy unit checks")
