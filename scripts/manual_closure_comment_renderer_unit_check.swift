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
///   - url: File URL to write.
///   - content: Markdown body to write.
func write(_ url: URL, content: String) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fputs("Failed to write markdown: \(error)\n", stderr)
        exit(1)
    }
}

/// Builds a filled widget action case from the shared template.
/// - Parameters:
///   - caseID: Canonical action case identifier.
///   - summary: Summary for rendered closure comment.
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
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: background")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: app opens the correct surface")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: expected destination")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] route=\(caseID.lowercased())")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: widget://\(caseID.lowercased())")
        .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded action=\(caseID.lowercased())")
        .replacingOccurrences(of: "request_id=...", with: "request_id=req-\(caseID.lowercased())")
}

/// Builds a filled widget layout case from the shared template.
/// - Parameters:
///   - caseID: Canonical layout case identifier.
///   - surface: Widget surface covered by the case.
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
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
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
    - Evidence Screenshot: smtp-domain.png
    """)

    write(directory.appendingPathComponent("02-supabase-smtp-settings.md"), content: """
    # Supabase Auth SMTP Settings

    - SMTP Host: smtp.resend.com
    - SMTP Port: 587
    - SMTP User Mask: re_***
    - Sender Name: DogArea Auth
    - Sender Email: auth@auth.dogarea.app
    - `email_sent`: true
    - `auth.email.max_frequency`: 60
    - Settings Screenshot: smtp-settings.png
    """)

    write(directory.appendingPathComponent("03-live-send-results.md"), content: """
    # Live Send Results

    | Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | Notes |
    | --- | --- | --- | --- | --- | --- | --- | --- |
    | signup confirmation | a***@dogarea.test | 2026-03-12 12:00 | yes | yes | req-1 | msg-1 | ok |
    | password reset | a***@dogarea.test | 2026-03-12 12:05 | yes | yes | req-2 | msg-2 | ok |
    | email change | a***@dogarea.test | 2026-03-12 12:10 | yes | yes | req-3 | msg-3 | ok |
    """)

    write(directory.appendingPathComponent("04-negative-evidence.md"), content: """
    # Negative / Provider Event Evidence

    - SMTP-101 Guard Evidence: cooldown suppressed with retry_after_seconds=60
    - SMTP-102 Provider Event Evidence: provider dashboard event summary
    - bounce: none observed
    - reject: none observed
    - deferred: none observed
    - provider_event_id: evt-1
    - Dashboard / Webhook Evidence: resend-dashboard.png
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
}

let rendererScript = load("scripts/render_closure_comment_from_evidence.sh")
let rendererDoc = load("docs/manual-closure-comment-renderer-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
assertTrue(rendererScript.contains("layout / clipping 케이스"), "renderer should render layout section")
assertTrue(rendererDoc.contains("#617"), "renderer doc should mention bundled widget blockers")
assertTrue(rendererDoc.contains("widget-real-device-evidence"), "renderer doc should reference widget bundle path")
assertTrue(rendererDoc.contains("auth-smtp-evidence"), "renderer doc should reference auth smtp bundle path")
assertTrue(readme.contains("docs/manual-closure-comment-renderer-v1.md"), "README should link renderer doc")
assertTrue(iosPRCheck.contains("manual_closure_comment_renderer_unit_check.swift"), "ios_pr_check should run renderer check")
assertTrue(backendPRCheck.contains("manual_closure_comment_renderer_unit_check.swift"), "backend_pr_check should run renderer check")

let widgetDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetCases = [
    "WD-001": "member rival route converged",
    "WD-002": "member hotspot route converged",
    "WD-003": "quest detail route converged",
    "WD-004": "quest recovery route converged",
    "WD-005": "territory goal route converged",
    "WD-006": "walk start converged",
    "WD-007": "walk end converged",
    "WD-008": "auth overlay defer converged"
]
for (caseID, summary) in widgetCases {
    write(widgetDirectory.appendingPathComponent("action/\(caseID).md"), content: filledWidgetAction(caseID: caseID, summary: summary))
}
let layoutCases = [
    "WL-001": "WalkControlWidget",
    "WL-002": "WalkControlWidget",
    "WL-003": "TerritoryStatusWidget",
    "WL-004": "TerritoryStatusWidget",
    "WL-005": "QuestRivalStatusWidget",
    "WL-006": "QuestRivalStatusWidget",
    "WL-007": "HotspotStatusWidget",
    "WL-008": "HotspotStatusWidget"
]
for (caseID, surface) in layoutCases {
    write(widgetDirectory.appendingPathComponent("layout/\(caseID).md"), content: filledWidgetLayout(caseID: caseID, surface: surface))
}

let widgetOutput = runRenderer(arguments: ["widget", widgetDirectory.path], expectSuccess: true)
assertTrue(widgetOutput.contains("실기기 위젯 blocker 검증을 완료했습니다."), "widget comment should include intro")
assertTrue(widgetOutput.contains("`WD-001`: Pass - member rival route converged"), "widget comment should include WD-001 summary")
assertTrue(widgetOutput.contains("`WL-008`: Pass - HotspotStatusWidget layout stayed within bounds"), "widget comment should include WL-008 summary")
assertTrue(widgetOutput.contains("active widget blocker `#617`, `#692`, `#731` DoD를 충족했으므로 종료합니다."), "widget comment should include active blocker closure line")

let incompleteWidgetDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
write(incompleteWidgetDirectory.appendingPathComponent("action/WD-001.md"), content: filledWidgetAction(caseID: "WD-001", summary: "only one case"))
let incompleteWidgetOutput = runRenderer(arguments: ["widget", incompleteWidgetDirectory.path], expectSuccess: false)
assertTrue(incompleteWidgetOutput.contains("missing action file"), "widget renderer should fail on missing action bundle files")

let authURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
writeFilledAuthBundle(at: authURL)
let authOutput = runRenderer(arguments: ["auth-smtp", authURL.path], expectSuccess: true)
assertTrue(authOutput.contains("Provider: Resend"), "auth comment should include provider")
assertTrue(authOutput.contains("SMTP-101"), "auth comment should include negative guard evidence from bundle")
assertTrue(authOutput.contains("`#482` DoD를 충족했으므로 종료합니다."), "auth comment should include closure line")

print("PASS: manual closure comment renderer contract checks")
