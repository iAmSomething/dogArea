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

let outboxStore = load("dogArea/Source/ProfileSyncOutboxStore.swift")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    outboxStore.contains("case .permanent(let code):\n                updateItem(id: next.id) { item in"),
    "profile sync outbox should handle permanent failures explicitly"
)
assertTrue(
    outboxStore.contains("item.status = .permanentFailed"),
    "profile sync outbox should persist permanent failure state"
)
assertTrue(
    outboxStore.contains("item.lastErrorCode = code"),
    "profile sync outbox should persist permanent failure error code"
)
assertTrue(
    outboxStore.contains("item.updatedAt = currentNow"),
    "profile sync outbox should refresh timestamp when a permanent failure happens"
)
assertTrue(
    outboxStore.contains("continue\n            }\n        }\n        return summary()"),
    "profile sync outbox flush should continue draining queue after permanent failure"
)
assertTrue(
    backendPRCheck.contains("profile_sync_outbox_drain_unit_check.swift"),
    "backend_pr_check should run profile sync outbox drain check"
)
assertTrue(
    iosPRCheck.contains("profile_sync_outbox_drain_unit_check.swift"),
    "ios_pr_check should run profile sync outbox drain check"
)

print("PASS: profile sync outbox drain unit checks")
