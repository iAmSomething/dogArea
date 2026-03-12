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

/// Loads a UTF-8 text file from an absolute URL.
/// - Parameter url: File URL to read.
/// - Returns: Decoded file contents.
func loadAbsolute(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to load \(url.path)\n", stderr)
        exit(1)
    }
    return text
}

/// Asserts that a condition holds for the poster contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs the poster script and captures combined output.
/// - Parameters:
///   - arguments: CLI arguments passed to the poster.
///   - environment: Extra environment values for the process.
///   - expectSuccess: Whether the script should succeed.
/// - Returns: Combined stdout and stderr.
func runPoster(arguments: [String], environment: [String: String] = [:], expectSuccess: Bool) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/post_closure_comment_from_evidence.sh"] + arguments

    var mergedEnvironment = ProcessInfo.processInfo.environment
    environment.forEach { mergedEnvironment[$0.key] = $0.value }
    process.environment = mergedEnvironment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch poster: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if expectSuccess && process.terminationStatus != 0 {
        fputs("Poster should have succeeded.\n\(output)\n", stderr)
        exit(1)
    }
    if !expectSuccess && process.terminationStatus == 0 {
        fputs("Poster should have failed.\n\(output)\n", stderr)
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

/// Writes a placeholder asset file for poster-backed evidence tests.
/// - Parameter url: Asset file URL to create.
func writeAsset(_ url: URL) {
    write(url, content: "placeholder-asset")
}

/// Creates a fake gh binary that records its arguments.
/// - Parameter directory: Temporary directory that owns the fake binary.
/// - Returns: URLs for the fake binary and captured log.
func makeFakeGH(in directory: URL) -> (binary: URL, log: URL) {
    let logURL = directory.appendingPathComponent("gh.log")
    let binaryURL = directory.appendingPathComponent("fake-gh.sh")
    let script = """
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\\n' "$*" >> "\(logURL.path)"
    printf 'https://example.test/issues/comment\\n'
    """
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try script.write(to: binaryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryURL.path)
    } catch {
        fputs("Failed to create fake gh: \(error)\n", stderr)
        exit(1)
    }
    return (binaryURL, logURL)
}

