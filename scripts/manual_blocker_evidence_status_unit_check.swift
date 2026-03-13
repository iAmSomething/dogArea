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

/// Asserts that a condition holds for the blocker evidence status runner contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs the blocker evidence status runner and captures combined output.
/// - Parameters:
///   - arguments: CLI arguments passed to the runner.
///   - environment: Additional environment variables for the subprocess.
/// - Returns: Combined stdout and stderr from the launched process.
func runStatus(arguments: [String], environment: [String: String] = [:]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/manual_blocker_evidence_status.sh"] + arguments

    var env = ProcessInfo.processInfo.environment
    env["DOGAREA_SKIP_ISSUE_STATE"] = "1"
    environment.forEach { env[$0.key] = $0.value }
    process.environment = env

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch runner: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        fputs("Runner failed with status \(process.terminationStatus)\n\(output)\n", stderr)
        exit(1)
    }

    return output
}

/// Writes UTF-8 text into the provided file URL, creating parent directories as needed.
/// - Parameters:
///   - url: Destination file URL.
///   - content: UTF-8 content to write.
func write(_ url: URL, content: String) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fputs("Failed to write \(url.path): \(error)\n", stderr)
        exit(1)
    }
}

/// Writes a placeholder asset file for status-runner-backed evidence tests.
/// - Parameter url: Asset file URL to create.
func writeAsset(_ url: URL) {
    write(url, content: "placeholder-asset")
}

/// Writes a simulator baseline status file consumed by the blocker evidence runner.
/// - Parameters:
///   - directory: Directory that stores baseline status files.
///   - suite: Baseline suite identifier.
///   - status: Baseline outcome such as `pass` or `fail`.
///   - ranAt: UTC timestamp string recorded for the suite.
///   - coverage: Comma-separated case identifiers covered by the baseline suite.
func writeSimulatorBaseline(_ directory: URL, suite: String, status: String, ranAt: String, coverage: String? = nil) {
    let content = """
    suite=\(suite)
    status=\(status)
    ran_at_utc=\(ranAt)
    destination=simulator
    command=bash scripts/\(suite)
    coverage=\(coverage ?? "")
    """
    write(directory.appendingPathComponent("\(suite).status"), content: content)
}

/// Loads a UTF-8 text file from an absolute file URL.
/// - Parameter url: Absolute file URL to read.
/// - Returns: Decoded file contents.
func loadFile(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to load file \(url.path)\n", stderr)
        exit(1)
    }
    return text
}

/// Builds a filled widget action case from the shared template.
/// - Parameters:
///   - caseID: Canonical action case identifier.
///   - summary: Summary text for the case.
/// - Returns: Filled markdown for the action case.
func filledWidgetAction(caseID: String, summary: String) -> String {
    let template = load("docs/widget-action-real-device-evidence-template-v1.md")
    return template
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-12")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.12.1")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemSmall")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: cold start")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: route converges")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: FinalScreen")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] action=\(caseID) request_id=req-\(caseID)")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded consumed=\(caseID)")
        .replacingOccurrences(of: "request_id=...", with: "request_id=req-\(caseID)")
        .replacingOccurrences(of: "- `step-1`: assets/action/<case-id>-step-1.png", with: "- `step-1`: assets/action/\(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`: assets/action/<case-id>-step-2.png", with: "- `step-2`: assets/action/\(caseID)-step-2.png")
}

/// Builds a filled widget layout case from the shared template.
/// - Parameters:
///   - caseID: Canonical layout case identifier.
///   - surface: Widget surface name.
/// - Returns: Filled markdown for the layout case.
func filledWidgetLayout(caseID: String, surface: String) -> String {
    let template = load("docs/widget-family-real-device-evidence-template-v1.md")
    return template
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-12")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.12.1")
        .replacingOccurrences(of: "- Widget Surface:", with: "- Widget Surface: \(surface)")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemSmall")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- Covered States:", with: "- Covered States: idle, syncDelayed")
        .replacingOccurrences(of: "- Headline Policy:", with: "- Headline Policy: 2 lines max")
        .replacingOccurrences(of: "- Detail Policy:", with: "- Detail Policy: 1 line max")
        .replacingOccurrences(of: "- Badge Budget:", with: "- Badge Budget: 2 max")
        .replacingOccurrences(of: "- CTA Height Rule:", with: "- CTA Height Rule: 44-52pt")
        .replacingOccurrences(of: "- Metric Tile Rule:", with: "- Metric Tile Rule: stable strip height")
        .replacingOccurrences(of: "- Compact Formatting Rule:", with: "- Compact Formatting Rule: shortened unit labels")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: no clipping")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(surface) layout stayed within bounds")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "- `step-1`: assets/layout/<case-id>-step-1.png", with: "- `step-1`: assets/layout/\(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`: assets/layout/<case-id>-step-2.png", with: "- `step-2`: assets/layout/\(caseID)-step-2.png")
}

