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

let opsDoc = load("docs/realtime-ops-rollout-killswitch-v1.md")
let templateDoc = load("docs/realtime-ops-weekly-report-template-v1.md")
let workflow = load(".github/workflows/realtime-ops-gate.yml")
let gateScript = load("scripts/realtime_ops_rollout_gate.swift")
let prCheck = load("scripts/ios_pr_check.sh")
let releaseChecklist = load("docs/release-regression-checklist-v1.md")

assertTrue(opsDoc.contains("active_sessions_5m"), "ops doc should define active sessions KPI")
assertTrue(opsDoc.contains("stale_ratio_5m"), "ops doc should define stale ratio KPI")
assertTrue(opsDoc.contains("p95_latency_ms"), "ops doc should define p95 latency KPI")
assertTrue(opsDoc.contains("error_rate_5m"), "ops doc should define error rate KPI")
assertTrue(opsDoc.contains("battery_impact_percent_per_hour"), "ops doc should define battery impact KPI")
assertTrue(opsDoc.contains("internal") && opsDoc.contains("10%") && opsDoc.contains("50%") && opsDoc.contains("100%"), "ops doc should define staged rollout percentages")
assertTrue(opsDoc.contains("ff_nearby_hotspot_v1=false"), "ops doc should define client kill switch")
assertTrue(opsDoc.contains("NEARBY_PRESENCE_ENABLED=false"), "ops doc should define server kill switch")
assertTrue(opsDoc.contains("docs/realtime-ops-weekly-report-template-v1.md"), "ops doc should link weekly report template")

assertTrue(templateDoc.contains("KPI 요약"), "weekly template should include KPI summary section")
assertTrue(templateDoc.contains("Alert/Incident"), "weekly template should include alert incident section")
assertTrue(templateDoc.contains("Kill Switch"), "weekly template should include kill switch section")
assertTrue(releaseChecklist.contains("realtime-ops-gate"), "release checklist should reference realtime ops gate workflow")
assertTrue(releaseChecklist.contains("scripts/realtime_ops_rollout_gate.swift --input <kpi-json>"), "release checklist should include realtime gate script command")

assertTrue(workflow.contains("name: realtime-ops-gate"), "workflow should define realtime ops gate workflow")
assertTrue(workflow.contains("metrics_file"), "workflow should expose metrics_file input for dispatch")
assertTrue(workflow.contains("swift scripts/realtime_ops_rollout_unit_check.swift"), "workflow should run realtime ops unit check")
assertTrue(workflow.contains("swift scripts/realtime_ops_rollout_gate.swift --input"), "workflow should run realtime ops gate script")

assertTrue(gateScript.contains("minimumActiveSessions(for:") , "gate script should define stage-based active session threshold")
assertTrue(gateScript.contains("input.staleRatio >= 0.12"), "gate script should enforce stale ratio threshold")
assertTrue(gateScript.contains("input.p95LatencyMs >= 350"), "gate script should enforce p95 latency threshold")
assertTrue(gateScript.contains("input.errorRate >= 0.01"), "gate script should enforce error rate threshold")
assertTrue(gateScript.contains("input.batteryImpactPercentPerHour >= 2.5"), "gate script should enforce battery threshold")

assertTrue(prCheck.contains("scripts/realtime_ops_rollout_unit_check.swift"), "ios_pr_check should include realtime ops unit check")
assertTrue(prCheck.contains("scripts/realtime_ops_rollout_gate.swift --input docs/realtime-ops-kpi-sample-pass.json"), "ios_pr_check should execute realtime ops gate with sample input")

print("PASS: realtime ops rollout unit checks")
