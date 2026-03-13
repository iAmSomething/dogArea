import Foundation

@discardableResult
func require(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let migration = read("supabase/migrations/20260313214500_weather_feedback_null_adjustment_hotfix.sql")
let backendCheck = read("scripts/backend_pr_check.sh")
let iosCheck = read("scripts/ios_pr_check.sh")

require(migration.contains("rpc_submit_weather_feedback(payload jsonb)"), "hotfix migration should redefine rpc_submit_weather_feedback.")
require(migration.contains("current_adjustment_step := coalesce(current_adjustment_step, 0);"), "hotfix migration should normalize null adjustment_step after empty-day lookup.")
require(migration.contains("feedback_used_week >= policy_row.weekly_feedback_limit"), "hotfix migration should preserve weekly feedback limit branch.")
require(migration.contains("grant execute on function public.rpc_submit_weather_feedback(jsonb)"), "hotfix migration should keep execute grant.")

require(backendCheck.contains("weather_feedback_adjustment_step_hotfix_unit_check.swift"), "backend_pr_check should run weather feedback hotfix check.")
require(iosCheck.contains("weather_feedback_adjustment_step_hotfix_unit_check.swift"), "ios_pr_check should run weather feedback hotfix check.")

print("PASS: weather feedback adjustment-step hotfix unit checks")
