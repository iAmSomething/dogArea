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
let actionMatrix = load("docs/widget-action-real-device-validation-matrix-v1.md")
let layoutMatrix = load("docs/widget-family-real-device-validation-matrix-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(checklist.contains("#408, #617, #692, #731"), "checklist should reference bundled widget issues")
for caseID in ["WD-001", "WD-008", "WL-001", "WL-008"] {
    assertTrue(checklist.contains(caseID), "checklist should require \(caseID)")
}
assertTrue(checklist.contains("Widget Surface"), "checklist should require layout fields")
assertTrue(checklist.contains("WidgetAction"), "checklist should require WidgetAction log")
assertTrue(checklist.contains("step-2"), "checklist should require step-2 screenshot")

assertTrue(template.contains("실기기 위젯 blocker 검증을 완료했습니다."), "template should open with blocker validation summary")
assertTrue(template.contains("layout / clipping 케이스"), "template should include layout section")
assertTrue(template.contains("#617"), "template should mention #617")
assertTrue(template.contains("#731"), "template should mention #731")
assertTrue(template.contains("#408`, `#617`, `#692`, `#731"), "template should close bundled issues")

assertTrue(actionMatrix.contains("docs/widget-action-closure-checklist-v1.md"), "action matrix should reference closure checklist")
assertTrue(layoutMatrix.contains("docs/widget-action-closure-checklist-v1.md"), "layout matrix should reference closure checklist")
assertTrue(readme.contains("docs/widget-action-closure-checklist-v1.md"), "README should link closure checklist")
assertTrue(readme.contains("docs/widget-action-closure-comment-template-v1.md"), "README should link closure comment template")
assertTrue(iosPRCheck.contains("widget_action_closure_pack_unit_check.swift"), "ios_pr_check should run widget closure pack check")

print("PASS: widget closure pack checks")
