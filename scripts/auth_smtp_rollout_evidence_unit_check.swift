import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a repository-relative UTF-8 text file.
/// - Parameter relativePath: Repository-relative path to read.
/// - Returns: Decoded file contents.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to load \(relativePath)\n", stderr)
        exit(1)
    }
    return text
}

/// Asserts that a static documentation contract holds.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let runbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let template = load("docs/auth-smtp-rollout-evidence-template-v1.md")
let checklist = load("docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md")
let observability = load("docs/auth-mail-observability-metric-alert-request-key-v1.md")
let readme = load("README.md")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(runbook.contains("# Auth SMTP Rollout Evidence Runbook v1"), "runbook title should exist")
assertTrue(runbook.contains("Issue: #664"), "runbook should reference issue #664")
assertTrue(runbook.contains("Relates to: #482"), "runbook should reference #482")
assertTrue(runbook.contains("SPF pass"), "runbook should require SPF evidence")
assertTrue(runbook.contains("DKIM verified"), "runbook should require DKIM evidence")
assertTrue(runbook.contains("DMARC record"), "runbook should require DMARC evidence")
assertTrue(runbook.contains("SMTP Host"), "runbook should require SMTP host evidence")
assertTrue(runbook.contains("SMTP Port"), "runbook should require SMTP port evidence")
assertTrue(runbook.contains("Sender Name"), "runbook should require sender name evidence")
assertTrue(runbook.contains("Sender Email"), "runbook should require sender email evidence")
assertTrue(runbook.contains("signup confirmation"), "runbook should require signup confirmation evidence")
assertTrue(runbook.contains("password reset"), "runbook should require password reset evidence")
assertTrue(runbook.contains("email change"), "runbook should require email change evidence")
assertTrue(runbook.contains("provider_message_id"), "runbook should require provider message identifiers")
assertTrue(runbook.contains("rollback"), "runbook should require rollback readiness")
assertTrue(runbook.contains("rotation"), "runbook should require rotation readiness")

assertTrue(template.contains("# Auth SMTP Rollout Evidence Template v1"), "template title should exist")
assertTrue(template.contains("Supabase Project:"), "template should include Supabase project")
assertTrue(template.contains("Provider:"), "template should include provider")
assertTrue(template.contains("Sender Domain:"), "template should include sender domain")
assertTrue(template.contains("| signup confirmation |"), "template should include signup confirmation row")
assertTrue(template.contains("| password reset |"), "template should include password reset row")
assertTrue(template.contains("| email change |"), "template should include email change row")
assertTrue(template.contains("provider_message_id"), "template should include provider message id")
assertTrue(template.contains("Pass / Fail:"), "template should include pass/fail field")
assertTrue(template.contains("Remaining Blockers:"), "template should include blocker field")

assertTrue(checklist.contains("## DNS 체크리스트"), "existing provider checklist should still define DNS checklist")
assertTrue(observability.contains("provider_message_id"), "observability doc should still define provider message id")
assertTrue(readme.contains("docs/auth-smtp-rollout-evidence-runbook-v1.md"), "README should link auth smtp rollout evidence runbook")
assertTrue(readme.contains("docs/auth-smtp-rollout-evidence-template-v1.md"), "README should link auth smtp rollout evidence template")
assertTrue(backendPRCheck.contains("auth_smtp_rollout_evidence_unit_check.swift"), "backend_pr_check should run auth smtp rollout evidence check")
assertTrue(iosPRCheck.contains("auth_smtp_rollout_evidence_unit_check.swift"), "ios_pr_check should run auth smtp rollout evidence check")

print("PASS: auth smtp rollout evidence runbook checks")
