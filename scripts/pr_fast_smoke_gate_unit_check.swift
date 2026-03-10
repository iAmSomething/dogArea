import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ path: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(path))
    return String(decoding: data, as: UTF8.self)
}

let guide = load("docs/pr-fast-smoke-gate-v1.md")
let template = load("docs/pr-fast-smoke-gate-report-template-v1.md")
let readme = load("README.md")

assertTrue(guide.contains("- Issue: #705"), "fast smoke doc must reference issue #705")
assertTrue(guide.contains("## 역할 경계"), "fast smoke doc must define boundary from nightly")
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

print("PASS: pr fast smoke gate unit checks")
