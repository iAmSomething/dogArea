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

/// Asserts that a condition holds for the manual evidence helper contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs the evidence helper script and captures stdout/stderr.
/// - Parameter arguments: Arguments passed to the script.
/// - Returns: Combined UTF-8 output from the launched process.
func runHelper(arguments: [String]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/render_manual_evidence_pack.sh"] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch helper: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        fputs("Helper failed with status \(process.terminationStatus)\n\(output)\n", stderr)
        exit(1)
    }

    return output
}

let helperScript = load("scripts/render_manual_evidence_pack.sh")
let helperDoc = load("docs/manual-evidence-helper-v1.md")
let widgetRunbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let authRunbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(helperScript.contains("widget|auth-smtp"), "helper usage should define both modes")
assertTrue(helperScript.contains(".codex_tmp/widget-action-evidence-pack.md"), "helper should define widget default output")
assertTrue(helperScript.contains(".codex_tmp/auth-smtp-evidence-pack.md"), "helper should define auth smtp default output")
assertTrue(helperDoc.contains("bash scripts/render_manual_evidence_pack.sh widget"), "doc should include widget usage")
assertTrue(helperDoc.contains("bash scripts/render_manual_evidence_pack.sh auth-smtp"), "doc should include auth-smtp usage")
assertTrue(widgetRunbook.contains("render_manual_evidence_pack.sh"), "widget runbook should mention helper")
assertTrue(authRunbook.contains("render_manual_evidence_pack.sh"), "auth smtp runbook should mention helper")
assertTrue(readme.contains("docs/manual-evidence-helper-v1.md"), "README should link helper doc")
assertTrue(iosPRCheck.contains("manual_evidence_helper_unit_check.swift"), "ios_pr_check should run helper check")
assertTrue(backendPRCheck.contains("manual_evidence_helper_unit_check.swift"), "backend_pr_check should run helper check")

let widgetOutput = runHelper(arguments: ["widget"])
assertTrue(widgetOutput.contains("# Widget Action Evidence Pack v1"), "widget output should include title")
assertTrue(widgetOutput.contains("docs/widget-action-real-device-evidence-template-v1.md"), "widget output should include template path")
assertTrue(widgetOutput.contains("docs/widget-action-closure-comment-template-v1.md"), "widget output should include closure template path")
assertTrue(widgetOutput.contains("## Evidence Template"), "widget output should include evidence section")
assertTrue(widgetOutput.contains("## Closure Comment Template"), "widget output should include closure section")

let authOutput = runHelper(arguments: ["auth-smtp"])
assertTrue(authOutput.contains("# Auth SMTP Evidence Pack v1"), "auth output should include title")
assertTrue(authOutput.contains("docs/auth-smtp-rollout-evidence-template-v1.md"), "auth output should include template path")
assertTrue(authOutput.contains("docs/auth-smtp-closure-comment-template-v1.md"), "auth output should include closure template path")

let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
let tempOutputURL = tempDirectory.appendingPathComponent("manual-evidence-pack-test.md")
let writeOutput = runHelper(arguments: ["widget", "--output", tempOutputURL.path])
assertTrue(writeOutput.contains("WROTE \(tempOutputURL.path)"), "write mode should report output path")
let writtenText = (try? String(contentsOf: tempOutputURL, encoding: .utf8)) ?? ""
assertTrue(writtenText.contains("# Widget Action Evidence Pack v1"), "written file should include widget title")
assertTrue(writtenText.contains("docs/widget-action-real-device-evidence-template-v1.md"), "written file should include widget template path")

print("PASS: manual evidence helper contract checks")