/// Builds a filled widget action case from the shared template.
/// - Parameters:
///   - caseID: Canonical action case identifier.
///   - summary: Summary for the closure comment.
/// - Returns: Filled markdown for the action case.
func filledWidgetAction(caseID: String, summary: String) -> String {
    let template = load("docs/widget-action-real-device-evidence-template-v1.md")
    return template
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-12")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.12")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemSmall")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: background")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: 로그인")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: dogarea://widget/\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: app opens the correct surface")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: expected destination")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "- `step-1`: assets/action/<case-id>-step-1.png", with: "- `step-1`: assets/action/\(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`: assets/action/<case-id>-step-2.png", with: "- `step-2`: assets/action/\(caseID)-step-2.png")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] route=\(caseID.lowercased())")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: dogarea://widget/\(caseID.lowercased())")
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
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.12")
        .replacingOccurrences(of: "- Widget Surface:", with: "- Widget Surface: \(surface)")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemSmall")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- Covered States:", with: "- Covered States: idle, syncDelayed")
        .replacingOccurrences(of: "- Headline Policy:", with: "- Headline Policy: 2 lines max")
        .replacingOccurrences(of: "- Detail Policy:", with: "- Detail Policy: 1 line max")
        .replacingOccurrences(of: "- Badge Budget:", with: "- Badge Budget: 2 max")
        .replacingOccurrences(of: "- CTA Height Rule:", with: "- CTA Height Rule: 44-52pt")
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
    - SMTP-102 Provider Event Evidence: provider dashboard event summary
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

let posterScript = load("scripts/post_closure_comment_from_evidence.sh")
let posterDoc = load("docs/manual-closure-comment-poster-v1.md")
let rendererDoc = load("docs/manual-closure-comment-renderer-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
assertTrue(posterScript.contains("surface widget must target one of #408, #617, #692, #731"), "poster should allow widget blocker issue bundle")
assertTrue(posterScript.contains("--all-related"), "poster should support widget bundle posting")
assertTrue(posterDoc.contains("#617"), "poster doc should mention related widget issues")
assertTrue(posterDoc.contains("--all-related"), "poster doc should document bundled widget posting")
assertTrue(rendererDoc.contains("widget-real-device-evidence"), "renderer doc should reference widget bundle path")
assertTrue(rendererDoc.contains("auth-smtp-evidence"), "renderer doc should reference auth smtp bundle path")
assertTrue(readme.contains("docs/manual-closure-comment-poster-v1.md"), "README should link poster doc")
assertTrue(iosPRCheck.contains("manual_closure_comment_poster_unit_check.swift"), "ios_pr_check should run poster check")
assertTrue(backendPRCheck.contains("manual_closure_comment_poster_unit_check.swift"), "backend_pr_check should run poster check")

let widgetTempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetCases: [(String, String)] = [
    ("WD-001", "member start route converged"),
    ("WD-002", "member stop route converged"),
    ("WD-003", "guest route deferred into auth"),
    ("WD-004", "overlay replay converged"),
    ("WD-005", "territory deeplink converged"),
    ("WD-006", "quest deeplink converged"),
    ("WD-007", "hotspot deeplink converged"),
    ("WD-008", "pending action replay converged")
]
for (caseID, summary) in widgetCases {
    write(widgetTempDir.appendingPathComponent("action/\(caseID).md"), content: filledWidgetAction(caseID: caseID, summary: summary))
    writeAsset(widgetTempDir.appendingPathComponent("assets/action/\(caseID)-step-1.png"))
    writeAsset(widgetTempDir.appendingPathComponent("assets/action/\(caseID)-step-2.png"))
}
let widgetLayouts = [
    "WL-001": "WalkControlWidget",
    "WL-002": "WalkControlWidget",
    "WL-003": "TerritoryStatusWidget",
    "WL-004": "TerritoryStatusWidget",
    "WL-005": "QuestRivalStatusWidget",
    "WL-006": "QuestRivalStatusWidget",
    "WL-007": "HotspotStatusWidget",
    "WL-008": "HotspotStatusWidget"
]
for (caseID, surface) in widgetLayouts {
    write(widgetTempDir.appendingPathComponent("layout/\(caseID).md"), content: filledWidgetLayout(caseID: caseID, surface: surface))
    writeAsset(widgetTempDir.appendingPathComponent("assets/layout/\(caseID)-step-1.png"))
    writeAsset(widgetTempDir.appendingPathComponent("assets/layout/\(caseID)-step-2.png"))
}

let widgetDryRunOutput = runPoster(arguments: ["widget", "--issue", "617", widgetTempDir.path], expectSuccess: true)
assertTrue(widgetDryRunOutput.contains("실기기 위젯 blocker 검증을 완료했습니다."), "widget dry-run should print closure comment")
assertTrue(widgetDryRunOutput.contains("DRY RUN: no GitHub comment was posted."), "widget dry-run should explain posting did not happen")

let widgetBundleDryRunOutput = runPoster(arguments: ["widget", "--all-related", widgetTempDir.path], expectSuccess: true)
assertTrue(widgetBundleDryRunOutput.contains("실기기 위젯 blocker 검증을 완료했습니다."), "widget bundle dry-run should print closure comment")
assertTrue(widgetBundleDryRunOutput.contains("issues #731, #617, and #692"), "widget bundle dry-run should mention active target issues")

let widgetMismatchOutput = runPoster(arguments: ["widget", "--issue", "482", widgetTempDir.path], expectSuccess: false)
assertTrue(widgetMismatchOutput.contains("surface widget must target one of #408, #617, #692, #731"), "widget poster should reject mismatched issue")

let widgetBundleConflictOutput = runPoster(arguments: ["widget", "--issue", "617", "--all-related", widgetTempDir.path], expectSuccess: false)
assertTrue(widgetBundleConflictOutput.contains("--issue and --all-related cannot be used together"), "widget poster should reject mixed single and bundled modes")

let fakeWidgetGH = makeFakeGH(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
let widgetPostOutput = runPoster(arguments: ["widget", "--issue", "731", widgetTempDir.path, "--post"], environment: ["DOGAREA_GH_BIN": fakeWidgetGH.binary.path], expectSuccess: true)
let widgetGHLog = loadAbsolute(fakeWidgetGH.log)
assertTrue(widgetGHLog.contains("issue comment 731 --body-file"), "widget post should call gh issue comment with issue 731")
assertTrue(widgetPostOutput.contains("POSTED issue #731"), "widget post should report successful post")

let fakeWidgetBundleGH = makeFakeGH(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
let widgetBundlePostOutput = runPoster(arguments: ["widget", "--all-related", widgetTempDir.path, "--post"], environment: ["DOGAREA_GH_BIN": fakeWidgetBundleGH.binary.path], expectSuccess: true)
let widgetBundleGHLog = loadAbsolute(fakeWidgetBundleGH.log)
assertTrue(!widgetBundleGHLog.contains("issue comment 408 --body-file"), "widget bundle post should skip closed issue 408")
assertTrue(widgetBundleGHLog.contains("issue comment 731 --body-file"), "widget bundle post should comment on issue 731")
assertTrue(widgetBundleGHLog.contains("issue comment 617 --body-file"), "widget bundle post should comment on issue 617")
assertTrue(widgetBundleGHLog.contains("issue comment 692 --body-file"), "widget bundle post should comment on issue 692")
assertTrue(widgetBundlePostOutput.contains("POSTED issues #731, #617, and #692"), "widget bundle post should report bundled post")

let authURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
writeFilledAuthBundle(at: authURL)
let authDryRunOutput = runPoster(arguments: ["auth-smtp", "--issue", "482", authURL.path], expectSuccess: true)
assertTrue(authDryRunOutput.contains("custom SMTP rollout 운영 증적을 확인했습니다."), "auth dry-run should print closure comment")

print("PASS: manual closure comment poster contract checks")
