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

/// Asserts that a condition holds for the validator contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Executes the validator with the provided arguments.
/// - Parameters:
///   - arguments: CLI arguments passed to the validator script.
///   - expectSuccess: Whether the process should exit successfully.
/// - Returns: Combined UTF-8 output from stdout and stderr.
func runValidator(arguments: [String], expectSuccess: Bool) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/validate_manual_evidence_pack.sh"] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch validator: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if expectSuccess && process.terminationStatus != 0 {
        fputs("Validator should have succeeded.\n\(output)\n", stderr)
        exit(1)
    }

    if !expectSuccess && process.terminationStatus == 0 {
        fputs("Validator should have failed.\n\(output)\n", stderr)
        exit(1)
    }

    return output
}

/// Writes temporary markdown content for validator test cases.
/// - Parameter content: Markdown body to write.
/// - Returns: Temporary file URL containing the provided content.
func writeTemporaryMarkdown(_ content: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("md")
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fputs("Failed to write temp markdown: \(error)\n", stderr)
        exit(1)
    }
    return url
}

let validatorScript = load("scripts/validate_manual_evidence_pack.sh")
let validatorDoc = load("docs/manual-evidence-validator-v1.md")
let helperDoc = load("docs/manual-evidence-helper-v1.md")
let widgetRunbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let authRunbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let widgetTemplate = load("docs/widget-action-real-device-evidence-template-v1.md")
let authTemplate = load("docs/auth-smtp-rollout-evidence-template-v1.md")

assertTrue(validatorScript.contains("validate_widget"), "validator should define widget validation")
assertTrue(validatorScript.contains("validate_auth_smtp"), "validator should define auth smtp validation")
assertTrue(validatorDoc.contains("validate_manual_evidence_pack.sh widget"), "doc should include widget validator usage")
assertTrue(validatorDoc.contains("validate_manual_evidence_pack.sh auth-smtp"), "doc should include auth-smtp validator usage")
assertTrue(helperDoc.contains("render_manual_evidence_pack.sh"), "helper doc should still mention render helper")
assertTrue(widgetRunbook.contains("validate_manual_evidence_pack.sh widget"), "widget runbook should reference validator")
assertTrue(authRunbook.contains("validate_manual_evidence_pack.sh auth-smtp"), "auth runbook should reference validator")
assertTrue(readme.contains("docs/manual-evidence-validator-v1.md"), "README should link validator doc")
assertTrue(iosPRCheck.contains("manual_evidence_validator_unit_check.swift"), "ios_pr_check should run validator check")
assertTrue(backendPRCheck.contains("manual_evidence_validator_unit_check.swift"), "backend_pr_check should run validator check")

let filledWidget = widgetTemplate
    .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-10")
    .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
    .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
    .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.10.1")
    .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemMedium")
    .replacingOccurrences(of: "- Case ID:", with: "- Case ID: WD-001")
    .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: cold start")
    .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
    .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://walk/start")
    .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: map start deck opens")
    .replacingOccurrences(of: "- Summary:", with: "- Summary: expected route opened")
    .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: MapView")
    .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
    .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] action=startWalk request_id=abc")
    .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: widget://walk/start")
    .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded consumed=startWalk")
    .replacingOccurrences(of: "request_id=...", with: "request_id=abc")
    .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: WD-001-step-1.png")
    .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: WD-001-step-2.png")

