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

/// Asserts that a condition holds for the manual evidence prefill contract.
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
/// - Returns: Combined stdout and stderr.
func runScript(_ script: String, arguments: [String]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script] + arguments

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

/// Loads a UTF-8 text file from an absolute URL.
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

let prefillScript = load("scripts/prefill_manual_evidence_pack.sh")
let prefillDoc = load("docs/manual-evidence-prefill-v1.md")
let helperDoc = load("docs/manual-evidence-helper-v1.md")
let statusDoc = load("docs/manual-blocker-evidence-status-runner-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(prefillScript.contains("widget|auth-smtp"), "prefill script should support widget and auth-smtp")
assertTrue(prefillScript.contains("fill_prefixed_value_if_empty"), "prefill script should only fill empty prefixed lines")
assertTrue(prefillScript.contains("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS"), "prefill script should support widget env values")
assertTrue(prefillScript.contains("DOGAREA_AUTH_SMTP_PROJECT"), "prefill script should support auth smtp env values")
assertTrue(prefillDoc.contains("next-prefill-existing"), "prefill doc should describe status runner integration")
assertTrue(helperDoc.contains("prefill_manual_evidence_pack.sh"), "helper doc should reference prefill script")
assertTrue(statusDoc.contains("next-prefill-existing"), "status doc should describe prefill command")
assertTrue(readme.contains("prefill_manual_evidence_pack.sh"), "README should reference prefill script")
assertTrue(iosPRCheck.contains("manual_evidence_prefill_unit_check.swift"), "ios_pr_check should run prefill check")
assertTrue(backendPRCheck.contains("manual_evidence_prefill_unit_check.swift"), "backend_pr_check should run prefill check")

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetPath = tempRoot.appendingPathComponent("widget")
let authPath = tempRoot.appendingPathComponent("auth")

_ = runScript("scripts/render_manual_evidence_pack.sh", arguments: ["widget", "--output", widgetPath.path])
setenv("DOGAREA_WIDGET_EVIDENCE_DATE", "2026-03-12", 1)
setenv("DOGAREA_WIDGET_EVIDENCE_TESTER", "codex", 1)
setenv("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS", "iPhone 16 / iOS 18.5", 1)
setenv("DOGAREA_WIDGET_EVIDENCE_APP_BUILD", "2026.03.12.1", 1)
let widgetPrefillOutput = runScript("scripts/prefill_manual_evidence_pack.sh", arguments: ["widget", widgetPath.path])
assertTrue(widgetPrefillOutput.contains("PREFILLED widget"), "widget prefill should report completion")
let widgetAction = loadFile(widgetPath.appendingPathComponent("action/WD-001.md"))
let widgetLayout = loadFile(widgetPath.appendingPathComponent("layout/WL-001.md"))
assertTrue(widgetAction.contains("- Date: 2026-03-12"), "widget prefill should fill date metadata")
assertTrue(widgetAction.contains("- Tester: codex"), "widget prefill should fill tester metadata")
assertTrue(widgetAction.contains("- Device / OS: iPhone 16 / iOS 18.5"), "widget prefill should fill device metadata")
assertTrue(widgetAction.contains("- App Build: 2026.03.12.1"), "widget prefill should fill app build metadata")
assertTrue(widgetLayout.contains("- Tester: codex"), "widget prefill should fill layout tester metadata")

let customWidgetActionPath = widgetPath.appendingPathComponent("action/WD-002.md")
let customWidgetAction = loadFile(customWidgetActionPath).replacingOccurrences(of: "- Tester: codex", with: "- Tester: already-set")
try customWidgetAction.write(to: customWidgetActionPath, atomically: true, encoding: .utf8)
_ = runScript("scripts/prefill_manual_evidence_pack.sh", arguments: ["widget", widgetPath.path])
let preservedWidgetAction = loadFile(customWidgetActionPath)
assertTrue(preservedWidgetAction.contains("- Tester: already-set"), "widget prefill should not overwrite existing metadata")

_ = runScript("scripts/render_manual_evidence_pack.sh", arguments: ["auth-smtp", "--output", authPath.path])
setenv("DOGAREA_AUTH_SMTP_PROJECT", "ttjiknenynbhbpoqoesq", 1)
setenv("DOGAREA_AUTH_SMTP_PROVIDER", "Resend", 1)
setenv("DOGAREA_AUTH_SMTP_SENDER_DOMAIN", "auth.dogarea.app", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_SPF", "pass", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_DKIM", "verified", 1)
setenv("DOGAREA_AUTH_SMTP_DNS_DMARC", "present", 1)
setenv("DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT", "2026-03-12T08:00:00Z", 1)
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
let authPrefillOutput = runScript("scripts/prefill_manual_evidence_pack.sh", arguments: ["auth-smtp", authPath.path])
assertTrue(authPrefillOutput.contains("PREFILLED auth-smtp"), "auth-smtp prefill should report completion")
let authDNS = loadFile(authPath.appendingPathComponent("01-dns-verification.md"))
let authSettings = loadFile(authPath.appendingPathComponent("02-supabase-smtp-settings.md"))
assertTrue(authDNS.contains("- Provider: Resend"), "auth prefill should fill provider metadata")
assertTrue(authDNS.contains("- DKIM: verified"), "auth prefill should fill dns metadata")
assertTrue(authSettings.contains("- SMTP Host: smtp.resend.com"), "auth prefill should fill smtp host")
assertTrue(authSettings.contains("- `email_sent`: 12"), "auth prefill should fill smtp policy metadata")

let customAuthDNSPath = authPath.appendingPathComponent("01-dns-verification.md")
let customAuthDNS = loadFile(customAuthDNSPath).replacingOccurrences(of: "- Provider: Resend", with: "- Provider: Custom Provider")
try customAuthDNS.write(to: customAuthDNSPath, atomically: true, encoding: .utf8)
_ = runScript("scripts/prefill_manual_evidence_pack.sh", arguments: ["auth-smtp", authPath.path])
let preservedAuthDNS = loadFile(customAuthDNSPath)
assertTrue(preservedAuthDNS.contains("- Provider: Custom Provider"), "auth prefill should not overwrite existing metadata")

print("PASS: manual evidence prefill contract checks")
