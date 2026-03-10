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

/// Asserts that a condition holds for the static evidence pack contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let runbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let template = load("docs/widget-action-real-device-evidence-template-v1.md")
let matrix = load("docs/widget-action-real-device-validation-matrix-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(runbook.contains("# Widget Action Real-Device Evidence Runbook v1"), "runbook title should exist")
assertTrue(runbook.contains("Issue: #662"), "runbook should reference issue #662")
assertTrue(runbook.contains("Relates to: #408"), "runbook should reference #408")
assertTrue(runbook.contains("WidgetAction"), "runbook should require WidgetAction logs")
assertTrue(runbook.contains("onOpenURL received"), "runbook should require onOpenURL logs")
assertTrue(runbook.contains("consumePendingWidgetActionIfNeeded"), "runbook should require pending action consumption logs")
assertTrue(runbook.contains("request_id"), "runbook should require request_id capture guidance")
assertTrue(runbook.contains("step-1"), "runbook should define first screenshot evidence")
assertTrue(runbook.contains("step-2"), "runbook should define final screenshot evidence")
assertTrue(runbook.contains("cold start"), "runbook should mention cold start")
assertTrue(runbook.contains("background"), "runbook should mention background")
assertTrue(runbook.contains("foreground"), "runbook should mention foreground")

assertTrue(template.contains("# Widget Action Real-Device Evidence Template v1"), "template title should exist")
assertTrue(template.contains("Case ID:"), "template should include case ID")
assertTrue(template.contains("Action Route:"), "template should include action route")
assertTrue(template.contains("Pass / Fail:"), "template should include pass/fail field")
assertTrue(template.contains("[WidgetAction]"), "template should include WidgetAction log stub")
assertTrue(template.contains("consumePendingWidgetActionIfNeeded"), "template should include pending action log stub")
assertTrue(template.contains("request_id="), "template should include request id stub")

assertTrue(matrix.contains("docs/widget-action-real-device-evidence-runbook-v1.md"), "matrix should reference evidence runbook")
assertTrue(matrix.contains("docs/widget-action-real-device-evidence-template-v1.md"), "matrix should reference evidence template")
assertTrue(readme.contains("docs/widget-action-real-device-evidence-runbook-v1.md"), "README should link evidence runbook")
assertTrue(readme.contains("docs/widget-action-real-device-evidence-template-v1.md"), "README should link evidence template")
assertTrue(iosPRCheck.contains("widget_action_real_device_evidence_unit_check.swift"), "ios_pr_check should run the evidence pack check")

print("PASS: widget action real-device evidence runbook checks")
