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

/// Asserts that a condition holds for the renderer contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs the renderer script and captures combined output.
/// - Parameters:
///   - arguments: CLI arguments passed to the renderer.
///   - expectSuccess: Whether the script should succeed.
/// - Returns: Combined stdout and stderr.
func runRenderer(arguments: [String], expectSuccess: Bool) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/render_closure_comment_from_evidence.sh"] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch renderer: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if expectSuccess && process.terminationStatus != 0 {
        fputs("Renderer should have succeeded.\n\(output)\n", stderr)
        exit(1)
    }
    if !expectSuccess && process.terminationStatus == 0 {
        fputs("Renderer should have failed.\n\(output)\n", stderr)
        exit(1)
    }
    return output
}

/// Writes temporary markdown content into a dedicated directory.
/// - Parameters:
///   - directory: Base directory.
///   - filename: File name to create.
///   - content: Markdown body to write.
/// - Returns: URL for the written file.
func writeMarkdown(in directory: URL, filename: String, content: String) -> URL {
    let url = directory.appendingPathComponent(filename)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fputs("Failed to write markdown: \(error)\n", stderr)
        exit(1)
    }
    return url
}

let rendererScript = load("scripts/render_closure_comment_from_evidence.sh")
let rendererDoc = load("docs/manual-closure-comment-renderer-v1.md")
let validatorDoc = load("docs/manual-evidence-validator-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let widgetTemplate = load("docs/widget-action-real-device-evidence-template-v1.md")
let authTemplate = load("docs/auth-smtp-rollout-evidence-template-v1.md")

assertTrue(rendererScript.contains("render_widget_comment"), "renderer should support widget rendering")
assertTrue(rendererScript.contains("render_auth_comment"), "renderer should support auth rendering")
assertTrue(rendererDoc.contains("render_closure_comment_from_evidence.sh widget"), "renderer doc should include widget usage")
assertTrue(rendererDoc.contains("render_closure_comment_from_evidence.sh auth-smtp"), "renderer doc should include auth usage")
assertTrue(validatorDoc.contains("validate_manual_evidence_pack.sh"), "validator doc should still mention validator")
assertTrue(readme.contains("docs/manual-closure-comment-renderer-v1.md"), "README should link renderer doc")
assertTrue(iosPRCheck.contains("manual_closure_comment_renderer_unit_check.swift"), "ios_pr_check should run renderer check")
assertTrue(backendPRCheck.contains("manual_closure_comment_renderer_unit_check.swift"), "backend_pr_check should run renderer check")

func filledWidget(caseID: String, summary: String) -> String {
    widgetTemplate
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-10")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.10.1")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemMedium")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: cold start")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: expected destination opens")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: FinalScreen")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] action=\(caseID) request_id=req-\(caseID)")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded consumed=\(caseID)")
        .replacingOccurrences(of: "request_id=...", with: "request_id=req-\(caseID)")
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
}

let widgetDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetCases = [
    "WD-001": "rival tab opened",
    "WD-002": "hotspot broad preset applied",
    "WD-003": "quest detail opened",
    "WD-004": "quest recovery opened",
    "WD-005": "territory goal opened",
    "WD-006": "walk started from widget",
    "WD-007": "walk ended from widget",
    "WD-008": "auth overlay defer worked",
]
for (caseID, summary) in widgetCases {
    _ = writeMarkdown(in: widgetDirectory, filename: "\(caseID).md", content: filledWidget(caseID: caseID, summary: summary))
}

let widgetOutput = runRenderer(arguments: ["widget", widgetDirectory.path], expectSuccess: true)
assertTrue(widgetOutput.contains("실기기 위젯 액션 검증을 완료했습니다."), "widget comment should include intro")
assertTrue(widgetOutput.contains("`WD-001`: Pass - rival tab opened"), "widget comment should include WD-001 summary")
assertTrue(widgetOutput.contains("`WD-008`: Pass - auth overlay defer worked"), "widget comment should include WD-008 summary")
assertTrue(widgetOutput.contains("`#408` DoD를 충족했으므로 종료합니다."), "widget comment should include closure line")

let incompleteWidgetDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
_ = writeMarkdown(in: incompleteWidgetDirectory, filename: "WD-001.md", content: filledWidget(caseID: "WD-001", summary: "only one case"))
let incompleteWidgetOutput = runRenderer(arguments: ["widget", incompleteWidgetDirectory.path], expectSuccess: false)
assertTrue(incompleteWidgetOutput.contains("missing widget case WD-002"), "widget renderer should fail on missing case set")

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

let authURL = writeMarkdown(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString), filename: "auth.md", content: filledAuth)
let authOutput = runRenderer(
    arguments: [
        "auth-smtp",
        authURL.path,
        "--negative-guard", "SMTP-101: cooldown suppressed with retry_after_seconds=60",
        "--negative-provider-event", "SMTP-102: bounce observed with provider_event_id=evt-1",
    ],
    expectSuccess: true
)
assertTrue(authOutput.contains("Provider: Resend"), "auth comment should include provider")
assertTrue(authOutput.contains("`SMTP-001`: recipient=a***@dogarea.test, accepted=yes, mailbox=yes, provider_message_id=msg-1"), "auth comment should include SMTP-001 summary")
assertTrue(authOutput.contains("`SMTP-101`: SMTP-101: cooldown suppressed with retry_after_seconds=60"), "auth comment should include guard summary")
assertTrue(authOutput.contains("`#482` DoD를 충족했으므로 종료합니다."), "auth comment should include closure line")

let authMissingFlagOutput = runRenderer(arguments: ["auth-smtp", authURL.path], expectSuccess: false)
assertTrue(authMissingFlagOutput.contains("--negative-guard is required for auth-smtp"), "auth renderer should require negative guard flag")

print("PASS: manual closure comment renderer contract checks")
