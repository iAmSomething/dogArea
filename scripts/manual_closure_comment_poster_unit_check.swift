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
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
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
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
}

let posterScript = load("scripts/post_closure_comment_from_evidence.sh")
let posterDoc = load("docs/manual-closure-comment-poster-v1.md")
let rendererDoc = load("docs/manual-closure-comment-renderer-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let authTemplate = load("docs/auth-smtp-rollout-evidence-template-v1.md")

assertTrue(posterScript.contains("surface widget must target one of #408, #617, #692, #731"), "poster should allow widget blocker issue bundle")
assertTrue(posterScript.contains("--all-related"), "poster should support widget bundle posting")
assertTrue(posterDoc.contains("#617"), "poster doc should mention related widget issues")
assertTrue(posterDoc.contains("--all-related"), "poster doc should document bundled widget posting")
assertTrue(rendererDoc.contains("widget-real-device-evidence"), "renderer doc should reference widget bundle path")
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
}

let widgetDryRunOutput = runPoster(arguments: ["widget", "--issue", "617", widgetTempDir.path], expectSuccess: true)
assertTrue(widgetDryRunOutput.contains("실기기 위젯 blocker 검증을 완료했습니다."), "widget dry-run should print closure comment")
assertTrue(widgetDryRunOutput.contains("DRY RUN: no GitHub comment was posted."), "widget dry-run should explain posting did not happen")

let widgetBundleDryRunOutput = runPoster(arguments: ["widget", "--all-related", widgetTempDir.path], expectSuccess: true)
assertTrue(widgetBundleDryRunOutput.contains("실기기 위젯 blocker 검증을 완료했습니다."), "widget bundle dry-run should print closure comment")
assertTrue(widgetBundleDryRunOutput.contains("issues #408, #617, #692, and #731"), "widget bundle dry-run should mention all target issues")

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
assertTrue(widgetBundleGHLog.contains("issue comment 408 --body-file"), "widget bundle post should comment on issue 408")
assertTrue(widgetBundleGHLog.contains("issue comment 617 --body-file"), "widget bundle post should comment on issue 617")
assertTrue(widgetBundleGHLog.contains("issue comment 692 --body-file"), "widget bundle post should comment on issue 692")
assertTrue(widgetBundleGHLog.contains("issue comment 731 --body-file"), "widget bundle post should comment on issue 731")
assertTrue(widgetBundlePostOutput.contains("POSTED issues #408, #617, #692, and #731"), "widget bundle post should report bundled post")

let filledAuth = authTemplate
    .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-12")
    .replacingOccurrences(of: "- Operator:", with: "- Operator: codex")
    .replacingOccurrences(of: "- Supabase Project:", with: "- Supabase Project: ttjiknenynbhbpoqoesq")
    .replacingOccurrences(of: "- Provider:", with: "- Provider: Resend")
    .replacingOccurrences(of: "- Sender Domain:", with: "- Sender Domain: auth.dogarea.app")
    .replacingOccurrences(of: "- SPF:", with: "- SPF: pass")
    .replacingOccurrences(of: "- DKIM:", with: "- DKIM: verified")
    .replacingOccurrences(of: "- DMARC:", with: "- DMARC: present")
    .replacingOccurrences(of: "- Provider Verified Timestamp:", with: "- Provider Verified Timestamp: 2026-03-12T12:00:00Z")
    .replacingOccurrences(of: "- Evidence Screenshot:", with: "- Evidence Screenshot: smtp-domain.png")
    .replacingOccurrences(of: "- SMTP Host:", with: "- SMTP Host: smtp.resend.com")
    .replacingOccurrences(of: "- SMTP Port:", with: "- SMTP Port: 587")
    .replacingOccurrences(of: "- SMTP User Mask:", with: "- SMTP User Mask: re_***")
    .replacingOccurrences(of: "- Sender Name:", with: "- Sender Name: DogArea Auth")
    .replacingOccurrences(of: "- Sender Email:", with: "- Sender Email: auth@auth.dogarea.app")
    .replacingOccurrences(of: "- `email_sent`:", with: "- `email_sent`: true")
    .replacingOccurrences(of: "- `auth.email.max_frequency`:", with: "- `auth.email.max_frequency`: 60")
    .replacingOccurrences(of: "- Settings Screenshot:", with: "- Settings Screenshot: smtp-settings.png")
    .replacingOccurrences(of: "| signup confirmation |  |  |  |  |  |  |  |", with: "| signup confirmation | a***@dogarea.test | 2026-03-12 12:00 | yes | yes | req-1 | msg-1 | ok |")
    .replacingOccurrences(of: "| password reset |  |  |  |  |  |  |  |", with: "| password reset | a***@dogarea.test | 2026-03-12 12:05 | yes | yes | req-2 | msg-2 | ok |")
    .replacingOccurrences(of: "| email change |  |  |  |  |  |  |  |", with: "| email change | a***@dogarea.test | 2026-03-12 12:10 | yes | yes | req-3 | msg-3 | ok |")
    .replacingOccurrences(of: "- bounce:", with: "- bounce: none observed")
    .replacingOccurrences(of: "- reject:", with: "- reject: none observed")
    .replacingOccurrences(of: "- deferred:", with: "- deferred: none observed")
    .replacingOccurrences(of: "- provider_event_id:", with: "- provider_event_id: evt-1")
    .replacingOccurrences(of: "- Dashboard / Webhook Evidence:", with: "- Dashboard / Webhook Evidence: resend-dashboard.png")
    .replacingOccurrences(of: "- rollback path:", with: "- rollback path: revert to previous SMTP config")
    .replacingOccurrences(of: "- secret rotation owner:", with: "- secret rotation owner: ops@dogarea")
    .replacingOccurrences(of: "- tested backup path:", with: "- tested backup path: staging resend account")
    .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
    .replacingOccurrences(of: "- Remaining Blockers:", with: "- Remaining Blockers: none")
    .replacingOccurrences(of: "- Linked Issue / PR Comment:", with: "- Linked Issue / PR Comment: issue comment url")
let authURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("md")
write(authURL, content: filledAuth)
let authDryRunOutput = runPoster(arguments: ["auth-smtp", "--issue", "482", authURL.path, "--negative-guard", "SMTP-101: cooldown suppressed", "--negative-provider-event", "SMTP-102: dashboard event"], expectSuccess: true)
assertTrue(authDryRunOutput.contains("custom SMTP rollout 운영 증적을 확인했습니다."), "auth dry-run should print closure comment")

print("PASS: manual closure comment poster contract checks")
