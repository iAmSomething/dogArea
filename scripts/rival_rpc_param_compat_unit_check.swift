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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift"
])
let compatMigration = load("supabase/migrations/20260305224000_rival_rpc_postgrest_compat_fix.sql")
let hotfixMigration = load("supabase/migrations/20260305225500_rival_leaderboard_ambiguity_hotfix.sql")
let delegateMigration = load("supabase/migrations/20260305231000_rival_leaderboard_three_arg_delegate.sql")

assertTrue(
    infra.contains("\"payload\": [") &&
        infra.contains("\"period_type\"") &&
        infra.contains("\"top_n\"") &&
        infra.contains("\"now_ts\""),
    "rival leaderboard RPC payload should route through jsonb payload wrapper"
)
assertTrue(
    infra.contains("rpc_get_widget_quest_rival_summary") && infra.contains("\"in_now_ts\""),
    "quest/rival widget summary RPC payload should use in_now_ts"
)
assertTrue(
    compatMigration.contains("create or replace function public.rpc_get_rival_leaderboard(payload jsonb)") &&
        compatMigration.contains("from public.rival_league_assignments a"),
    "compat migration should define jsonb leaderboard function backed by rival_league_assignments"
)
assertTrue(
    compatMigration.contains("create or replace function public.rpc_get_widget_quest_rival_summary(\n  in_now_ts timestamptz default now()"),
    "compat migration should replace timestamptz widget summary function to avoid broken 3-arg leaderboard dependency"
)
assertTrue(
    compatMigration.contains("create or replace function public.rpc_get_widget_quest_rival_summary(payload jsonb)"),
    "compat migration should provide jsonb compatibility wrapper for quest/rival widget summary RPC"
)
assertTrue(
    hotfixMigration.contains("#variable_conflict use_column") &&
        hotfixMigration.contains("create or replace function public.rpc_get_rival_leaderboard("),
    "hotfix migration should recompile 3-arg rpc_get_rival_leaderboard with variable-conflict guard"
)
assertTrue(
    delegateMigration.contains("create or replace function public.rpc_get_rival_leaderboard(") &&
        delegateMigration.contains("from public.rpc_get_rival_leaderboard(") &&
        delegateMigration.contains("jsonb_build_object("),
    "delegate migration should route 3-arg leaderboard RPC to jsonb compatibility implementation"
)

print("PASS: rival rpc param compatibility unit checks")
