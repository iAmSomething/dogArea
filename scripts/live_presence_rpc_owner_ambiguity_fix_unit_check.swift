import Foundation

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let firstFixURL = root.appendingPathComponent("supabase/migrations/20260310191000_walk_live_presence_rpc_owner_ambiguity_fix.sql")
let secondFixURL = root.appendingPathComponent("supabase/migrations/20260310194500_walk_live_presence_rpc_owner_conflict_target_fix.sql")
let firstFix = try String(contentsOf: firstFixURL, encoding: .utf8)
let migration = try String(contentsOf: secondFixURL, encoding: .utf8)

assertTrue(firstFix.contains("on conflict (owner_user_id) do update"), "first fix migration should preserve the already-applied intermediate state")
assertTrue(migration.contains("-- #694 #695 fix ambiguous owner_user_id references inside rpc_upsert_walk_live_presence"), "second fix migration should retain remediation context header")
assertTrue(migration.contains("state_snapshot.owner_user_id = in_owner_user_id"), "new migration should qualify abuse state owner_user_id reference")
assertTrue(migration.contains("persisted_presence.owner_user_id = in_owner_user_id"), "new migration should qualify walk_live_presence owner_user_id reference")
assertTrue(migration.contains("grant execute on function public.rpc_upsert_walk_live_presence("), "new migration should preserve execute grant")
assertTrue(migration.contains("in_device_key text default null"), "new migration should preserve device key parameter")
assertTrue(migration.contains("returns table ("), "new migration should keep RPC return contract")
assertTrue(migration.contains("delete from public.walk_live_presence persisted_presence"), "new migration should alias delete target to avoid ambiguity")
assertTrue(migration.contains("from public.live_presence_abuse_states state_snapshot"), "new migration should alias abuse state source")
assertTrue(migration.contains("from public.walk_live_presence persisted_presence"), "new migration should alias persisted presence reads")
assertTrue(migration.contains("on conflict on constraint live_presence_abuse_states_pkey"), "abuse state upsert should avoid bare owner_user_id conflict target")
assertTrue(migration.contains("on conflict on constraint walk_live_presence_pkey"), "walk_live_presence upsert should avoid bare owner_user_id conflict target")
assertTrue(migration.contains("where state_snapshot.owner_user_id = in_owner_user_id"), "abuse state lookup should use qualified owner_user_id")
assertTrue(migration.contains("where persisted_presence.owner_user_id = in_owner_user_id"), "persisted presence lookup should use qualified owner_user_id")
assertTrue(migration.contains("where owner_user_id = in_owner_user_id") == false, "new migration should not leave unqualified owner_user_id filters")

print("PASS: live presence rpc owner ambiguity fix unit checks")
