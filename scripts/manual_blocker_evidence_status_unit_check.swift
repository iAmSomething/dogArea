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
assertTrue(runnerScript.contains("next-post-closure-bundle"), "runner should print bundled widget post command")
assertTrue(doc.contains("primary `#731`, related `#617`, `#692`"), "doc should describe active widget blocker routing")
assertTrue(doc.contains("widget-real-device-evidence"), "doc should mention widget directory path")
assertTrue(doc.contains("next-archive"), "doc should describe archive command")
assertTrue(doc.contains("next-post-closure-bundle"), "doc should describe bundled widget post command")
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
])
assertTrue(FileManager.default.fileExists(atPath: widgetPath.appendingPathComponent("action/WD-001.md").path), "write-missing should create widget action cases")
assertTrue(generatedOutput.contains("status: incomplete"), "generated widget bundle should still be incomplete until filled")

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

let authOutput = runStatus(arguments: ["auth-smtp"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
])
assertTrue(authOutput.contains("== auth-smtp =="), "runner should print auth-smtp header")
assertTrue(authOutput.contains("pack: \(authPath.path)"), "auth runner should print custom auth bundle path")
assertTrue(!authOutput.contains("--negative-guard"), "auth next command should not require negative guard flag")
assertTrue(!authOutput.contains("--negative-provider-event"), "auth next command should not require provider event flag")

print("PASS: manual blocker evidence status runner contract checks")
