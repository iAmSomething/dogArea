import Foundation

/// Validates that a condition required by the geo fixture lifecycle documentation is satisfied.
/// - Parameters:
///   - condition: Boolean expression describing the invariant that must hold.
///   - message: Failure description printed before terminating the script.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("backend_geo_fixture_lifecycle_unit_check failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Loads a UTF-8 text file from the repository root.
/// - Parameters:
///   - path: Relative repository path to load.
/// - Returns: Full file contents as a string.
func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

let doc = load("docs/backend-geo-test-fixture-lifecycle-v1.md")
let readme = load("README.md")
let smokeMatrix = load("docs/supabase-integration-smoke-matrix-v1.md")
let rollbackRunbook = load("docs/backend-deploy-rollback-roll-forward-runbook-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let harness = load("scripts/lib/supabase_integration_harness.sh")
let config = load("supabase/config.toml")
let activeVariant = load("supabase/migrations/20260303173000_seed_geo_test_additional_variants.sql")
let recenterMigration = load("supabase/migrations/20260303185000_recenter_geo_test_points_to_yeonsu1dong.sql")
let placeholderMigrations = [
    "supabase/migrations/20260226181500_seed_test_walk_data.sql",
    "supabase/migrations/20260226182500_seed_geo_2km_test_data.sql",
    "supabase/migrations/20260226183500_rename_geo_test_user_and_pet_names.sql",
    "supabase/migrations/20260226184500_reduce_geo_test_to_one_pet_per_user.sql",
    "supabase/migrations/20260226190000_regenerate_geo_walk_patterns.sql",
    "supabase/migrations/20260226191500_set_geo_test_profile_photos.sql",
    "supabase/migrations/20260226192500_set_geo_test_pet_photos.sql",
].map(load)
let backendCheck = load("scripts/backend_pr_check.sh")
let iosCheck = load("scripts/ios_pr_check.sh")

let requiredDocTokens = [
    "integration_smoke_fixture",
    "qa_geo_fixture",
    "historical_migration_anchor",
    "DOGAREA_TEST_EMAIL",
    "dogarea.test.geo%@dogarea.test",
    "seed://dogarea/geo2km/v4/",
    "npx --yes supabase db reset",
    "npx --yes supabase migration list --linked",
    "recenter",
    "regenerate",
    "연수1동",
    "하늘산책가",
    "별빛산책가",
    "노을산책가",
    "새벽산책가",
    "바람산책가",
]

for token in requiredDocTokens {
    assertTrue(doc.contains(token), "doc missing token: \(token)")
}

assertTrue(readme.contains("docs/backend-geo-test-fixture-lifecycle-v1.md"), "README missing geo fixture doc link")
assertTrue(smokeMatrix.contains("docs/backend-geo-test-fixture-lifecycle-v1.md"), "smoke matrix missing geo fixture doc link")
assertTrue(rollbackRunbook.contains("docs/backend-geo-test-fixture-lifecycle-v1.md"), "rollback runbook missing geo fixture doc link")
assertTrue(migrationDoc.contains("docs/backend-geo-test-fixture-lifecycle-v1.md"), "migration doc missing geo fixture doc link")

assertTrue(harness.contains("DOGAREA_TEST_EMAIL"), "integration harness missing DOGAREA_TEST_EMAIL")
assertTrue(harness.contains("DOGAREA_TEST_PASSWORD"), "integration harness missing DOGAREA_TEST_PASSWORD")
assertTrue(config.contains("[db.seed]"), "config missing [db.seed]")
assertTrue(config.contains("sql_paths = [\"./seed.sql\"]"), "config missing seed sql path")

assertTrue(activeVariant.contains("seed://dogarea/geo2km/v4/"), "active variant migration missing v4 seed namespace")
assertTrue(activeVariant.contains("하늘산책가"), "active variant migration missing fixture name")
assertTrue(activeVariant.contains("별빛산책가"), "active variant migration missing fixture name")
assertTrue(activeVariant.contains("노을산책가"), "active variant migration missing fixture name")
assertTrue(activeVariant.contains("새벽산책가"), "active variant migration missing fixture name")
assertTrue(activeVariant.contains("바람산책가"), "active variant migration missing fixture name")
assertTrue(activeVariant.contains("source_device"), "active variant migration missing source_device")
assertTrue(activeVariant.contains("caricature_url"), "active variant migration missing caricature_url")

assertTrue(recenterMigration.contains("dogarea.test.geo%@dogarea.test"), "recenter migration missing geo fixture namespace")
assertTrue(recenterMigration.contains("Yeonsu 1-dong"), "recenter migration missing Yeonsu 1-dong marker")

for placeholder in placeholderMigrations {
    assertTrue(placeholder.contains("Historical placeholder."), "placeholder migration lost historical placeholder marker")
}

assertTrue(backendCheck.contains("swift scripts/backend_geo_fixture_lifecycle_unit_check.swift"), "backend_pr_check missing geo fixture lifecycle check")
assertTrue(iosCheck.contains("swift scripts/backend_geo_fixture_lifecycle_unit_check.swift"), "ios_pr_check missing geo fixture lifecycle check")

print("backend_geo_fixture_lifecycle_unit_check passed")
