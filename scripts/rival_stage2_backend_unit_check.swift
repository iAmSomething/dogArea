import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let migration = load("supabase/migrations/20260301153000_rival_stage2_leaderboard_backend.sql")
let edgeFunction = load("supabase/functions/rival-league/index.ts")
let doc = load("docs/rival-stage2-backend-v1.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.rival_alias_profiles"), "migration should create rival alias table")
assertTrue(migration.contains("create table if not exists public.rival_abuse_audit_logs"), "migration should create rival abuse audit table")
assertTrue(migration.contains("create or replace function public.rpc_get_rival_leaderboard"), "migration should provide rival leaderboard rpc")
assertTrue(migration.contains("create or replace function public.rpc_export_my_rival_data"), "migration should provide export route")
assertTrue(migration.contains("create or replace function public.rpc_delete_my_rival_data"), "migration should provide delete route")
assertTrue(migration.contains("blocked_by_season_audit"), "migration should record abuse filter reason")
assertTrue(migration.contains("rival_score_bucket"), "migration should hide exact score with bucket")

assertTrue(edgeFunction.contains("get_leaderboard"), "edge function should expose leaderboard action")
assertTrue(edgeFunction.contains("export_my_data"), "edge function should expose export action")
assertTrue(edgeFunction.contains("delete_my_data"), "edge function should expose delete action")
assertTrue(edgeFunction.contains("rpc_get_rival_leaderboard"), "edge function should call rival leaderboard rpc")

assertTrue(doc.contains("일/주/시즌"), "stage2 doc should define daily/weekly/season leaderboard")
assertTrue(doc.contains("구간 점수"), "stage2 doc should mention score bucket policy")
assertTrue(doc.contains("내보내기"), "stage2 doc should include export route")
assertTrue(doc.contains("삭제"), "stage2 doc should include delete route")
assertTrue(readme.contains("docs/rival-stage2-backend-v1.md"), "README should reference stage2 backend doc")

print("PASS: rival stage2 backend unit checks")
