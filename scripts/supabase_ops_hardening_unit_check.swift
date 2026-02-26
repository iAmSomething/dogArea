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

let migration = load("supabase/migrations/20260226230000_supabase_schema_ops_hardening.sql")
let opsDoc = load("docs/supabase-migration.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.profiles"), "migration should define profiles table")
assertTrue(migration.contains("create table if not exists public.pets"), "migration should define pets table")
assertTrue(migration.contains("create table if not exists public.walk_sessions"), "migration should define walk_sessions table")
assertTrue(migration.contains("create table if not exists public.walk_points"), "migration should define walk_points table")
assertTrue(migration.contains("create table if not exists public.area_milestones"), "migration should define area_milestones table")
assertTrue(migration.contains("create table if not exists public.walk_session_pets"), "migration should define walk_session_pets table")
assertTrue(migration.contains("create policy walk_points_owner_all"), "migration should include owner policy for walk_points")
assertTrue(migration.contains("create policy walk_session_pets_owner_all"), "migration should include owner policy for walk_session_pets")
assertTrue(migration.contains("create policy storage_profiles_insert_own"), "migration should include storage profile policy")
assertTrue(migration.contains("create policy storage_caricatures_insert_own"), "migration should include storage caricatures policy")
assertTrue(migration.contains("create policy storage_walk_maps_insert_own"), "migration should include storage walk maps policy")
assertTrue(migration.contains("create or replace view public.view_owner_walk_stats"), "migration should expose owner stats view")

assertTrue(opsDoc.contains("## 2. Migration 상태 동기화"), "ops doc should include migration sync section")
assertTrue(opsDoc.contains("npx --yes supabase migration list --linked"), "ops doc should include linked migration command")
assertTrue(opsDoc.contains("## 3. RLS 교차 계정 차단 검증 SQL"), "ops doc should include cross-account RLS checks")
assertTrue(opsDoc.contains("## 4. Storage 정책 검증"), "ops doc should include storage policy checks")
assertTrue(opsDoc.contains("## 5. 운영 검증 SQL (핵심 통계)"), "ops doc should include operational SQL")
assertTrue(opsDoc.contains("view_owner_walk_stats"), "ops doc should reference owner stats view")

assertTrue(readme.contains("docs/supabase-migration.md"), "README should include supabase migration ops doc link")

print("PASS: supabase ops hardening unit checks")
