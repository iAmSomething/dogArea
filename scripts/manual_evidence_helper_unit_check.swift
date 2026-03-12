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
let layoutRunbook = load("docs/widget-family-real-device-evidence-runbook-v1.md")
let authRunbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(helperScript.contains("widget|auth-smtp"), "helper usage should define both modes")
assertTrue(helperScript.contains(".codex_tmp/widget-real-device-evidence"), "helper should define widget directory default output")
assertTrue(helperScript.contains("write_widget_bundle"), "helper should generate widget bundle")
assertTrue(helperDoc.contains("widget-real-device-evidence"), "helper doc should include widget directory path")
assertTrue(helperDoc.contains("action/WD-001.md"), "helper doc should mention action case files")
assertTrue(helperDoc.contains("layout/WL-001.md"), "helper doc should mention layout case files")
assertTrue(widgetRunbook.contains("render_manual_evidence_pack.sh"), "widget action runbook should mention helper")
assertTrue(layoutRunbook.contains("render_manual_evidence_pack.sh"), "widget layout runbook should mention helper")
assertTrue(authRunbook.contains("render_manual_evidence_pack.sh"), "auth runbook should mention helper")
assertTrue(readme.contains("docs/manual-evidence-helper-v1.md"), "README should link helper doc")
assertTrue(iosPRCheck.contains("manual_evidence_helper_unit_check.swift"), "ios_pr_check should run helper check")
assertTrue(backendPRCheck.contains("manual_evidence_helper_unit_check.swift"), "backend_pr_check should run helper check")

let widgetOutput = runHelper(arguments: ["widget"])
assertTrue(widgetOutput.contains("# Widget Real-Device Evidence Pack v2"), "widget output should include title")
assertTrue(widgetOutput.contains("docs/widget-family-real-device-validation-matrix-v1.md"), "widget output should include layout matrix path")
assertTrue(widgetOutput.contains("action/WD-001.md"), "widget output should mention action files")
assertTrue(widgetOutput.contains("layout/WL-001.md"), "widget output should mention layout files")

let authOutput = runHelper(arguments: ["auth-smtp"])
assertTrue(authOutput.contains("# Auth SMTP Evidence Pack v1"), "auth output should include title")
assertTrue(authOutput.contains("docs/auth-smtp-rollout-evidence-template-v1.md"), "auth output should include template path")

let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let writeOutput = runHelper(arguments: ["widget", "--output", tempDirectory.path])
assertTrue(writeOutput.contains("WROTE \(tempDirectory.path)"), "write mode should report output path")
let bundleReadme = (try? String(contentsOf: tempDirectory.appendingPathComponent("README.md"), encoding: .utf8)) ?? ""
assertTrue(bundleReadme.contains("Widget Real-Device Evidence Pack v2"), "written widget bundle should include readme")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("action/WD-001.md").path), "written widget bundle should include WD-001")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("layout/WL-008.md").path), "written widget bundle should include WL-008")

print("PASS: manual evidence helper contract checks")
