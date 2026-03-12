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

/// Asserts that a condition holds for the prefill env printer contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs a shell script from the repository root and returns combined output.
/// - Parameters:
///   - script: Repository-relative script path.
///   - arguments: CLI arguments passed to the script.
///   - environment: Extra environment variables for the subprocess.
/// - Returns: Combined stdout and stderr.
func runScript(_ script: String, arguments: [String], environment: [String: String] = [:]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script] + arguments

    var env = ProcessInfo.processInfo.environment
    environment.forEach { env[$0.key] = $0.value }
    process.environment = env

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch \(script): \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        fputs("Script failed with status \(process.terminationStatus)\n\(output)\n", stderr)
        exit(1)
    }

    return output
}

let printerScript = load("scripts/print_manual_evidence_prefill_env.sh")
let prefillDoc = load("docs/manual-evidence-prefill-v1.md")
let helperDoc = load("docs/manual-evidence-helper-v1.md")
let statusDoc = load("docs/manual-blocker-evidence-status-runner-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(printerScript.contains("widget|auth-smtp"), "printer script should support widget and auth-smtp")
assertTrue(printerScript.contains("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS"), "printer script should print widget env exports")
assertTrue(printerScript.contains("DOGAREA_AUTH_SMTP_PROJECT"), "printer script should print auth-smtp env exports")
assertTrue(prefillDoc.contains("print_manual_evidence_prefill_env.sh"), "prefill doc should reference env printer")
assertTrue(helperDoc.contains("print_manual_evidence_prefill_env.sh"), "helper doc should reference env printer")
assertTrue(statusDoc.contains("next-prefill-env"), "status doc should mention prefill env guidance")
assertTrue(readme.contains("docs/manual-evidence-prefill-v1.md"), "README should reference env printer doc")
assertTrue(iosPRCheck.contains("manual_evidence_prefill_env_printer_unit_check.swift"), "ios_pr_check should run env printer check")
assertTrue(backendPRCheck.contains("manual_evidence_prefill_env_printer_unit_check.swift"), "backend_pr_check should run env printer check")

let defaultWidgetOutput = runScript("scripts/print_manual_evidence_prefill_env.sh", arguments: ["widget"])
assertTrue(defaultWidgetOutput.contains("# widget prefill env"), "widget env printer should label widget block")
assertTrue(defaultWidgetOutput.contains("export DOGAREA_WIDGET_EVIDENCE_DEVICE_OS="), "widget env printer should include device os export")
assertTrue(defaultWidgetOutput.contains("export DOGAREA_WIDGET_EVIDENCE_APP_BUILD="), "widget env printer should include app build export")

let customWidgetOutput = runScript("scripts/print_manual_evidence_prefill_env.sh", arguments: ["widget"], environment: [
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_EVIDENCE_DEVICE_OS": "iPhone 17 / iOS 18.6",
    "DOGAREA_WIDGET_EVIDENCE_APP_BUILD": "2026.03.12.9",
])
assertTrue(customWidgetOutput.contains("export DOGAREA_WIDGET_EVIDENCE_DEVICE_OS=iPhone\\ 17\\ /\\ iOS\\ 18.6"), "widget env printer should use current env values")
assertTrue(customWidgetOutput.contains("export DOGAREA_WIDGET_EVIDENCE_APP_BUILD=2026.03.12.9"), "widget env printer should use current app build env value")

let defaultAuthOutput = runScript("scripts/print_manual_evidence_prefill_env.sh", arguments: ["auth-smtp"])
assertTrue(defaultAuthOutput.contains("# auth-smtp prefill env"), "auth env printer should label auth block")
assertTrue(defaultAuthOutput.contains("export DOGAREA_AUTH_SMTP_PROJECT=ttjiknenynbhbpoqoesq"), "auth env printer should include project export")
assertTrue(defaultAuthOutput.contains("export DOGAREA_AUTH_SMTP_PROVIDER=Resend"), "auth env printer should include provider export")

let customAuthOutput = runScript("scripts/print_manual_evidence_prefill_env.sh", arguments: ["auth-smtp"], environment: [
    "DOGAREA_AUTH_SMTP_PROVIDER": "Mailgun",
    "DOGAREA_AUTH_SMTP_SENDER_EMAIL": "auth@mailer.dogarea.app",
    "DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY": "enabled / universal link",
])
assertTrue(customAuthOutput.contains("export DOGAREA_AUTH_SMTP_PROVIDER=Mailgun"), "auth env printer should use current provider env value")
assertTrue(customAuthOutput.contains("export DOGAREA_AUTH_SMTP_SENDER_EMAIL=auth@mailer.dogarea.app"), "auth env printer should use current sender email env value")
assertTrue(customAuthOutput.contains("export DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY=enabled\\ /\\ universal\\ link"), "auth env printer should shell-quote spaced values")

print("PASS: manual evidence prefill env printer contract checks")
