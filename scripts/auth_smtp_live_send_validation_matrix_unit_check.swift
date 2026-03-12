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

/// Asserts that a static document contract holds.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let matrix = load("docs/auth-smtp-live-send-validation-matrix-v1.md")
let runbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let template = load("docs/auth-smtp-rollout-evidence-template-v1.md")
let readme = load("README.md")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(matrix.contains("# Auth SMTP Live-Send Validation Matrix v1"), "matrix title should exist")
assertTrue(matrix.contains("Issue: #666"), "matrix should reference issue #666")
assertTrue(matrix.contains("Relates to: #482"), "matrix should reference #482")
assertTrue(matrix.contains("accepted"), "matrix should include accepted axis")
assertTrue(matrix.contains("mailbox_received"), "matrix should include mailbox_received axis")
assertTrue(matrix.contains("redirect_valid"), "matrix should include redirect_valid axis")
assertTrue(matrix.contains("provider_event_checked"), "matrix should include provider_event_checked axis")
assertTrue(matrix.contains("SMTP-001"), "matrix should include signup confirmation case")
assertTrue(matrix.contains("SMTP-002"), "matrix should include password reset case")
assertTrue(matrix.contains("SMTP-003"), "matrix should include email change case")
assertTrue(matrix.contains("SMTP-101"), "matrix should include duplicate resend guard case")
assertTrue(matrix.contains("SMTP-102"), "matrix should include bounce case")
assertTrue(matrix.contains("SMTP-103"), "matrix should include reject/deferred case")
assertTrue(matrix.contains("production | Y"), "matrix should mark production as required")

assertTrue(runbook.contains("docs/auth-smtp-live-send-validation-matrix-v1.md"), "runbook should reference live-send validation matrix")
assertTrue(template.contains("signup confirmation"), "template should still include signup confirmation scenario")
assertTrue(template.contains("password reset"), "template should still include password reset scenario")
assertTrue(template.contains("email change"), "template should still include email change scenario")
assertTrue(template.contains("evidence_asset"), "template should include mailbox evidence asset column")
assertTrue(template.contains("assets/signup-mailbox.png"), "template should include signup mailbox asset path")
assertTrue(readme.contains("docs/auth-smtp-live-send-validation-matrix-v1.md"), "README should link live-send validation matrix")
assertTrue(backendPRCheck.contains("auth_smtp_live_send_validation_matrix_unit_check.swift"), "backend_pr_check should run live-send validation matrix check")
assertTrue(iosPRCheck.contains("auth_smtp_live_send_validation_matrix_unit_check.swift"), "ios_pr_check should run live-send validation matrix check")

print("PASS: auth smtp live-send validation matrix checks")
