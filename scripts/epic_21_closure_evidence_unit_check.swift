import Foundation

/// Asserts that a condition is true and exits with a failure message otherwise.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to `true`.
///   - message: Failure description printed when the assertion does not hold.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a UTF-8 text file from the repository root.
/// - Parameter relativePath: Repository-relative file path to read.
/// - Returns: Decoded UTF-8 file contents.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let evidenceDoc = load("docs/epic-21-closure-evidence-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let backendCheck = load("scripts/backend_pr_check.sh")

assertTrue(evidenceDoc.contains("#21"), "evidence doc should reference epic #21")
assertTrue(evidenceDoc.contains("#412"), "evidence doc should reference issue #412")
assertTrue(evidenceDoc.contains("#595"), "evidence doc should reference residual blocker issue #595")

assertTrue(evidenceDoc.contains("bash scripts/backend_pr_check.sh"), "evidence doc should record backend_pr_check execution")
assertTrue(evidenceDoc.contains("bash scripts/ios_pr_check.sh"), "evidence doc should record ios_pr_check execution")
assertTrue(evidenceDoc.contains("swift scripts/security_key_exposure_unit_check.swift"), "evidence doc should record security key exposure check")
assertTrue(evidenceDoc.contains("npx --yes supabase migration list --linked"), "evidence doc should record linked migration list execution")
assertTrue(evidenceDoc.contains("npx --yes supabase db push --linked"), "evidence doc should record linked db push execution")

assertTrue(evidenceDoc.contains("20260309043000_realtime_retention_cleanup_rollout.sql"), "evidence doc should identify the remaining migration blocker")
assertTrue(evidenceDoc.contains("SQLSTATE 42803"), "evidence doc should preserve the linked rollout failure code")
assertTrue(evidenceDoc.contains("view_owner_walk_stats"), "evidence doc should reference the owner stats SQL surface")
assertTrue(evidenceDoc.contains("get_backfill_summary"), "evidence doc should reference the app-facing summary route")
assertTrue(evidenceDoc.contains("total_duration_sec"), "evidence doc should mention the missing duration parity column")
assertTrue(evidenceDoc.contains("에픽 종료 직전 단계"), "evidence doc should conclude the epic is not fully closable yet")

assertTrue(readme.contains("docs/epic-21-closure-evidence-v1.md"), "README should index the epic #21 closure evidence doc")
assertTrue(iosCheck.contains("swift scripts/epic_21_closure_evidence_unit_check.swift"), "ios_pr_check should run the epic #21 closure evidence unit check")
assertTrue(backendCheck.contains("swift scripts/epic_21_closure_evidence_unit_check.swift"), "backend_pr_check should run the epic #21 closure evidence unit check")

print("PASS: epic #21 closure evidence unit checks")
