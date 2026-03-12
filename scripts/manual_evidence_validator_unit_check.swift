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
/// - Parameters:
///   - url: Destination file URL.
///   - content: Markdown body to write.
func write(_ url: URL, content: String) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fputs("Failed to write temp markdown: \(error)\n", stderr)
        exit(1)
    }
}

/// Writes a placeholder asset file for validator-backed evidence tests.
/// - Parameter url: Asset file URL to create.
func writeAsset(_ url: URL) {
    write(url, content: "placeholder-asset")
}

/// Builds a filled widget action case from the shared template.
/// - Parameters:
///   - caseID: Canonical action case identifier.
///   - summary: Result summary to store in the evidence.
/// - Returns: Filled markdown for the action case.
func filledWidgetAction(caseID: String, summary: String) -> String {
    let template = load("docs/widget-action-real-device-evidence-template-v1.md")
    return template
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-12")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.12.1")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemMedium")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: cold start")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: route converges")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: ExpectedDestination")
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
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemMedium")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- Covered States:", with: "- Covered States: memberReady, syncDelayed")
        .replacingOccurrences(of: "- Headline Policy:", with: "- Headline Policy: 2 lines max")
        .replacingOccurrences(of: "- Detail Policy:", with: "- Detail Policy: 2 lines max")
        .replacingOccurrences(of: "- Badge Budget:", with: "- Badge Budget: 2 max")
        .replacingOccurrences(of: "- CTA Height Rule:", with: "- CTA Height Rule: 44-56pt")
        .replacingOccurrences(of: "- Metric Tile Rule:", with: "- Metric Tile Rule: stable strip height")
        .replacingOccurrences(of: "- Compact Formatting Rule:", with: "- Compact Formatting Rule: shortened unit labels")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: no clipping")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(surface) layout stayed within bounds")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "- `step-1`: assets/layout/<case-id>-step-1.png", with: "- `step-1`: assets/layout/\(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`: assets/layout/<case-id>-step-2.png", with: "- `step-2`: assets/layout/\(caseID)-step-2.png")
}

/// Writes a filled auth smtp evidence bundle into the provided directory.
/// - Parameter directory: Bundle root directory that will receive the evidence files.
func writeFilledAuthBundle(at directory: URL) {
    write(directory.appendingPathComponent("01-dns-verification.md"), content: """
    # DNS Verification

    - Date: 2026-03-12
    - Operator: codex
    - Supabase Project: ttjiknenynbhbpoqoesq
    - Provider: Resend
    - Sender Domain: auth.dogarea.app
    - SPF: pass
    - DKIM: verified
    - DMARC: present
    - Provider Verified Timestamp: 2026-03-12T12:00:00Z
    - Evidence Screenshot: assets/provider-domain.png
    """)

    write(directory.appendingPathComponent("02-supabase-smtp-settings.md"), content: """
    # Supabase Auth SMTP Settings

    - SMTP Host: smtp.resend.com
    - SMTP Port: 587
    - SMTP User Mask: re_***
    - Sender Name: DogArea Auth
    - Sender Email: auth@auth.dogarea.app
    - `email_sent`: 12
    - `auth.email.max_frequency`: 60
    - Email Confirmation Policy: required
    - Password Reset Policy: enabled / app deep link
    - Email Change Policy: double confirmation
    - Invite Policy: disabled in product
    - Settings Screenshot: assets/supabase-smtp-settings.png
    """)

    write(directory.appendingPathComponent("03-live-send-results.md"), content: """
    # Live Send Results

    | Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | evidence_asset | Notes |
    | --- | --- | --- | --- | --- | --- | --- | --- | --- |
    | signup confirmation | a***@dogarea.test | 2026-03-12 12:00 | yes | yes | req-1 | msg-1 | assets/signup-mailbox.png | ok |
    | password reset | a***@dogarea.test | 2026-03-12 12:05 | yes | yes | req-2 | msg-2 | assets/password-reset-mailbox.png | ok |
    | email change | a***@dogarea.test | 2026-03-12 12:10 | yes | yes | req-3 | msg-3 | assets/email-change-mailbox.png | ok |
    """)

    write(directory.appendingPathComponent("04-negative-evidence.md"), content: """
    # Negative / Provider Event Evidence

    - SMTP-101 Guard Evidence: cooldown suppressed with retry_after_seconds=60
    - SMTP-102 Provider Event Evidence: provider dashboard confirms accepted delivery
    - bounce: none observed
    - reject: none observed
    - deferred: none observed
    - provider_event_id: evt-1
    - Dashboard / Webhook Evidence: assets/provider-dashboard-event.png
    """)

    write(directory.appendingPathComponent("05-rollback-rotation.md"), content: """
    # Rollback / Rotation Readiness

    - rollback path: revert to previous SMTP config
    - secret rotation owner: ops@dogarea
    - tested backup path: staging resend account
    - notes: ready
    """)

    write(directory.appendingPathComponent("06-final-decision.md"), content: """
    # Final Decision

    - Pass / Fail: Pass
    - Remaining Blockers: none
    - Linked Issue / PR Comment: issue comment url
    """)

    writeAsset(directory.appendingPathComponent("assets/provider-domain.png"))
    writeAsset(directory.appendingPathComponent("assets/supabase-smtp-settings.png"))
    writeAsset(directory.appendingPathComponent("assets/signup-mailbox.png"))
    writeAsset(directory.appendingPathComponent("assets/password-reset-mailbox.png"))
    writeAsset(directory.appendingPathComponent("assets/email-change-mailbox.png"))
    writeAsset(directory.appendingPathComponent("assets/provider-dashboard-event.png"))
}

