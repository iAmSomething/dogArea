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
assertTrue(runnerScript.contains("gap-summary:"), "runner should print plain gap summaries for incomplete packs")
assertTrue(runnerScript.contains("next-fill:"), "runner should print next-fill guidance")
assertTrue(runnerScript.contains("### Gap Summary"), "runner should print markdown gap summaries for incomplete packs")
assertTrue(runnerScript.contains("widget --output %q --prefill-from-env"), "runner should prefer prefilled widget render commands")
assertTrue(runnerScript.contains("--prefill-from-env"), "runner should use auth smtp env prefill render path")
assertTrue(doc.contains("primary `#731`, related `#617`, `#692`"), "doc should describe active widget blocker routing")
assertTrue(doc.contains("widget-real-device-evidence"), "doc should mention widget directory path")
assertTrue(doc.contains("next-archive"), "doc should describe archive command")
assertTrue(doc.contains("next-prefill-existing"), "doc should describe prefill-existing command")
assertTrue(doc.contains("next-post-closure-bundle"), "doc should describe bundled widget post command")
assertTrue(doc.contains("Manual Blocker Evidence Status Report"), "doc should describe markdown report title")
assertTrue(doc.contains("--markdown"), "doc should describe markdown mode")
assertTrue(doc.contains("--output"), "doc should describe output export")
assertTrue(doc.contains("--raw-errors"), "doc should describe raw error output mode")
assertTrue(doc.contains("gap-summary"), "doc should describe plain gap summary output")
assertTrue(doc.contains("next-fill"), "doc should describe next-fill guidance")
assertTrue(doc.contains("### Gap Summary"), "doc should describe markdown gap summary heading")
assertTrue(doc.contains("03-live-send-results.md"), "doc should describe auth-smtp file-level scenario row grouping")
assertTrue(doc.contains("--prefill-from-env"), "doc should describe auth smtp prefill render command")
assertTrue(readme.contains("docs/manual-blocker-evidence-status-runner-v1.md"), "README should link runner doc")
assertTrue(iosPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "ios_pr_check should run blocker runner check")
assertTrue(backendPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "backend_pr_check should run blocker runner check")

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetPath = tempRoot.appendingPathComponent("widget")
let authPath = tempRoot.appendingPathComponent("auth")

let missingOutput = runStatus(arguments: ["widget"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(missingOutput.contains("== widget =="), "runner should print widget header")
assertTrue(missingOutput.contains("status: missing"), "runner should mark missing widget evidence")
assertTrue(missingOutput.contains("issue: #731 (skipped)"), "runner should print active widget primary issue")
assertTrue(missingOutput.contains("related-issues: #617 #692"), "runner should print related widget issues")

let generatedOutput = runStatus(arguments: ["widget", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 16 / iOS 18.5",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.1",
])
assertTrue(FileManager.default.fileExists(atPath: widgetPath.appendingPathComponent("action/WD-001.md").path), "write-missing should create widget action cases")
assertTrue(generatedOutput.contains("status: incomplete"), "generated widget bundle should still be incomplete until filled")
assertTrue(generatedOutput.contains("next-render: bash scripts/render_manual_evidence_pack.sh widget --output \(widgetPath.path) --prefill-from-env"), "generated widget bundle should advertise prefilled widget render command")
assertTrue(generatedOutput.contains("next-prefill-existing: bash scripts/prefill_manual_evidence_pack.sh widget \(widgetPath.path)"), "generated widget bundle should advertise widget prefill-existing command")
assertTrue(generatedOutput.contains("gap-summary: 16 incomplete cases (action 8, layout 8, total-errors 120)"), "generated widget bundle should summarize reduced incomplete case counts after metadata prefill")
assertTrue(generatedOutput.contains("next-fill: action/WD-001.md"), "generated widget bundle should point at the first case to fill")
assertTrue(generatedOutput.contains("gap-cases:"), "generated widget bundle should print case bucket list")
assertTrue(generatedOutput.contains("WD-001: result, assets, placeholder logs"), "generated widget bundle should dedupe case buckets after metadata prefill")
assertTrue(generatedOutput.contains("WL-001: result, assets"), "generated widget bundle should reduce layout gaps after metadata prefill")
assertTrue(!generatedOutput.contains("empty value:"), "generated widget bundle should hide raw validator errors by default")

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
])
assertTrue(completeOutput.contains("status: complete"), "filled widget evidence should be reported as complete")
assertTrue(completeOutput.contains("render_closure_comment_from_evidence.sh widget"), "runner should print widget closure render command")
assertTrue(completeOutput.contains("archive_manual_evidence_pack.sh widget"), "runner should print widget archive command")
assertTrue(completeOutput.contains("next-post-closure-bundle: bash scripts/post_closure_comment_from_evidence.sh widget --all-related"), "runner should print bundled widget post command")
assertTrue(!completeOutput.contains("gap-summary:"), "complete widget evidence should not print a gap summary")

let markdownOutput = runStatus(arguments: ["widget", "--markdown"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(markdownOutput.contains("# Manual Blocker Evidence Status Report"), "markdown mode should print report title")
assertTrue(markdownOutput.contains("## widget"), "markdown mode should render widget section")
assertTrue(markdownOutput.contains("- Primary Issue: [#731]"), "markdown mode should render primary issue link")
assertTrue(markdownOutput.contains("- Prefill Existing: `bash scripts/prefill_manual_evidence_pack.sh widget"), "markdown mode should render widget prefill-existing command")
assertTrue(markdownOutput.contains("- Post Closure Bundle: `bash scripts/post_closure_comment_from_evidence.sh widget --all-related"), "markdown mode should render bundled post command")
assertTrue(!markdownOutput.contains("### Gap Summary"), "complete widget markdown should not print a gap summary")

let incompleteMarkdownOutput = runStatus(arguments: ["widget", "--markdown", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": tempRoot.appendingPathComponent("widget-incomplete").path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 16 / iOS 18.5",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.1",
])
assertTrue(incompleteMarkdownOutput.contains("### Gap Summary"), "incomplete widget markdown should print a gap summary")
assertTrue(incompleteMarkdownOutput.contains("- Next Fill: `action/WD-001.md`"), "incomplete widget markdown should print next-fill guidance")
assertTrue(incompleteMarkdownOutput.contains("- Incomplete Cases: `16` (`action 8`, `layout 8`, `errors 120`)"), "incomplete widget markdown should reflect reduced error count after metadata prefill")

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
assertTrue(authOutput.contains("--prefill-from-env"), "auth runner should prefer prefilled auth render command")
assertTrue(!authOutput.contains("--negative-guard"), "auth next command should not require negative guard flag")

let authGeneratedOutput = runStatus(arguments: ["auth-smtp", "--write-missing"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(authGeneratedOutput.contains("gap-summary: 6 incomplete files"), "auth runner should summarize auth evidence by file count")
assertTrue(authGeneratedOutput.contains("next-fill: 01-dns-verification.md"), "auth runner should point to the first auth file to fill")
assertTrue(authGeneratedOutput.contains("03-live-send-results.md: scenario rows, mailbox assets"), "auth runner should fold live-send scenario row errors into the live-send file")
assertTrue(!authGeneratedOutput.contains("signup confirmation: 1 gaps"), "auth runner should avoid scenario-only pseudo-file output")
assertTrue(!authOutput.contains("--negative-provider-event"), "auth next command should not require provider event flag")

print("PASS: manual blocker evidence status runner contract checks")
