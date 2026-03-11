import Foundation

/// Validates that a required fast smoke contract condition holds.
/// - Parameters:
///   - condition: Condition to validate for the workflow/document contract.
///   - message: Failure message printed when the condition does not hold.
@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a repository-relative UTF-8 text file.
/// - Parameter path: Repository-relative path to load.
/// - Returns: Decoded file contents.
func load(_ path: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(path))
    return String(decoding: data, as: UTF8.self)
}

let guide = load("docs/pr-fast-smoke-gate-v1.md")
let template = load("docs/pr-fast-smoke-gate-report-template-v1.md")
let readme = load("README.md")
let workflow = load(".github/workflows/pr-fast-smoke-gate.yml")
let fullCheckWorkflow = load(".github/workflows/ios-pr-check.yml")

assertTrue(guide.contains("- Issue: #705"), "fast smoke doc must reference issue #705")
assertTrue(guide.contains("## 역할 경계"), "fast smoke doc must define boundary from nightly")
assertTrue(guide.contains(".github/workflows/pr-fast-smoke-gate.yml"), "fast smoke doc must bind the dedicated workflow file")
assertTrue(guide.contains(".github/workflows/ios-pr-check.yml"), "fast smoke doc must describe ios full check role separation")
assertTrue(guide.contains("FS-001"), "fast smoke doc must define map axis")
assertTrue(guide.contains("FS-002"), "fast smoke doc must define widget layout axis")
assertTrue(guide.contains("FS-003"), "fast smoke doc must define widget action axis")
assertTrue(guide.contains("FS-004"), "fast smoke doc must define watch axis")
assertTrue(guide.contains("FS-005"), "fast smoke doc must define sync recovery axis")
assertTrue(guide.contains("PASS | FAIL | BLOCKED | SKIPPED"), "fast smoke doc must freeze result states")
assertTrue(guide.contains("map_root_ui"), "fast smoke doc must define failure bucket")
assertTrue(guide.contains("widget_layout"), "fast smoke doc must define widget layout bucket")
assertTrue(guide.contains("widget_action"), "fast smoke doc must define widget action bucket")
assertTrue(guide.contains("watch_basic_action"), "fast smoke doc must define watch bucket")
assertTrue(guide.contains("sync_recovery"), "fast smoke doc must define sync recovery bucket")
assertTrue(guide.contains("run_feature_regression_ui_tests.sh"), "fast smoke doc must reference map regression runner")
assertTrue(guide.contains("run_widget_action_regression_ui_tests.sh"), "fast smoke doc must reference widget regression runner")
assertTrue(guide.contains("backend_pr_check.sh"), "fast smoke doc must reference backend smoke runner")
assertTrue(template.contains("## Summary"), "fast smoke template must include summary section")
assertTrue(template.contains("## Detail"), "fast smoke template must include detail section")
assertTrue(template.contains("## Failure Triage"), "fast smoke template must include triage section")
assertTrue(template.contains("## Final Decision"), "fast smoke template must include final decision section")
assertTrue(readme.contains("docs/pr-fast-smoke-gate-v1.md"), "README must index fast smoke guide")
assertTrue(readme.contains("docs/pr-fast-smoke-gate-report-template-v1.md"), "README must index fast smoke template")
assertTrue(workflow.contains("name: pr-fast-smoke-gate"), "workflow must use canonical fast smoke workflow name")
assertTrue(workflow.contains("pull_request:"), "workflow must trigger on pull_request")
assertTrue(workflow.contains("workflow_dispatch:"), "workflow must support manual rerun")
assertTrue(workflow.contains("FS-001 map_root_ui"), "workflow must expose FS-001 job naming")
assertTrue(workflow.contains("FS-002 widget_layout"), "workflow must expose FS-002 job naming")
assertTrue(workflow.contains("FS-003 widget_action"), "workflow must expose FS-003 job naming")
assertTrue(workflow.contains("FS-004 watch_basic_action"), "workflow must expose FS-004 job naming")
assertTrue(workflow.contains("FS-005 sync_recovery"), "workflow must expose FS-005 job naming")
assertTrue(workflow.contains("run_pr_fast_smoke_map_ui_tests.sh"), "workflow must run dedicated FS-001 runner")
assertTrue(workflow.contains("run_pr_fast_smoke_widget_layout_checks.sh"), "workflow must run dedicated FS-002 runner")
assertTrue(workflow.contains("run_widget_action_regression_ui_tests.sh"), "workflow must run FS-003 widget action runner")
assertTrue(workflow.contains("run_pr_fast_smoke_watch_contract_checks.sh"), "workflow must run dedicated FS-004 runner")
assertTrue(workflow.contains("auth_member_401_smoke_check.sh"), "workflow must run FS-005 auth smoke")
assertTrue(workflow.contains("actions/upload-artifact@v4"), "workflow must upload fast smoke artifacts")
assertTrue(fullCheckWorkflow.contains("name: ios-full-check"), "ios full check workflow must be renamed to clarify role")
assertTrue(fullCheckWorkflow.contains("push:"), "ios full check workflow must run on main push")
assertTrue(!fullCheckWorkflow.contains("pull_request:"), "ios full check workflow should no longer duplicate PR fast smoke on pull_request")

print("PASS: pr fast smoke gate unit checks")
