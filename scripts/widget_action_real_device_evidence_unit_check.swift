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

let actionRunbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let actionMatrix = load("docs/widget-action-real-device-validation-matrix-v1.md")
let actionTemplate = load("docs/widget-action-real-device-evidence-template-v1.md")
let layoutRunbook = load("docs/widget-family-real-device-evidence-runbook-v1.md")
let layoutMatrix = load("docs/widget-family-real-device-validation-matrix-v1.md")
let layoutTemplate = load("docs/widget-family-real-device-evidence-template-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(actionRunbook.contains("# Widget Action Real-Device Evidence Runbook v1"), "action runbook title should exist")
assertTrue(actionRunbook.contains("Issue: #731"), "action runbook should reference current blocker issue")
assertTrue(!actionRunbook.contains("#662"), "action runbook should not keep stale issue #662")
assertTrue(actionTemplate.contains("Issue: #731"), "action template should reference current blocker issue")
assertTrue(!actionTemplate.contains("#662"), "action template should not keep stale issue #662")
assertTrue(actionRunbook.contains("docs/widget-family-real-device-validation-matrix-v1.md"), "action runbook should reference layout matrix")
assertTrue(actionRunbook.contains("widget-real-device-evidence"), "action runbook should reference bundle path")
assertTrue(actionMatrix.contains("#617"), "action matrix should mention #617")
assertTrue(actionMatrix.contains("#731"), "action matrix should mention #731")
assertTrue(actionMatrix.contains("Issue: #731"), "action matrix should reference current blocker issue")
assertTrue(!actionMatrix.contains("#660"), "action matrix should not keep stale issue #660")
assertTrue(actionMatrix.contains("WD-008"), "action matrix should keep WD-008")
assertTrue(actionMatrix.contains("WL-001"), "action matrix should mention layout linkage")

assertTrue(layoutRunbook.contains("# Widget Family Real-Device Evidence Runbook v1"), "layout runbook title should exist")
assertTrue(layoutRunbook.contains("Issue: #692"), "layout runbook should reference current blocker issue")
assertTrue(!layoutRunbook.contains("#751"), "layout runbook should not keep stale issue #751")
assertTrue(layoutRunbook.contains("WL-001"), "layout runbook should mention WL-001")
assertTrue(layoutRunbook.contains("validate_manual_evidence_pack.sh widget"), "layout runbook should reference widget validator")
assertTrue(layoutMatrix.contains("# Widget Family Real-Device Validation Matrix v1"), "layout matrix title should exist")
assertTrue(layoutMatrix.contains("Issue: #692"), "layout matrix should reference current blocker issue")
assertTrue(!layoutMatrix.contains("#751"), "layout matrix should not keep stale issue #751")
assertTrue(layoutMatrix.contains("WalkControlWidget"), "layout matrix should include WalkControlWidget")
assertTrue(layoutMatrix.contains("QuestRivalStatusWidget"), "layout matrix should include QuestRivalStatusWidget")
assertTrue(layoutMatrix.contains("HotspotStatusWidget"), "layout matrix should include HotspotStatusWidget")
assertTrue(layoutMatrix.contains("WL-008"), "layout matrix should include WL-008")
assertTrue(layoutTemplate.contains("# Widget Family Real-Device Evidence Template v1"), "layout template title should exist")
assertTrue(layoutTemplate.contains("Issue: #692"), "layout template should reference current blocker issue")
assertTrue(!layoutTemplate.contains("#751"), "layout template should not keep stale issue #751")
assertTrue(layoutTemplate.contains("Widget Surface:"), "layout template should include widget surface")
assertTrue(layoutTemplate.contains("Compact Formatting Rule:"), "layout template should include compact rule")
assertTrue(layoutTemplate.contains("Pass / Fail:"), "layout template should include pass/fail")

assertTrue(readme.contains("docs/widget-family-real-device-validation-matrix-v1.md"), "README should link layout matrix")
assertTrue(readme.contains("docs/widget-family-real-device-evidence-runbook-v1.md"), "README should link layout runbook")
assertTrue(readme.contains("docs/widget-family-real-device-evidence-template-v1.md"), "README should link layout template")
assertTrue(iosPRCheck.contains("widget_action_real_device_evidence_unit_check.swift"), "ios_pr_check should run evidence check")

print("PASS: widget real-device evidence bundle doc checks")
