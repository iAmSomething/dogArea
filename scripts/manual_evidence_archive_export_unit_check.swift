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

/// Asserts that a condition holds for the archive export contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Writes UTF-8 text to a file, creating parent directories as needed.
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

/// Writes a placeholder asset file for archive export tests.
/// - Parameter url: Asset file URL to create.
func writeAsset(_ url: URL) {
    write(url, content: "placeholder-asset")
}

/// Runs a shell command and captures combined output.
/// - Parameters:
///   - launchPath: Executable launch path.
///   - arguments: Arguments passed to the executable.
///   - expectSuccess: Whether the command should succeed.
/// - Returns: Combined stdout and stderr.
func runProcess(_ launchPath: String, arguments: [String], expectSuccess: Bool) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch process: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if expectSuccess && process.terminationStatus != 0 {
        fputs("Process should have succeeded.\n\(output)\n", stderr)
        exit(1)
    }

    if !expectSuccess && process.terminationStatus == 0 {
        fputs("Process should have failed.\n\(output)\n", stderr)
        exit(1)
    }

    return output
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
    - `email_sent`: true
    - `auth.email.max_frequency`: 60
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

/// Returns line-wise archive contents for the given zip file.
/// - Parameter archiveURL: Zip archive file URL.
/// - Returns: Decoded `unzip -l` output.
func listArchive(_ archiveURL: URL) -> String {
    runProcess("/usr/bin/unzip", arguments: ["-l", archiveURL.path], expectSuccess: true)
}

/// Reads a UTF-8 file entry from a zip archive.
/// - Parameters:
///   - archiveURL: Zip archive file URL.
///   - entryPath: Relative entry path inside the archive.
/// - Returns: Decoded archive entry contents.
func readArchiveEntry(_ archiveURL: URL, entryPath: String) -> String {
    runProcess("/usr/bin/unzip", arguments: ["-p", archiveURL.path, entryPath], expectSuccess: true)
}

let script = load("scripts/archive_manual_evidence_pack.sh")
let doc = load("docs/manual-evidence-archive-export-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")

assertTrue(script.contains("validate_manual_evidence_pack.sh"), "archive script should validate bundles first")
assertTrue(script.contains("render_closure_comment_from_evidence.sh"), "archive script should render closure preview")
assertTrue(script.contains("widget-real-device-evidence-export.zip"), "archive script should define widget default export path")
assertTrue(script.contains("auth-smtp-evidence-export.zip"), "archive script should define auth default export path")
assertTrue(script.contains("MANIFEST.md"), "archive script should export manifest")
assertTrue(script.contains("SHA256SUMS"), "archive script should export checksums")
assertTrue(doc.contains("# Manual Evidence Archive Export v1"), "archive export doc title should exist")
assertTrue(doc.contains("closure comment preview"), "archive export doc should describe closure preview")
assertTrue(doc.contains("MANIFEST.md"), "archive export doc should describe manifest")
assertTrue(doc.contains("SHA256SUMS"), "archive export doc should describe checksums")
assertTrue(readme.contains("docs/manual-evidence-archive-export-v1.md"), "README should link archive export doc")
assertTrue(iosPRCheck.contains("manual_evidence_archive_export_unit_check.swift"), "ios_pr_check should run archive export check")
assertTrue(backendPRCheck.contains("manual_evidence_archive_export_unit_check.swift"), "backend_pr_check should run archive export check")

let widgetBundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
for caseID in ["WD-001", "WD-002", "WD-003", "WD-004", "WD-005", "WD-006", "WD-007", "WD-008"] {
    write(widgetBundleURL.appendingPathComponent("action/\(caseID).md"), content: filledWidgetAction(caseID: caseID, summary: "\(caseID) converged"))
    writeAsset(widgetBundleURL.appendingPathComponent("assets/action/\(caseID)-step-1.png"))
    writeAsset(widgetBundleURL.appendingPathComponent("assets/action/\(caseID)-step-2.png"))
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
    write(widgetBundleURL.appendingPathComponent("layout/\(caseID).md"), content: filledWidgetLayout(caseID: caseID, surface: surface))
    writeAsset(widgetBundleURL.appendingPathComponent("assets/layout/\(caseID)-step-1.png"))
    writeAsset(widgetBundleURL.appendingPathComponent("assets/layout/\(caseID)-step-2.png"))
}

let widgetArchiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".zip")
let widgetArchiveOutput = runProcess("/bin/bash", arguments: ["scripts/archive_manual_evidence_pack.sh", "widget", widgetBundleURL.path, "--output", widgetArchiveURL.path], expectSuccess: true)
assertTrue(widgetArchiveOutput.contains("WROTE"), "widget archive export should report written archive")
assertTrue(FileManager.default.fileExists(atPath: widgetArchiveURL.path), "widget archive should exist")
let widgetArchiveListing = listArchive(widgetArchiveURL)
assertTrue(widgetArchiveListing.contains("widget-closure-comment.md"), "widget archive should include closure preview")
assertTrue(widgetArchiveListing.contains("MANIFEST.md"), "widget archive should include manifest")
assertTrue(widgetArchiveListing.contains("SHA256SUMS"), "widget archive should include checksums")
assertTrue(widgetArchiveListing.contains("bundle/action/WD-001.md"), "widget archive should include evidence bundle files")
assertTrue(widgetArchiveListing.contains("bundle/assets/action/WD-001-step-1.png"), "widget archive should include action assets")
let widgetManifest = readArchiveEntry(widgetArchiveURL, entryPath: "MANIFEST.md")
assertTrue(widgetManifest.contains("- Surface: widget"), "widget manifest should describe the widget surface")
assertTrue(widgetManifest.contains("- Bundle File Count:"), "widget manifest should include bundle file count")
let widgetChecksums = readArchiveEntry(widgetArchiveURL, entryPath: "SHA256SUMS")
assertTrue(widgetChecksums.contains(" README.md"), "widget checksums should include README")
assertTrue(widgetChecksums.contains(" MANIFEST.md"), "widget checksums should include manifest")
assertTrue(widgetChecksums.contains(" bundle/action/WD-001.md"), "widget checksums should include bundle files")

let authBundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
writeFilledAuthBundle(at: authBundleURL)
let authArchiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".zip")
let authArchiveOutput = runProcess("/bin/bash", arguments: ["scripts/archive_manual_evidence_pack.sh", "auth-smtp", authBundleURL.path, "--output", authArchiveURL.path], expectSuccess: true)
assertTrue(authArchiveOutput.contains("WROTE"), "auth archive export should report written archive")
assertTrue(FileManager.default.fileExists(atPath: authArchiveURL.path), "auth archive should exist")
let authArchiveListing = listArchive(authArchiveURL)
assertTrue(authArchiveListing.contains("auth-smtp-closure-comment.md"), "auth archive should include closure preview")
assertTrue(authArchiveListing.contains("MANIFEST.md"), "auth archive should include manifest")
assertTrue(authArchiveListing.contains("SHA256SUMS"), "auth archive should include checksums")
assertTrue(authArchiveListing.contains("bundle/03-live-send-results.md"), "auth archive should include evidence bundle files")
assertTrue(authArchiveListing.contains("bundle/assets/provider-dashboard-event.png"), "auth archive should include evidence assets")
let authManifest = readArchiveEntry(authArchiveURL, entryPath: "MANIFEST.md")
assertTrue(authManifest.contains("- Surface: auth-smtp"), "auth manifest should describe the auth smtp surface")
assertTrue(authManifest.contains("- Bundle Asset Count:"), "auth manifest should include asset count")
let authChecksums = readArchiveEntry(authArchiveURL, entryPath: "SHA256SUMS")
assertTrue(authChecksums.contains(" auth-smtp-closure-comment.md"), "auth checksums should include closure preview")
assertTrue(authChecksums.contains(" bundle/assets/provider-dashboard-event.png"), "auth checksums should include bundle assets")

print("PASS: manual evidence archive export checks")
