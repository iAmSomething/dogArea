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

let migration = read("supabase/migrations/20260313222000_indoor_mission_claim_ambiguity_hotfix.sql")
let backendCheck = read("scripts/backend_pr_check.sh")
let iosCheck = read("scripts/ios_pr_check.sh")

require(migration.contains("rpc_claim_indoor_mission_reward(payload jsonb)"), "hotfix migration should redefine indoor mission claim RPC.")
require(migration.contains("#variable_conflict use_column"), "hotfix migration should opt into use_column ambiguity resolution.")
require(migration.contains("on conflict (mission_instance_id) do nothing"), "hotfix migration should preserve mission claim idempotency conflict target.")
require(migration.contains("grant execute on function public.rpc_claim_indoor_mission_reward(jsonb)"), "hotfix migration should keep execute grant.")

require(backendCheck.contains("indoor_mission_claim_ambiguity_hotfix_unit_check.swift"), "backend_pr_check should run indoor claim ambiguity hotfix check.")
require(iosCheck.contains("indoor_mission_claim_ambiguity_hotfix_unit_check.swift"), "ios_pr_check should run indoor claim ambiguity hotfix check.")

print("PASS: indoor mission claim ambiguity hotfix unit checks")