let filledAuth = authTemplate
    .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-10")
    .replacingOccurrences(of: "- Operator:", with: "- Operator: codex")
    .replacingOccurrences(of: "- Supabase Project:", with: "- Supabase Project: ttjiknenynbhbpoqoesq")
    .replacingOccurrences(of: "- Provider:", with: "- Provider: Resend")
    .replacingOccurrences(of: "- Sender Domain:", with: "- Sender Domain: auth.dogarea.app")
    .replacingOccurrences(of: "- SPF:", with: "- SPF: pass")
    .replacingOccurrences(of: "- DKIM:", with: "- DKIM: verified")
    .replacingOccurrences(of: "- DMARC:", with: "- DMARC: present")
    .replacingOccurrences(of: "- Provider Verified Timestamp:", with: "- Provider Verified Timestamp: 2026-03-10T12:00:00Z")
    .replacingOccurrences(of: "- Evidence Screenshot:", with: "- Evidence Screenshot: smtp-domain.png")
    .replacingOccurrences(of: "- SMTP Host:", with: "- SMTP Host: smtp.resend.com")
    .replacingOccurrences(of: "- SMTP Port:", with: "- SMTP Port: 587")
    .replacingOccurrences(of: "- SMTP User Mask:", with: "- SMTP User Mask: re_***")
    .replacingOccurrences(of: "- Sender Name:", with: "- Sender Name: DogArea Auth")
    .replacingOccurrences(of: "- Sender Email:", with: "- Sender Email: auth@auth.dogarea.app")
    .replacingOccurrences(of: "- `email_sent`:", with: "- `email_sent`: true")
    .replacingOccurrences(of: "- `auth.email.max_frequency`:", with: "- `auth.email.max_frequency`: 60")
    .replacingOccurrences(of: "- Settings Screenshot:", with: "- Settings Screenshot: smtp-settings.png")
    .replacingOccurrences(of: "| signup confirmation |  |  |  |  |  |  |  |", with: "| signup confirmation | a***@dogarea.test | 2026-03-10 12:00 | yes | yes | req-1 | msg-1 | ok |")
    .replacingOccurrences(of: "| password reset |  |  |  |  |  |  |  |", with: "| password reset | a***@dogarea.test | 2026-03-10 12:05 | yes | yes | req-2 | msg-2 | ok |")
    .replacingOccurrences(of: "| email change |  |  |  |  |  |  |  |", with: "| email change | a***@dogarea.test | 2026-03-10 12:10 | yes | yes | req-3 | msg-3 | ok |")
    .replacingOccurrences(of: "- bounce:", with: "- bounce: none observed")
    .replacingOccurrences(of: "- reject:", with: "- reject: none observed")
    .replacingOccurrences(of: "- deferred:", with: "- deferred: none observed")
    .replacingOccurrences(of: "- provider_event_id:", with: "- provider_event_id: evt-1")
    .replacingOccurrences(of: "- Dashboard / Webhook Evidence:", with: "- Dashboard / Webhook Evidence: resend-dashboard.png")
    .replacingOccurrences(of: "- rollback path:", with: "- rollback path: revert to previous SMTP config")
    .replacingOccurrences(of: "- secret rotation owner:", with: "- secret rotation owner: ops@dogarea")
    .replacingOccurrences(of: "- tested backup path:", with: "- tested backup path: staging resend account")
    .replacingOccurrences(of: "- notes:", with: "- notes: none")
    .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
    .replacingOccurrences(of: "- Remaining Blockers:", with: "- Remaining Blockers: none")
    .replacingOccurrences(of: "- Linked Issue / PR Comment:", with: "- Linked Issue / PR Comment: issue comment url")

let rawWidgetURL = writeTemporaryMarkdown(widgetTemplate)
let rawAuthURL = writeTemporaryMarkdown(authTemplate)
let filledWidgetURL = writeTemporaryMarkdown(filledWidget)
let filledAuthURL = writeTemporaryMarkdown(filledAuth)

let rawWidgetOutput = runValidator(arguments: ["widget", rawWidgetURL.path], expectSuccess: false)
assertTrue(rawWidgetOutput.contains("FAIL: widget evidence is incomplete"), "raw widget template should fail")
assertTrue(rawWidgetOutput.contains("empty value: - Date:"), "raw widget template should flag empty date")
assertTrue(rawWidgetOutput.contains("placeholder literal remains: [WidgetAction] ..."), "raw widget template should flag placeholder log")

let filledWidgetOutput = runValidator(arguments: ["widget", filledWidgetURL.path], expectSuccess: true)
assertTrue(filledWidgetOutput.contains("PASS: widget evidence is complete"), "filled widget evidence should pass")

let rawAuthOutput = runValidator(arguments: ["auth-smtp", rawAuthURL.path], expectSuccess: false)
assertTrue(rawAuthOutput.contains("FAIL: auth-smtp evidence is incomplete"), "raw auth template should fail")
assertTrue(rawAuthOutput.contains("empty value: - Provider:"), "raw auth template should flag empty provider")
assertTrue(rawAuthOutput.contains("incomplete scenario row: signup confirmation"), "raw auth template should flag empty scenario row")

let filledAuthOutput = runValidator(arguments: ["auth-smtp", filledAuthURL.path], expectSuccess: true)
assertTrue(filledAuthOutput.contains("PASS: auth-smtp evidence is complete"), "filled auth evidence should pass")

print("PASS: manual evidence validator contract checks")
