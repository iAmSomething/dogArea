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

/// Asserts that a static widget closure-pack contract holds.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let checklist = load("docs/widget-action-closure-checklist-v1.md")
let template = load("docs/widget-action-closure-comment-template-v1.md")
let matrix = load("docs/widget-action-real-device-validation-matrix-v1.md")
let runbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(checklist.contains("# Widget Action Closure Checklist v1"), "checklist title should exist")
assertTrue(checklist.contains("Issue: #668"), "checklist should reference issue #668")
assertTrue(checklist.contains("Relates to: #408"), "checklist should reference #408")
for caseID in ["WD-001", "WD-002", "WD-003", "WD-004", "WD-005", "WD-006", "WD-007", "WD-008"] {
    assertTrue(checklist.contains(caseID), "checklist should require \(caseID)")
}
assertTrue(checklist.contains("WidgetAction"), "checklist should require WidgetAction log")
assertTrue(checklist.contains("onOpenURL received"), "checklist should require onOpenURL log")
assertTrue(checklist.contains("consumePendingWidgetActionIfNeeded"), "checklist should require pending action consume log")
assertTrue(checklist.contains("step-1"), "checklist should require step-1 screenshot")
assertTrue(checklist.contains("step-2"), "checklist should require step-2 screenshot")

assertTrue(template.contains("# Widget Action Closure Comment Template v1"), "template title should exist")
assertTrue(template.contains("실기기 위젯 액션 검증을 완료했습니다."), "template should open with validation summary")
assertTrue(template.contains("WD-001"), "template should include WD-001")
assertTrue(template.contains("WD-008"), "template should include WD-008")
assertTrue(template.contains("남은 blocker"), "template should include blocker section")
assertTrue(template.contains("`#408` DoD를 충족했으므로 종료합니다."), "template should include closure sentence")

assertTrue(matrix.contains("docs/widget-action-closure-checklist-v1.md"), "matrix should reference closure checklist")
assertTrue(runbook.contains("docs/widget-action-closure-checklist-v1.md"), "runbook should reference closure checklist")
assertTrue(readme.contains("docs/widget-action-closure-checklist-v1.md"), "README should link closure checklist")
assertTrue(readme.contains("docs/widget-action-closure-comment-template-v1.md"), "README should link closure comment template")
assertTrue(iosPRCheck.contains("widget_action_closure_pack_unit_check.swift"), "ios_pr_check should run widget closure pack check")

print("PASS: widget action closure pack checks")
