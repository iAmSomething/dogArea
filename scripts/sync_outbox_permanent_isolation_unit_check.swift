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

let syncOutboxStore = load("dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift")
let behaviorScript = load("scripts/walk_sync_consistency_outbox_unit_check.swift")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(syncOutboxStore.contains("markPendingStagesPermanent("), "sync outbox store should isolate remaining stages after permanent failure")
assertTrue(syncOutboxStore.contains("if code == .notConfigured {\n                    continue\n                }"), "notConfigured permanent failure should continue draining queue")
assertTrue(syncOutboxStore.contains("markPendingStagesPermanent(\n                    walkSessionId: next.walkSessionId"), "permanent failure should quarantine same-session stages")
assertTrue(syncOutboxStore.contains("continue\n            }\n        }\n        return summary()"), "flush should continue after permanent failures instead of returning early")
assertTrue(syncOutboxStore.contains("private static func isPendingStatus"), "store should centralize pending-status filtering for permanent isolation")

assertTrue(behaviorScript.contains("permanent session failure should quarantine same-session stages and continue with next session"), "behavior model should cover permanent failure isolation")
assertTrue(behaviorScript.contains("permanentFailureCount == 3"), "behavior model should mark same-session remaining stages as permanent")

assertTrue(iosPRCheck.contains("sync_outbox_permanent_isolation_unit_check.swift"), "ios_pr_check should run outbox permanent isolation check")
assertTrue(iosPRCheck.contains("walk_sync_consistency_outbox_unit_check.swift"), "ios_pr_check should run outbox behavior model check")

print("PASS: sync outbox permanent isolation unit checks")
