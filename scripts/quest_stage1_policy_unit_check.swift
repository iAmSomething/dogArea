import Foundation

/// 조건식을 검증하고 실패 시 오류 메시지를 출력한 뒤 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
/// - Returns: 반환값은 없으며 실패 시 프로세스를 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 지정한 상대 경로의 UTF-8 텍스트 파일 내용을 읽어 문자열로 반환합니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일의 UTF-8 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let policy = load("docs/quest-stage1-template-difficulty-policy-v1.md")
let report = load("docs/cycle-127-quest-stage1-policy-report-2026-03-01.md")

assertTrue(policy.contains("`new_tile`"), "Policy should define new_tile quest type")
assertTrue(policy.contains("`linked_path`"), "Policy should define linked_path quest type")
assertTrue(policy.contains("`walk_duration`"), "Policy should define walk_duration quest type")
assertTrue(policy.contains("`streak_days`"), "Policy should define streak_days quest type")

assertTrue(policy.contains("Easy"), "Policy should define Easy tier")
assertTrue(policy.contains("Normal"), "Policy should define Normal tier")
assertTrue(policy.contains("Hard"), "Policy should define Hard tier")

assertTrue(policy.contains("일일 퀘스트 3개"), "Policy should define daily generation count")
assertTrue(policy.contains("주간 퀘스트 2개"), "Policy should define weekly generation count")
assertTrue(policy.contains("최근 5개 일일 슬롯"), "Policy should define repeat limit window")
assertTrue(policy.contains("대체 퀘스트 슬롯"), "Policy should define alternative quest slot")
assertTrue(policy.contains("seed=20260301"), "Policy should provide reproducible seed examples")

assertTrue(report.contains("#127"), "Cycle report should reference issue #127")
assertTrue(report.contains("quest_stage1_policy_unit_check"), "Cycle report should include validation command")

print("PASS: quest stage1 policy unit checks")
