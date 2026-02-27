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

let migration = load("supabase/migrations/20260227192000_rival_privacy_hard_guard.sql")
let nearbyFunction = load("supabase/functions/nearby-presence/index.ts")
let doc = load("docs/rival-privacy-hard-guard-v1.md")
let nearbyDoc = load("docs/nearby-anonymous-hotspot-v1.md")
let readme = load("README.md")

assertTrue(migration.contains("create table if not exists public.privacy_guard_policies"), "migration should create privacy_guard_policies")
assertTrue(migration.contains("create table if not exists public.privacy_sensitive_geo_masks"), "migration should create privacy_sensitive_geo_masks")
assertTrue(migration.contains("create table if not exists public.privacy_guard_audit_logs"), "migration should create privacy_guard_audit_logs")
assertTrue(migration.contains("create or replace function public.rpc_get_nearby_hotspots"), "migration should replace hotspot rpc with privacy guard")
assertTrue(migration.contains("suppression_reason text"), "migration rpc should expose suppression reason")
assertTrue(migration.contains("daytime_delay_minutes"), "migration should include daytime delay policy")
assertTrue(migration.contains("nighttime_delay_minutes"), "migration should include nighttime delay policy")
assertTrue(migration.contains("percentile_fallback"), "migration should include percentile fallback policy")
assertTrue(migration.contains("view_privacy_guard_alerts_24h"), "migration should expose privacy alert monitoring view")

assertTrue(nearbyFunction.contains("privacy_guard_audit_logs"), "nearby edge function should write privacy audit logs")
assertTrue(nearbyFunction.contains("suppression_reason"), "nearby edge function should parse suppression metadata")
assertTrue(nearbyFunction.contains("alert_level"), "nearby edge function should compute alert level")

assertTrue(doc.contains("k >= 20"), "privacy guard doc should define minimum sample")
assertTrue(doc.contains("주간 30분"), "privacy guard doc should define daytime delay")
assertTrue(doc.contains("야간 60분"), "privacy guard doc should define nighttime delay")
assertTrue(doc.contains("privacy_guard_audit_logs"), "privacy guard doc should include audit log table")

assertTrue(nearbyDoc.contains("표본 미달"), "nearby doc should include sparse sample guard wording")
assertTrue(nearbyDoc.contains("k>=20"), "nearby doc should include k-anon threshold")
assertTrue(readme.contains("docs/rival-privacy-hard-guard-v1.md"), "README should reference privacy hard guard doc")

print("PASS: rival privacy hard guard unit checks")