let runnerScript = load("scripts/manual_blocker_evidence_status.sh")
let widgetBaselineScript = load("scripts/lib/widget_simulator_baseline_status.sh")
let doc = load("docs/manual-blocker-evidence-status-runner-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(runnerScript.contains("widget-real-device-evidence"), "runner should support widget evidence directory")
assertTrue(runnerScript.contains("related-issues"), "runner should print related widget issues")
assertTrue(runnerScript.contains("next-archive"), "runner should print archive command")
assertTrue(runnerScript.contains("next-prefill-existing"), "runner should print prefill-existing command")
assertTrue(runnerScript.contains("next-post-closure-bundle"), "runner should print bundled widget post command")
assertTrue(runnerScript.contains("--markdown"), "runner should support markdown mode")
assertTrue(runnerScript.contains("--output"), "runner should support output path")
assertTrue(runnerScript.contains("--raw-errors"), "runner should support raw error output mode")
assertTrue(runnerScript.contains("--apply-prefill"), "runner should support one-shot prefill application")
assertTrue(runnerScript.contains("next-apply-prefill"), "runner should print status-runner prefill guidance")
assertTrue(runnerScript.contains("next-prefill-env"), "runner should print env template guidance")
assertTrue(runnerScript.contains("next-prefill-bootstrap"), "runner should print one-shot prefill bootstrap guidance")
assertTrue(runnerScript.contains("simulator-baseline:"), "runner should print plain simulator baseline summaries")
assertTrue(runnerScript.contains("### Simulator Baseline"), "runner should print markdown simulator baseline summaries")
assertTrue(runnerScript.contains("simulator-coverage-summary"), "runner should print simulator coverage summaries")
assertTrue(runnerScript.contains("next-refresh-widget-action-baseline"), "runner should print action baseline refresh guidance")
assertTrue(runnerScript.contains("next-refresh-widget-layout-baseline"), "runner should print layout baseline refresh guidance")
assertTrue(runnerScript.contains("Apply Prefill Then Refresh"), "runner should print markdown prefill guidance")
assertTrue(runnerScript.contains("Print Prefill Env Template"), "runner should print markdown env template guidance")
assertTrue(runnerScript.contains("Bootstrap Prefill In One Shot"), "runner should print markdown bootstrap guidance")
assertTrue(runnerScript.contains("prefill-opportunity:"), "runner should summarize metadata-prefill opportunities")
assertTrue(runnerScript.contains("missing-prefill-env:"), "runner should summarize missing prefill env vars")
assertTrue(runnerScript.contains("gap-summary:"), "runner should print plain gap summaries for incomplete packs")
assertTrue(runnerScript.contains("next-fill:"), "runner should print next-fill guidance")
assertTrue(runnerScript.contains("### Gap Summary"), "runner should print markdown gap summaries for incomplete packs")
assertTrue(runnerScript.contains("widget --output %q --prefill-from-env"), "runner should prefer prefilled widget render commands")
assertTrue(runnerScript.contains("--prefill-from-env"), "runner should use auth smtp env prefill render path")
assertTrue(widgetBaselineScript.contains("write_widget_simulator_baseline_status"), "widget simulator baseline helper should expose a status writer")
assertTrue(doc.contains("primary `#731`, related `#617`, `#692`"), "doc should describe active widget blocker routing")
assertTrue(doc.contains("widget-real-device-evidence"), "doc should mention widget directory path")
assertTrue(doc.contains("simulator-baseline"), "doc should describe simulator baseline output")
assertTrue(doc.contains("simulator-coverage-summary"), "doc should describe simulator coverage summary output")
assertTrue(doc.contains("run_widget_action_regression_ui_tests.sh"), "doc should mention widget action baseline source")
assertTrue(doc.contains("run_pr_fast_smoke_widget_layout_checks.sh"), "doc should mention widget layout baseline source")
assertTrue(doc.contains("next-archive"), "doc should describe archive command")
assertTrue(doc.contains("next-prefill-existing"), "doc should describe prefill-existing command")
assertTrue(doc.contains("next-post-closure-bundle"), "doc should describe bundled widget post command")
assertTrue(doc.contains("Manual Blocker Evidence Status Report"), "doc should describe markdown report title")
assertTrue(doc.contains("--markdown"), "doc should describe markdown mode")
assertTrue(doc.contains("--output"), "doc should describe output export")
assertTrue(doc.contains("--raw-errors"), "doc should describe raw error output mode")
assertTrue(doc.contains("--apply-prefill"), "doc should describe one-shot prefill application")
assertTrue(doc.contains("next-apply-prefill"), "doc should describe status-runner prefill guidance")
assertTrue(doc.contains("next-prefill-env"), "doc should describe env template guidance")
assertTrue(doc.contains("next-prefill-bootstrap"), "doc should describe one-shot bootstrap guidance")
assertTrue(doc.contains("gap-summary"), "doc should describe plain gap summary output")
assertTrue(doc.contains("next-fill"), "doc should describe next-fill guidance")
assertTrue(doc.contains("### Gap Summary"), "doc should describe markdown gap summary heading")
assertTrue(doc.contains("03-live-send-results.md"), "doc should describe auth-smtp file-level scenario row grouping")
assertTrue(doc.contains("--prefill-from-env"), "doc should describe auth smtp prefill render command")
assertTrue(readme.contains("docs/manual-blocker-evidence-status-runner-v1.md"), "README should link runner doc")
assertTrue(readme.contains("run_pr_fast_smoke_widget_layout_checks.sh"), "README should list the widget layout fast smoke command")
assertTrue(iosPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "ios_pr_check should run blocker runner check")
assertTrue(backendPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "backend_pr_check should run blocker runner check")

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetPath = tempRoot.appendingPathComponent("widget")
let authPath = tempRoot.appendingPathComponent("auth")
let widgetBaselinePath = tempRoot.appendingPathComponent("widget-sim-baseline")

let missingOutput = runStatus(arguments: ["widget"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
])
assertTrue(missingOutput.contains("== widget =="), "runner should print widget header")
assertTrue(missingOutput.contains("status: missing"), "runner should mark missing widget evidence")
assertTrue(missingOutput.contains("issue: #731 (skipped)"), "runner should print active widget primary issue")
assertTrue(missingOutput.contains("related-issues: #617 #692"), "runner should print related widget issues")
assertTrue(missingOutput.contains("simulator-baseline:"), "widget status should include simulator baseline summary")
assertTrue(missingOutput.contains("action-regression: missing"), "widget status should show missing action baseline when no stamp exists")
assertTrue(missingOutput.contains("layout-fast-smoke: missing"), "widget status should show missing layout baseline when no stamp exists")
assertTrue(missingOutput.contains("coverage: WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008"), "widget status should show action coverage defaults")
assertTrue(missingOutput.contains("coverage: WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008"), "widget status should show layout coverage defaults")
assertTrue(missingOutput.contains("simulator-coverage-summary: action 8/8, layout 8/8"), "widget status should summarize simulator coverage counts")

writeSimulatorBaseline(
    widgetBaselinePath,
    suite: "action-regression",
    status: "pass",
    ranAt: "2026-03-13T10:25:00Z",
    coverage: "WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008"
)
writeSimulatorBaseline(
    widgetBaselinePath,
    suite: "layout-fast-smoke",
    status: "pass",
    ranAt: "2026-03-13T10:26:00Z",
    coverage: "WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008"
)

let generatedOutput = runStatus(arguments: ["widget", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 16 / iOS 18.5",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.1",
])
assertTrue(FileManager.default.fileExists(atPath: widgetPath.appendingPathComponent("action/WD-001.md").path), "write-missing should create widget action cases")
assertTrue(generatedOutput.contains("status: incomplete"), "generated widget bundle should still be incomplete until filled")
assertTrue(generatedOutput.contains("next-render: bash scripts/render_manual_evidence_pack.sh widget --output \(widgetPath.path) --prefill-from-env"), "generated widget bundle should advertise prefilled widget render command")
assertTrue(generatedOutput.contains("next-prefill-existing: bash scripts/prefill_manual_evidence_pack.sh widget \(widgetPath.path)"), "generated widget bundle should advertise widget prefill-existing command")
assertTrue(!generatedOutput.contains("next-apply-prefill:"), "generated widget bundle should not suggest apply-prefill when metadata gaps are already resolved")
assertTrue(generatedOutput.contains("gap-summary: 16 incomplete cases (action 8, layout 8, total-errors 120)"), "generated widget bundle should summarize reduced incomplete case counts after metadata prefill")
assertTrue(generatedOutput.contains("next-fill: action/WD-001.md"), "generated widget bundle should point at the first case to fill")
assertTrue(generatedOutput.contains("gap-cases:"), "generated widget bundle should print case bucket list")
assertTrue(generatedOutput.contains("WD-001: result, assets, placeholder logs"), "generated widget bundle should dedupe case buckets after metadata prefill")
assertTrue(generatedOutput.contains("WL-001: result, assets"), "generated widget bundle should reduce layout gaps after metadata prefill")
assertTrue(generatedOutput.contains("action-regression: pass (2026-03-13T10:25:00Z)"), "widget status should show the latest action baseline stamp")
assertTrue(generatedOutput.contains("layout-fast-smoke: pass (2026-03-13T10:26:00Z)"), "widget status should show the latest layout baseline stamp")
assertTrue(generatedOutput.contains("coverage: WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008"), "widget status should print stamped action coverage")
assertTrue(generatedOutput.contains("coverage: WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008"), "widget status should print stamped layout coverage")
assertTrue(generatedOutput.contains("simulator-coverage-summary: action 8/8, layout 8/8"), "widget status should print simulator coverage summary")
assertTrue(generatedOutput.contains("next-refresh-widget-action-baseline: bash scripts/run_widget_action_regression_ui_tests.sh"), "widget status should advertise the action baseline refresh command")
assertTrue(generatedOutput.contains("next-refresh-widget-layout-baseline: bash scripts/run_pr_fast_smoke_widget_layout_checks.sh"), "widget status should advertise the layout baseline refresh command")
assertTrue(!generatedOutput.contains("empty value:"), "generated widget bundle should hide raw validator errors by default")

let widgetExistingPath = tempRoot.appendingPathComponent("widget-existing")
_ = runStatus(arguments: ["widget", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetExistingPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
let widgetUnappliedExistingOutput = runStatus(arguments: ["widget"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetExistingPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
])
assertTrue(widgetUnappliedExistingOutput.contains("next-apply-prefill: bash scripts/manual_blocker_evidence_status.sh widget --apply-prefill"), "existing widget bundles with metadata gaps should prioritize apply-prefill guidance")
assertTrue(widgetUnappliedExistingOutput.contains("next-prefill-env: bash scripts/print_manual_evidence_prefill_env.sh widget"), "existing widget bundles should advertise env template guidance")
assertTrue(widgetUnappliedExistingOutput.contains("next-prefill-bootstrap: source <(bash scripts/print_manual_evidence_prefill_env.sh widget) && bash scripts/manual_blocker_evidence_status.sh widget --apply-prefill"), "existing widget bundles should advertise one-shot bootstrap guidance")
assertTrue(widgetUnappliedExistingOutput.contains("prefill-opportunity: metadata gaps detected in 16 cases"), "existing widget bundles should summarize metadata prefill opportunity")
assertTrue(widgetUnappliedExistingOutput.contains("missing-prefill-env: DOGAREA_WIDGET_EVIDENCE_DEVICE_OS, DOGAREA_WIDGET_EVIDENCE_APP_BUILD"), "existing widget bundles should summarize missing widget prefill env vars")

let widgetAppliedPath = tempRoot.appendingPathComponent("widget-applied")
_ = runStatus(arguments: ["widget", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetAppliedPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
let widgetAppliedPrefillOutput = runStatus(arguments: ["widget", "--apply-prefill"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetAppliedPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 16 / iOS 18.5",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.1",
])
assertTrue(widgetAppliedPrefillOutput.contains("gap-summary: 16 incomplete cases (action 8, layout 8, total-errors 120)"), "apply-prefill should reduce widget error counts for existing bundles")
assertTrue(widgetAppliedPrefillOutput.contains("WD-001: result, assets, placeholder logs"), "apply-prefill should remove metadata gaps from widget bundles")

for caseID in ["WD-001", "WD-002", "WD-003", "WD-004", "WD-005", "WD-006", "WD-007", "WD-008"] {
    write(widgetPath.appendingPathComponent("action/\(caseID).md"), content: filledWidgetAction(caseID: caseID, summary: "\(caseID) converged"))
    writeAsset(widgetPath.appendingPathComponent("assets/action/\(caseID)-step-1.png"))
    writeAsset(widgetPath.appendingPathComponent("assets/action/\(caseID)-step-2.png"))
}
let layoutSurfaces = [
    "WL-001": "WalkControlWidget",
    "WL-002": "WalkControlWidget",
    "WL-003": "TerritoryStatusWidget",
    "WL-004": "TerritoryStatusWidget",
    "WL-005": "QuestRivalStatusWidget",
    "WL-006": "QuestRivalStatusWidget",
    "WL-007": "HotspotStatusWidget",
    "WL-008": "HotspotStatusWidget"
]
for (caseID, surface) in layoutSurfaces {
    write(widgetPath.appendingPathComponent("layout/\(caseID).md"), content: filledWidgetLayout(caseID: caseID, surface: surface))
    writeAsset(widgetPath.appendingPathComponent("assets/layout/\(caseID)-step-1.png"))
    writeAsset(widgetPath.appendingPathComponent("assets/layout/\(caseID)-step-2.png"))
}
let completeOutput = runStatus(arguments: ["widget"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
])
assertTrue(completeOutput.contains("status: complete"), "filled widget evidence should be reported as complete")
assertTrue(completeOutput.contains("render_closure_comment_from_evidence.sh widget"), "runner should print widget closure render command")
assertTrue(completeOutput.contains("archive_manual_evidence_pack.sh widget"), "runner should print widget archive command")
assertTrue(completeOutput.contains("next-post-closure-bundle: bash scripts/post_closure_comment_from_evidence.sh widget --all-related"), "runner should print bundled widget post command")
assertTrue(!completeOutput.contains("gap-summary:"), "complete widget evidence should not print a gap summary")

let markdownOutput = runStatus(arguments: ["widget", "--markdown"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
])
assertTrue(markdownOutput.contains("# Manual Blocker Evidence Status Report"), "markdown mode should print report title")
assertTrue(markdownOutput.contains("## widget"), "markdown mode should render widget section")
assertTrue(markdownOutput.contains("- Primary Issue: [#731]"), "markdown mode should render primary issue link")
assertTrue(markdownOutput.contains("### Simulator Baseline"), "markdown mode should render simulator baseline section")
assertTrue(markdownOutput.contains("- Action Regression: `pass` (`2026-03-13T10:25:00Z`)"), "markdown mode should print the action baseline stamp")
assertTrue(markdownOutput.contains("- Layout Fast Smoke: `pass` (`2026-03-13T10:26:00Z`)"), "markdown mode should print the layout baseline stamp")
assertTrue(markdownOutput.contains("- Coverage: `WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008`"), "markdown mode should print action coverage")
assertTrue(markdownOutput.contains("- Coverage: `WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008`"), "markdown mode should print layout coverage")
assertTrue(markdownOutput.contains("- Coverage Summary: `action 8/8`, `layout 8/8`"), "markdown mode should print simulator coverage summary")
assertTrue(markdownOutput.contains("- Prefill Existing: `bash scripts/prefill_manual_evidence_pack.sh widget"), "markdown mode should render widget prefill-existing command")
assertTrue(markdownOutput.contains("- Post Closure Bundle: `bash scripts/post_closure_comment_from_evidence.sh widget --all-related"), "markdown mode should render bundled post command")
assertTrue(!markdownOutput.contains("### Gap Summary"), "complete widget markdown should not print a gap summary")

let incompleteMarkdownOutput = runStatus(arguments: ["widget", "--markdown", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": tempRoot.appendingPathComponent("widget-incomplete").path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 16 / iOS 18.5",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.1",
])
assertTrue(incompleteMarkdownOutput.contains("### Gap Summary"), "incomplete widget markdown should print a gap summary")
assertTrue(incompleteMarkdownOutput.contains("- Next Fill: `action/WD-001.md`"), "incomplete widget markdown should print next-fill guidance")
assertTrue(incompleteMarkdownOutput.contains("- Incomplete Cases: `16` (`action 8`, `layout 8`, `errors 120`)"), "incomplete widget markdown should reflect reduced error count after metadata prefill")
assertTrue(!incompleteMarkdownOutput.contains("Apply Prefill Then Refresh"), "write-missing widget markdown should not suggest apply-prefill after metadata prefill")

let widgetExistingMarkdownOutput = runStatus(arguments: ["widget", "--markdown"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetExistingPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_SIM_BASELINE_DIR": widgetBaselinePath.path,
])
assertTrue(widgetExistingMarkdownOutput.contains("- Apply Prefill Then Refresh: `bash scripts/manual_blocker_evidence_status.sh widget --apply-prefill`"), "existing widget markdown should suggest apply-prefill first")
assertTrue(widgetExistingMarkdownOutput.contains("- Print Prefill Env Template: `bash scripts/print_manual_evidence_prefill_env.sh widget`"), "existing widget markdown should suggest env template first")
assertTrue(widgetExistingMarkdownOutput.contains("- Bootstrap Prefill In One Shot: `source <(bash scripts/print_manual_evidence_prefill_env.sh widget) && bash scripts/manual_blocker_evidence_status.sh widget --apply-prefill`"), "existing widget markdown should suggest bootstrap command")
assertTrue(widgetExistingMarkdownOutput.contains("- Prefill Opportunity: metadata gaps in `16` cases"), "existing widget markdown should summarize metadata-prefill opportunity")
assertTrue(widgetExistingMarkdownOutput.contains("- Missing Prefill Env: `DOGAREA_WIDGET_EVIDENCE_DEVICE_OS, DOGAREA_WIDGET_EVIDENCE_APP_BUILD`"), "existing widget markdown should summarize missing widget prefill env vars")

let markdownPath = tempRoot.appendingPathComponent("manual-blocker-status.md")
let markdownWriteOutput = runStatus(arguments: ["auth-smtp", "--markdown", "--output", markdownPath.path], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(markdownWriteOutput.contains("WROTE \(markdownPath.path)"), "markdown output mode should report written file")
let markdownFile = loadFile(markdownPath)
assertTrue(markdownFile.contains("## auth-smtp"), "written markdown report should render auth surface section")
assertTrue(markdownFile.contains("- Primary Issue: [#482]"), "written markdown report should render auth primary issue link")
assertTrue(markdownFile.contains("- Archive: `bash scripts/archive_manual_evidence_pack.sh auth-smtp"), "written markdown report should render archive command")

let authOutput = runStatus(arguments: ["auth-smtp"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(authOutput.contains("== auth-smtp =="), "runner should print auth-smtp header")
assertTrue(authOutput.contains("pack: \(authPath.path)"), "auth runner should print custom auth bundle path")
assertTrue(authOutput.contains("render_manual_evidence_pack.sh auth-smtp --output"), "auth runner should print auth render command")
assertTrue(authOutput.contains("next-prefill-existing: bash scripts/prefill_manual_evidence_pack.sh auth-smtp \(authPath.path)"), "auth runner should advertise auth prefill-existing command")
assertTrue(!authOutput.contains("next-apply-prefill:"), "missing auth bundle should not suggest apply-prefill before a pack exists")
assertTrue(authOutput.contains("--prefill-from-env"), "auth runner should prefer prefilled auth render command")
assertTrue(!authOutput.contains("--negative-guard"), "auth next command should not require negative guard flag")

let authGeneratedOutput = runStatus(arguments: ["auth-smtp", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(authGeneratedOutput.contains("gap-summary: 6 incomplete files"), "auth runner should summarize auth evidence by file count")
assertTrue(authGeneratedOutput.contains("next-fill: 01-dns-verification.md"), "auth runner should point to the first auth file to fill")
assertTrue(authGeneratedOutput.contains("next-prefill-env: bash scripts/print_manual_evidence_prefill_env.sh auth-smtp"), "auth runner should suggest env template when write-missing leaves env-backed gaps")
assertTrue(authGeneratedOutput.contains("next-prefill-bootstrap: source <(bash scripts/print_manual_evidence_prefill_env.sh auth-smtp) && bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill"), "auth runner should suggest one-shot bootstrap when write-missing leaves env-backed gaps")
assertTrue(authGeneratedOutput.contains("next-apply-prefill: bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill"), "auth runner should suggest apply-prefill when write-missing leaves env-backed metadata gaps")
assertTrue(authGeneratedOutput.contains("prefill-opportunity: metadata gaps detected in 2 files"), "auth runner should summarize auth metadata prefill opportunity")
assertTrue(authGeneratedOutput.contains("missing-prefill-env: DOGAREA_AUTH_SMTP_PROJECT, DOGAREA_AUTH_SMTP_PROVIDER, DOGAREA_AUTH_SMTP_SENDER_DOMAIN, DOGAREA_AUTH_SMTP_DNS_SPF, DOGAREA_AUTH_SMTP_DNS_DKIM, DOGAREA_AUTH_SMTP_DNS_DMARC, DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT, DOGAREA_AUTH_SMTP_HOST, DOGAREA_AUTH_SMTP_PORT, DOGAREA_AUTH_SMTP_USER_MASK, DOGAREA_AUTH_SMTP_SENDER_NAME, DOGAREA_AUTH_SMTP_SENDER_EMAIL, DOGAREA_AUTH_SMTP_EMAIL_SENT, DOGAREA_AUTH_SMTP_MAX_FREQUENCY, DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY, DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY, DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY, DOGAREA_AUTH_SMTP_INVITE_POLICY"), "auth runner should summarize missing auth prefill env vars")
assertTrue(authGeneratedOutput.contains("03-live-send-results.md: scenario rows, mailbox assets"), "auth runner should fold live-send scenario row errors into the live-send file")
assertTrue(!authGeneratedOutput.contains("signup confirmation: 1 gaps"), "auth runner should avoid scenario-only pseudo-file output")

let authExistingPath = tempRoot.appendingPathComponent("auth-existing")
_ = runStatus(arguments: ["auth-smtp", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authExistingPath.path,
])
let authUnappliedExistingOutput = runStatus(arguments: ["auth-smtp"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authExistingPath.path,
])
assertTrue(authUnappliedExistingOutput.contains("next-apply-prefill: bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill"), "existing auth bundles with metadata gaps should prioritize apply-prefill guidance")
assertTrue(authUnappliedExistingOutput.contains("next-prefill-env: bash scripts/print_manual_evidence_prefill_env.sh auth-smtp"), "existing auth bundles should advertise auth env template guidance")
assertTrue(authUnappliedExistingOutput.contains("next-prefill-bootstrap: source <(bash scripts/print_manual_evidence_prefill_env.sh auth-smtp) && bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill"), "existing auth bundles should advertise auth bootstrap guidance")
assertTrue(authUnappliedExistingOutput.contains("prefill-opportunity: metadata gaps detected in 2 files"), "existing auth bundles should summarize metadata prefill opportunity")
assertTrue(authUnappliedExistingOutput.contains("missing-prefill-env: DOGAREA_AUTH_SMTP_PROJECT, DOGAREA_AUTH_SMTP_PROVIDER, DOGAREA_AUTH_SMTP_SENDER_DOMAIN, DOGAREA_AUTH_SMTP_DNS_SPF, DOGAREA_AUTH_SMTP_DNS_DKIM, DOGAREA_AUTH_SMTP_DNS_DMARC, DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT, DOGAREA_AUTH_SMTP_HOST, DOGAREA_AUTH_SMTP_PORT, DOGAREA_AUTH_SMTP_USER_MASK, DOGAREA_AUTH_SMTP_SENDER_NAME, DOGAREA_AUTH_SMTP_SENDER_EMAIL, DOGAREA_AUTH_SMTP_EMAIL_SENT, DOGAREA_AUTH_SMTP_MAX_FREQUENCY, DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY, DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY, DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY, DOGAREA_AUTH_SMTP_INVITE_POLICY"), "existing auth bundles should summarize missing auth prefill env vars")

let authAppliedPath = tempRoot.appendingPathComponent("auth-applied")
_ = runStatus(arguments: ["auth-smtp", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authAppliedPath.path,
])
let authAppliedPrefillOutput = runStatus(arguments: ["auth-smtp", "--apply-prefill"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authAppliedPath.path,
    "DOGAREA_AUTH_SMTP_PROJECT": "ttjiknenynbhbpoqoesq",
    "DOGAREA_AUTH_SMTP_PROVIDER": "Resend",
    "DOGAREA_AUTH_SMTP_SENDER_DOMAIN": "auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_DNS_SPF": "pass",
    "DOGAREA_AUTH_SMTP_DNS_DKIM": "verified",
    "DOGAREA_AUTH_SMTP_DNS_DMARC": "present",
    "DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT": "2026-03-12T08:00:00Z",
    "DOGAREA_AUTH_SMTP_HOST": "smtp.resend.com",
    "DOGAREA_AUTH_SMTP_PORT": "587",
    "DOGAREA_AUTH_SMTP_USER_MASK": "re_***",
    "DOGAREA_AUTH_SMTP_SENDER_NAME": "DogArea Auth",
    "DOGAREA_AUTH_SMTP_SENDER_EMAIL": "auth@auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_EMAIL_SENT": "12",
    "DOGAREA_AUTH_SMTP_MAX_FREQUENCY": "90",
    "DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY": "required",
    "DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY": "enabled / app deep link",
    "DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY": "double confirmation",
    "DOGAREA_AUTH_SMTP_INVITE_POLICY": "disabled in product",
])
assertTrue(authAppliedPrefillOutput.contains("01-dns-verification.md: asset"), "apply-prefill should reduce auth metadata gaps for existing bundles")
assertTrue(authAppliedPrefillOutput.contains("02-supabase-smtp-settings.md: asset"), "apply-prefill should reduce auth smtp settings gaps for existing bundles")
assertTrue(!authAppliedPrefillOutput.contains("01-dns-verification.md: dns metadata, asset"), "apply-prefill should remove auth dns metadata gaps for existing bundles")

let authExistingMarkdownOutput = runStatus(arguments: ["auth-smtp", "--markdown"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authExistingPath.path,
])
assertTrue(authExistingMarkdownOutput.contains("- Apply Prefill Then Refresh: `bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill`"), "existing auth markdown should suggest apply-prefill first")
assertTrue(authExistingMarkdownOutput.contains("- Print Prefill Env Template: `bash scripts/print_manual_evidence_prefill_env.sh auth-smtp`"), "existing auth markdown should suggest env template first")
assertTrue(authExistingMarkdownOutput.contains("- Bootstrap Prefill In One Shot: `source <(bash scripts/print_manual_evidence_prefill_env.sh auth-smtp) && bash scripts/manual_blocker_evidence_status.sh auth-smtp --apply-prefill`"), "existing auth markdown should suggest bootstrap command")
assertTrue(authExistingMarkdownOutput.contains("- Prefill Opportunity: metadata gaps in `2` files"), "existing auth markdown should summarize metadata-prefill opportunity")
assertTrue(authExistingMarkdownOutput.contains("- Missing Prefill Env: `DOGAREA_AUTH_SMTP_PROJECT, DOGAREA_AUTH_SMTP_PROVIDER, DOGAREA_AUTH_SMTP_SENDER_DOMAIN, DOGAREA_AUTH_SMTP_DNS_SPF, DOGAREA_AUTH_SMTP_DNS_DKIM, DOGAREA_AUTH_SMTP_DNS_DMARC, DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT, DOGAREA_AUTH_SMTP_HOST, DOGAREA_AUTH_SMTP_PORT, DOGAREA_AUTH_SMTP_USER_MASK, DOGAREA_AUTH_SMTP_SENDER_NAME, DOGAREA_AUTH_SMTP_SENDER_EMAIL, DOGAREA_AUTH_SMTP_EMAIL_SENT, DOGAREA_AUTH_SMTP_MAX_FREQUENCY, DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY, DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY, DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY, DOGAREA_AUTH_SMTP_INVITE_POLICY`"), "existing auth markdown should summarize missing auth prefill env vars")
assertTrue(!authOutput.contains("--negative-provider-event"), "auth next command should not require provider event flag")

print("PASS: manual blocker evidence status runner contract checks")
