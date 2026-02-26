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

let migration = load("supabase/migrations/20260227013000_area_references_catalog_seed_upgrade.sql")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")

assertTrue(
    migration.contains("create table if not exists public.area_reference_catalogs"),
    "migration should create area_reference_catalogs table"
)
assertTrue(
    migration.contains("add column if not exists catalog_id uuid"),
    "migration should extend area_references with catalog_id"
)
assertTrue(
    migration.contains("add column if not exists display_order integer"),
    "migration should extend area_references with display_order"
)
assertTrue(
    migration.contains("add column if not exists is_featured boolean"),
    "migration should extend area_references with is_featured"
)
assertTrue(
    migration.contains("area_references_catalog_id_fkey"),
    "migration should enforce catalog foreign key"
)
assertTrue(
    migration.contains("idx_area_references_reference_name_unique"),
    "migration should enforce unique reference_name index for deterministic upsert"
)
assertTrue(
    migration.contains("on conflict (reference_name)"),
    "migration should upsert area reference seeds by reference_name"
)
assertTrue(
    migration.contains("seed_version"),
    "migration should stamp metadata seed_version"
)

assertTrue(
    schemaDoc.contains("AREA_REFERENCE_CATALOGS"),
    "schema doc should include area reference catalogs entity"
)
assertTrue(
    schemaDoc.contains("display_order"),
    "schema doc should document display_order"
)
assertTrue(
    schemaDoc.contains("is_featured"),
    "schema doc should document is_featured"
)
assertTrue(
    migrationDoc.contains("5.6 비교군 카탈로그/시드 정합성 확인"),
    "migration ops doc should include area reference catalog validation SQL"
)

print("PASS: area reference catalog seed unit checks")
