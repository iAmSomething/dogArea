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

/// Asserts that an auth SMTP closure-pack contract holds.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let checklist = load("docs/auth-smtp-closure-checklist-v1.md")
let template = load("docs/auth-smtp-closure-comment-template-v1.md")
let matrix = load("docs/auth-smtp-live-send-validation-matrix-v1.md")
let runbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(checklist.contains("# Auth SMTP Closure Checklist v1"), "checklist title should exist")
assertTrue(checklist.contains("Issue: #670"), "checklist should reference issue #670")
assertTrue(checklist.contains("Relates to: #482"), "checklist should reference #482")
for caseID in ["SMTP-001", "SMTP-002", "SMTP-003", "SMTP-101", "SMTP-102", "SMTP-103"] {
    assertTrue(checklist.contains(caseID), "checklist should reference \(caseID)")
}
assertTrue(checklist.contains("SMTP Host"), "checklist should require SMTP Host")
assertTrue(checklist.contains("SMTP Port"), "checklist should require SMTP Port")
assertTrue(checklist.contains("Sender Name"), "checklist should require Sender Name")
assertTrue(checklist.contains("Sender Email"), "checklist should require Sender Email")
assertTrue(checklist.contains("rollback path"), "checklist should require rollback path")
assertTrue(checklist.contains("secret rotation owner"), "checklist should require rotation owner")

assertTrue(template.contains("# Auth SMTP Closure Comment Template v1"), "template title should exist")
assertTrue(template.contains("custom SMTP rollout 운영 증적을 확인했습니다."), "template should open with rollout summary")
assertTrue(template.contains("SMTP-001"), "template should include SMTP-001")
assertTrue(template.contains("SMTP-003"), "template should include SMTP-003")
assertTrue(template.contains("SMTP-101"), "template should include SMTP-101")
assertTrue(template.contains("SMTP-102"), "template should include SMTP-102")
assertTrue(template.contains("`#482` DoD를 충족했으므로 종료합니다."), "template should include closure sentence")

assertTrue(matrix.contains("docs/auth-smtp-closure-checklist-v1.md"), "matrix should reference closure checklist")
assertTrue(runbook.contains("docs/auth-smtp-closure-checklist-v1.md"), "runbook should reference closure checklist")
assertTrue(readme.contains("docs/auth-smtp-closure-checklist-v1.md"), "README should link closure checklist")
assertTrue(readme.contains("docs/auth-smtp-closure-comment-template-v1.md"), "README should link closure comment template")
assertTrue(backendPRCheck.contains("auth_smtp_closure_pack_unit_check.swift"), "backend_pr_check should run auth smtp closure pack check")
assertTrue(iosPRCheck.contains("auth_smtp_closure_pack_unit_check.swift"), "ios_pr_check should run auth smtp closure pack check")

print("PASS: auth smtp closure pack checks")
