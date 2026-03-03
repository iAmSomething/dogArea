import Foundation

/// 조건식을 검증하고 실패 시 오류 메시지를 출력한 뒤 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 검증 실패 시 출력할 메시지입니다.
/// - Returns: 반환값은 없으며 실패 시 프로세스를 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 파일을 UTF-8 문자열로 읽어옵니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 디코딩된 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let migration = load("supabase/migrations/20260303120000_quest_stage2_progress_claim_engine.sql")
let syncWalk = load("supabase/functions/sync-walk/index.ts")
let questEngine = load("supabase/functions/quest-engine/index.ts")
let doc = load("docs/quest-stage2-progress-claim-engine-v1.md")
let report = load("docs/cycle-205-quest-stage2-engine-report-2026-03-03.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.quest_templates"), "migration should create quest_templates table")
assertTrue(migration.contains("create table if not exists public.quest_instances"), "migration should create quest_instances table")
assertTrue(migration.contains("create table if not exists public.quest_progress"), "migration should create quest_progress table")
assertTrue(migration.contains("create table if not exists public.quest_claims"), "migration should create quest_claims table")

assertTrue(migration.contains("create or replace function public.rpc_issue_quest_instances"), "migration should provide quest issue rpc")
assertTrue(migration.contains("create or replace function public.rpc_apply_quest_progress_event"), "migration should provide quest progress rpc")
assertTrue(migration.contains("create or replace function public.rpc_claim_quest_reward"), "migration should provide quest claim rpc")
assertTrue(migration.contains("create or replace function public.rpc_transition_quest_status"), "migration should provide quest transition rpc")

assertTrue(migration.contains("unique (quest_instance_id, event_id)"), "migration should enforce quest progress idempotency key")
assertTrue(migration.contains("unique (quest_instance_id)"), "migration should enforce single claim per quest instance")
assertTrue(migration.contains("duplicate_claim_blocked"), "migration should record duplicate claim blocked audit action")
assertTrue(migration.contains("reroll_transition"), "migration should record reroll transition audit action")

assertTrue(syncWalk.contains("rpc_apply_quest_progress_event"), "sync-walk should push quest progress events")
assertTrue(syncWalk.contains("quest_progress_summary"), "sync-walk response should expose quest progress summary")

assertTrue(questEngine.contains("issue_quests"), "quest engine should expose issue action")
assertTrue(questEngine.contains("ingest_walk_event"), "quest engine should expose ingest action")
assertTrue(questEngine.contains("claim_reward"), "quest engine should expose claim action")
assertTrue(questEngine.contains("transition_status"), "quest engine should expose transition action")
assertTrue(questEngine.contains("rpc_claim_quest_reward"), "quest engine should call claim rpc")

assertTrue(doc.contains("멱등"), "quest stage2 doc should describe idempotent progress processing")
assertTrue(doc.contains("중복 클레임"), "quest stage2 doc should describe duplicate claim prevention")
assertTrue(doc.contains("reroll 1일 1회"), "quest stage2 doc should describe reroll daily limit")

assertTrue(report.contains("#128"), "cycle report should reference issue #128")
assertTrue(report.contains("quest_stage2_engine_unit_check"), "cycle report should include stage2 unit check command")
assertTrue(readme.contains("docs/quest-stage2-progress-claim-engine-v1.md"), "README should reference stage2 quest engine doc")

print("PASS: quest stage2 engine unit checks")
