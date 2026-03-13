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
/// - Parameters:
///   - arguments: Arguments passed to the script.
///   - environment: Extra environment variables for the subprocess.
/// - Returns: Combined UTF-8 output from the launched process.
func runHelper(arguments: [String], environment: [String: String] = [:]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/render_manual_evidence_pack.sh"] + arguments

    var env = ProcessInfo.processInfo.environment
    environment.forEach { env[$0.key] = $0.value }
    process.environment = env

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
assertTrue(helperScript.contains("--prefill-from-env"), "helper should expose auth smtp env prefill option")
assertTrue(helperScript.contains("manual_evidence_prefill_sources.sh"), "helper should source shared widget prefill helpers")
assertTrue(helperScript.contains("apply_widget_prefill_metadata"), "helper should still apply widget prefill metadata")
assertTrue(helperDoc.contains("widget-real-device-evidence"), "helper doc should include widget directory path")
assertTrue(helperDoc.contains("auth-smtp --write --prefill-from-env"), "helper doc should explain auth smtp env prefill path")
assertTrue(helperDoc.contains("widget --write --prefill-from-env"), "helper doc should explain widget env prefill path")
assertTrue(helperDoc.contains("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS"), "helper doc should list widget env prefill keys")
assertTrue(helperDoc.contains("auto-detect fallback"), "helper doc should document widget auto-detect fallback")
assertTrue(helperDoc.contains("action/WD-001.md"), "helper doc should mention action case files")
assertTrue(helperDoc.contains("layout/WL-001.md"), "helper doc should mention layout case files")
assertTrue(widgetRunbook.contains("render_manual_evidence_pack.sh"), "widget action runbook should mention helper")
assertTrue(widgetRunbook.contains("--prefill-from-env"), "widget action runbook should mention prefill helper path")
assertTrue(widgetRunbook.contains("DOGAREA_WIDGET_EVIDENCE_APP_BUILD"), "widget action runbook should list widget env prefill keys")
assertTrue(layoutRunbook.contains("render_manual_evidence_pack.sh"), "widget layout runbook should mention helper")
assertTrue(layoutRunbook.contains("--prefill-from-env"), "widget layout runbook should mention prefill helper path")
assertTrue(layoutRunbook.contains("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS"), "widget layout runbook should list widget env prefill keys")
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
assertTrue(authOutput.contains("# Auth SMTP Evidence Bundle v2"), "auth output should include title")
assertTrue(authOutput.contains("01-dns-verification.md"), "auth output should describe dns bundle file")
assertTrue(authOutput.contains("06-final-decision.md"), "auth output should describe final decision file")

let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let writeOutput = runHelper(arguments: ["widget", "--output", tempDirectory.path])
assertTrue(writeOutput.contains("WROTE \(tempDirectory.path)"), "write mode should report output path")
let bundleReadme = (try? String(contentsOf: tempDirectory.appendingPathComponent("README.md"), encoding: .utf8)) ?? ""
assertTrue(bundleReadme.contains("Widget Real-Device Evidence Pack v2"), "written widget bundle should include readme")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("action/WD-001.md").path), "written widget bundle should include WD-001")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("layout/WL-008.md").path), "written widget bundle should include WL-008")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("assets/action").path), "written widget bundle should include action assets directory")
assertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("assets/layout").path), "written widget bundle should include layout assets directory")

let prefilledWidgetDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let prefilledWidgetOutput = runHelper(arguments: ["widget", "--output", prefilledWidgetDirectory.path, "--prefill-from-env"], environment: [
    "DOGAREA_DISABLE_WIDGET_PREFILL_AUTODETECT": "1",
    "DOGAREA_WIDGET_EVIDENCE_DATE": "2026-03-12",
    "DOGAREA_WIDGET_EVIDENCE_TESTER": "codex",
    "DOGAREA_WIDGET_PREFILL_DEVICE_OS_STUB": "iPhone 14 / iOS 18.7.3",
    "DOGAREA_WIDGET_PREFILL_APP_BUILD_STUB": "1.0 (14)",
])
assertTrue(prefilledWidgetOutput.contains("WROTE \(prefilledWidgetDirectory.path)"), "prefilled widget write mode should report output path")
let prefilledAction = (try? String(contentsOf: prefilledWidgetDirectory.appendingPathComponent("action/WD-001.md"), encoding: .utf8)) ?? ""
let prefilledLayout = (try? String(contentsOf: prefilledWidgetDirectory.appendingPathComponent("layout/WL-001.md"), encoding: .utf8)) ?? ""
assertTrue(prefilledAction.contains("- Date: 2026-03-12"), "prefilled widget bundle should include date metadata")
assertTrue(prefilledAction.contains("- Tester: codex"), "prefilled widget bundle should include tester metadata")
assertTrue(prefilledAction.contains("- Device / OS: iPhone 14 / iOS 18.7.3"), "prefilled widget bundle should include device metadata from stub/autodetect source")
assertTrue(prefilledAction.contains("- App Build: 1.0 (14)"), "prefilled widget bundle should include app build metadata from stub/autodetect source")
assertTrue(prefilledLayout.contains("- Tester: codex"), "prefilled widget layout bundle should include tester metadata")

let authDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let authWriteOutput = runHelper(arguments: ["auth-smtp", "--output", authDirectory.path])
assertTrue(authWriteOutput.contains("WROTE \(authDirectory.path)"), "auth write mode should report output path")
let authReadme = (try? String(contentsOf: authDirectory.appendingPathComponent("README.md"), encoding: .utf8)) ?? ""
assertTrue(authReadme.contains("Auth SMTP Evidence Bundle v2"), "written auth bundle should include readme")
assertTrue(FileManager.default.fileExists(atPath: authDirectory.appendingPathComponent("01-dns-verification.md").path), "written auth bundle should include dns file")
assertTrue(FileManager.default.fileExists(atPath: authDirectory.appendingPathComponent("06-final-decision.md").path), "written auth bundle should include final decision file")
assertTrue(FileManager.default.fileExists(atPath: authDirectory.appendingPathComponent("assets/README.md").path), "written auth bundle should include assets readme")

let prefilledAuthDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
setenv("DOGAREA_AUTH_SMTP_PROJECT", "ttjiknenynbhbpoqoesq", 1)
setenv("DOGAREA_AUTH_SMTP_PROVIDER", "Resend", 1)
setenv("DOGAREA_AUTH_SMTP_SENDER_DOMAIN", "auth.dogarea.app", 1)
setenv("DOGAREA_AUTH_SMTP_HOST", "smtp.resend.com", 1)
setenv("DOGAREA_AUTH_SMTP_PORT", "587", 1)
setenv("DOGAREA_AUTH_SMTP_USER_MASK", "re_***", 1)
setenv("DOGAREA_AUTH_SMTP_SENDER_NAME", "DogArea Auth", 1)
setenv("DOGAREA_AUTH_SMTP_SENDER_EMAIL", "auth@auth.dogarea.app", 1)
setenv("DOGAREA_AUTH_SMTP_EMAIL_SENT", "12", 1)
setenv("DOGAREA_AUTH_SMTP_MAX_FREQUENCY", "90", 1)
setenv("DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY", "required", 1)
setenv("DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY", "enabled / app deep link", 1)
setenv("DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY", "double confirmation", 1)
setenv("DOGAREA_AUTH_SMTP_INVITE_POLICY", "disabled in product", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_SPF", "pass", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_DKIM", "verified", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_DMARC", "present", 1)

let prefilledAuthOutput = runHelper(arguments: ["auth-smtp", "--output", prefilledAuthDirectory.path, "--prefill-from-env"])
assertTrue(prefilledAuthOutput.contains("WROTE \(prefilledAuthDirectory.path)"), "prefilled auth write mode should report output path")
let prefilledDNS = (try? String(contentsOf: prefilledAuthDirectory.appendingPathComponent("01-dns-verification.md"), encoding: .utf8)) ?? ""
let prefilledSettings = (try? String(contentsOf: prefilledAuthDirectory.appendingPathComponent("02-supabase-smtp-settings.md"), encoding: .utf8)) ?? ""
assertTrue(prefilledDNS.contains("- Provider: Resend"), "prefilled auth bundle should include provider metadata")
assertTrue(prefilledDNS.contains("- DKIM: verified"), "prefilled auth bundle should include DNS claims")
assertTrue(prefilledSettings.contains("- SMTP Host: smtp.resend.com"), "prefilled auth bundle should include smtp host")
assertTrue(prefilledSettings.contains("- `email_sent`: 12"), "prefilled auth bundle should include email_sent")
assertTrue(prefilledSettings.contains("- Email Change Policy: double confirmation"), "prefilled auth bundle should include email change policy")

print("PASS: manual evidence helper contract checks")