let validatorScript = load("scripts/validate_manual_evidence_pack.sh")
let validatorDoc = load("docs/manual-evidence-validator-v1.md")
let helperDoc = load("docs/manual-evidence-helper-v1.md")
let widgetRunbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let layoutRunbook = load("docs/widget-family-real-device-evidence-runbook-v1.md")
let authRunbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let widgetTemplate = load("docs/widget-action-real-device-evidence-template-v1.md")
let layoutTemplate = load("docs/widget-family-real-device-evidence-template-v1.md")
assertTrue(validatorScript.contains("validate_widget_bundle"), "validator should define widget bundle validation")
assertTrue(validatorScript.contains("validate_auth_smtp_bundle"), "validator should define auth smtp bundle validation")
assertTrue(validatorScript.contains("WL-008"), "validator should validate layout cases")
assertTrue(validatorDoc.contains("widget-real-device-evidence"), "validator doc should reference widget bundle path")
assertTrue(validatorDoc.contains("auth-smtp-evidence"), "validator doc should reference auth smtp bundle path")
assertTrue(helperDoc.contains("widget-real-device-evidence"), "helper doc should mention widget bundle path")
assertTrue(helperDoc.contains("auth-smtp-evidence"), "helper doc should mention auth smtp bundle path")
assertTrue(widgetRunbook.contains("validate_manual_evidence_pack.sh widget"), "widget action runbook should reference validator")
assertTrue(layoutRunbook.contains("validate_manual_evidence_pack.sh widget"), "widget layout runbook should reference validator")
assertTrue(authRunbook.contains("validate_manual_evidence_pack.sh auth-smtp"), "auth runbook should reference validator")
assertTrue(readme.contains("docs/manual-evidence-validator-v1.md"), "README should link validator doc")
assertTrue(iosPRCheck.contains("manual_evidence_validator_unit_check.swift"), "ios_pr_check should run validator check")
assertTrue(backendPRCheck.contains("manual_evidence_validator_unit_check.swift"), "backend_pr_check should run validator check")

let rawBundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
try? FileManager.default.createDirectory(at: rawBundleURL.appendingPathComponent("action"), withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: rawBundleURL.appendingPathComponent("layout"), withIntermediateDirectories: true)
write(rawBundleURL.appendingPathComponent("action/WD-001.md"), content: widgetTemplate)
write(rawBundleURL.appendingPathComponent("layout/WL-001.md"), content: layoutTemplate)
let rawWidgetOutput = runValidator(arguments: ["widget", rawBundleURL.path], expectSuccess: false)
assertTrue(rawWidgetOutput.contains("FAIL: widget evidence is incomplete"), "raw widget bundle should fail")
assertTrue(rawWidgetOutput.contains("missing action file"), "raw widget bundle should flag missing action files")
assertTrue(rawWidgetOutput.contains("missing layout file"), "raw widget bundle should flag missing layout files")

let filledBundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
for caseID in ["WD-001", "WD-002", "WD-003", "WD-004", "WD-005", "WD-006", "WD-007", "WD-008"] {
    write(filledBundleURL.appendingPathComponent("action/\(caseID).md"), content: filledWidgetAction(caseID: caseID, summary: "\(caseID) converged"))
    writeAsset(filledBundleURL.appendingPathComponent("assets/action/\(caseID)-step-1.png"))
    writeAsset(filledBundleURL.appendingPathComponent("assets/action/\(caseID)-step-2.png"))
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
    write(filledBundleURL.appendingPathComponent("layout/\(caseID).md"), content: filledWidgetLayout(caseID: caseID, surface: surface))
    writeAsset(filledBundleURL.appendingPathComponent("assets/layout/\(caseID)-step-1.png"))
    writeAsset(filledBundleURL.appendingPathComponent("assets/layout/\(caseID)-step-2.png"))
}
let filledWidgetOutput = runValidator(arguments: ["widget", filledBundleURL.path], expectSuccess: true)
assertTrue(filledWidgetOutput.contains("PASS: widget evidence is complete"), "filled widget bundle should pass")

let rawAuthURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let filledAuthURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
write(rawAuthURL.appendingPathComponent("01-dns-verification.md"), content: """
# DNS Verification

- Date:
- Operator:
- Supabase Project:
- Provider:
- Sender Domain:
- SPF:
- DKIM:
- DMARC:
- Provider Verified Timestamp:
- Evidence Screenshot:
""")
let rawAuthOutput = runValidator(arguments: ["auth-smtp", rawAuthURL.path], expectSuccess: false)
assertTrue(rawAuthOutput.contains("FAIL: auth-smtp evidence is incomplete"), "raw auth template should fail")
writeFilledAuthBundle(at: filledAuthURL)
let filledAuthOutput = runValidator(arguments: ["auth-smtp", filledAuthURL.path], expectSuccess: true)
assertTrue(filledAuthOutput.contains("PASS: auth-smtp evidence is complete"), "filled auth evidence should pass")

print("PASS: manual evidence validator contract checks")
