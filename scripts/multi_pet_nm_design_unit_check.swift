import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let docPath = root.appendingPathComponent("docs/multi-pet-session-nm-v2.md")
let doc = String(decoding: try! Data(contentsOf: docPath), as: UTF8.self)
let migrationPath = root.appendingPathComponent("supabase/migrations/20260226214000_walk_session_pets_nm_phase2_draft.sql")
let migration = String(decoding: try! Data(contentsOf: migrationPath), as: UTF8.self)

assertTrue(doc.contains("## 3. N:M 도메인 규칙"), "doc should define N:M domain rules")
assertTrue(doc.contains("primary pet"), "doc should define primary pet contract")
assertTrue(doc.contains("## 4. 저장/조회 API 스펙"), "doc should include API contract section")
assertTrue(doc.contains("all 모드"), "doc should define all-mode dedupe behavior")
assertTrue(doc.contains("## 6. 활성화/마이그레이션 전략"), "doc should include migration strategy section")
assertTrue(doc.contains("## 8. 2차 구현 이슈 분해 (초안)"), "doc should include implementation issue decomposition")
assertTrue(doc.contains("## 9. 구현 착수 조건"), "doc should include implementation readiness checklist")

assertTrue(migration.contains("create table public.walk_session_pets"), "migration should ensure walk_session_pets table")
assertTrue(migration.contains("on conflict (walk_session_id, pet_id)"), "migration should include idempotent backfill")
assertTrue(migration.contains("v_walk_session_pets_backfill_check"), "migration should provide backfill validation view")

print("PASS: multi-pet N:M design unit checks")
