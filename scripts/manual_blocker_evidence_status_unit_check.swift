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

/// Builds a widget evidence file that satisfies the existing validator contract.
/// - Returns: Filled widget evidence markdown content.
func filledWidgetEvidence() -> String {
    let template = load("docs/widget-action-real-device-evidence-template-v1.md")
    return template
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-11")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.11.1")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemMedium")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: WD-001")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: cold start")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://rival")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: rival tab opens")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: rival tab opened")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: RivalTab")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] action=rival request_id=req-1")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: widget://rival")
        .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded consumed=rival")
        .replacingOccurrences(of: "request_id=...", with: "request_id=req-1")
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: AppIntent fired")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: Root route consumed")
}

let runnerScript = load("scripts/manual_blocker_evidence_status.sh")
let doc = load("docs/manual-blocker-evidence-status-runner-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(runnerScript.contains("widget|auth-smtp"), "runner should support both blocker surfaces in usage")
assertTrue(runnerScript.contains("DOGAREA_WIDGET_EVIDENCE_PATH"), "runner should support widget evidence path override")
assertTrue(runnerScript.contains("DOGAREA_AUTH_SMTP_EVIDENCE_PATH"), "runner should support auth evidence path override")
assertTrue(runnerScript.contains("--write-missing"), "runner should support write-missing mode")
assertTrue(doc.contains("manual_blocker_evidence_status.sh"), "doc should mention runner command")
assertTrue(doc.contains("status: complete"), "doc should describe complete state")
assertTrue(readme.contains("docs/manual-blocker-evidence-status-runner-v1.md"), "README should link runner doc")
assertTrue(readme.contains("bash scripts/manual_blocker_evidence_status.sh"), "README should include runner command")
assertTrue(iosPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "ios_pr_check should run blocker runner check")
assertTrue(backendPRCheck.contains("manual_blocker_evidence_status_unit_check.swift"), "backend_pr_check should run blocker runner check")

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetPath = tempRoot.appendingPathComponent("widget.md")
let authPath = tempRoot.appendingPathComponent("auth.md")

let missingOutput = runStatus(
    arguments: ["widget"],
    environment: [
        "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
        "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    ]
)
assertTrue(missingOutput.contains("== widget =="), "runner should print widget header")
assertTrue(missingOutput.contains("status: missing"), "runner should mark missing widget evidence")
assertTrue(missingOutput.contains("next-render:"), "runner should print next render command")

let generatedOutput = runStatus(
    arguments: ["widget", "--write-missing"],
    environment: [
        "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
        "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    ]
)
assertTrue(FileManager.default.fileExists(atPath: widgetPath.path), "write-missing should create widget evidence pack")
assertTrue(generatedOutput.contains("status: incomplete"), "generated template should still be incomplete until filled")

write(widgetPath, content: filledWidgetEvidence())
let completeOutput = runStatus(
    arguments: ["widget"],
    environment: [
        "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
        "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    ]
)
assertTrue(completeOutput.contains("status: complete"), "filled widget evidence should be reported as complete")
assertTrue(completeOutput.contains("render_closure_comment_from_evidence.sh widget"), "runner should print widget closure render command")

let authOutput = runStatus(
    arguments: ["auth-smtp"],
    environment: [
        "DOGAREA_WIDGET_EVIDENCE_PATH": widgetPath.path,
        "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": authPath.path,
    ]
)
assertTrue(authOutput.contains("== auth-smtp =="), "runner should print auth-smtp header")
assertTrue(authOutput.contains("--negative-guard"), "auth next command should include negative guard placeholder")
assertTrue(authOutput.contains("--negative-provider-event"), "auth next command should include provider event placeholder")

print("PASS: manual blocker evidence status runner contract checks")
