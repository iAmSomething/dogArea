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

let posterScript = load("scripts/post_closure_comment_from_evidence.sh")
let posterDoc = load("docs/manual-closure-comment-poster-v1.md")
let rendererDoc = load("docs/manual-closure-comment-renderer-v1.md")
let validatorDoc = load("docs/manual-evidence-validator-v1.md")
let widgetRunbook = load("docs/widget-action-real-device-evidence-runbook-v1.md")
let authRunbook = load("docs/auth-smtp-rollout-evidence-runbook-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let widgetTemplate = load("docs/widget-action-real-device-evidence-template-v1.md")
let authTemplate = load("docs/auth-smtp-rollout-evidence-template-v1.md")

assertTrue(posterScript.contains("canonical_issue_for_surface"), "poster should validate canonical surface/issue pairs")
assertTrue(posterScript.contains("gh issue comment"), "poster should post through gh issue comment")
assertTrue(posterScript.contains("DOGAREA_GH_BIN"), "poster should expose gh override for tests")
assertTrue(posterDoc.contains("widget --issue 408"), "poster doc should include widget usage")
assertTrue(posterDoc.contains("auth-smtp --issue 482"), "poster doc should include auth usage")
assertTrue(rendererDoc.contains("render_closure_comment_from_evidence.sh"), "renderer doc should remain linked")
assertTrue(validatorDoc.contains("post_closure_comment_from_evidence.sh"), "validator doc should reference poster")
assertTrue(widgetRunbook.contains("post_closure_comment_from_evidence.sh widget --issue 408"), "widget runbook should reference poster")
assertTrue(authRunbook.contains("post_closure_comment_from_evidence.sh auth-smtp --issue 482"), "auth runbook should reference poster")
assertTrue(readme.contains("docs/manual-closure-comment-poster-v1.md"), "README should link poster doc")
assertTrue(readme.contains("post_closure_comment_from_evidence.sh"), "README should include poster helper command")
assertTrue(iosPRCheck.contains("manual_closure_comment_poster_unit_check.swift"), "ios_pr_check should run poster check")
assertTrue(backendPRCheck.contains("manual_closure_comment_poster_unit_check.swift"), "backend_pr_check should run poster check")

func filledWidget(caseID: String, summary: String) -> String {
    widgetTemplate
        .replacingOccurrences(of: "- Date:", with: "- Date: 2026-03-10")
        .replacingOccurrences(of: "- Tester:", with: "- Tester: codex")
        .replacingOccurrences(of: "- Device / OS:", with: "- Device / OS: iPhone 16 / iOS 18.5")
        .replacingOccurrences(of: "- App Build:", with: "- App Build: 2026.03.10")
        .replacingOccurrences(of: "- Widget Family:", with: "- Widget Family: systemSmall")
        .replacingOccurrences(of: "- Case ID:", with: "- Case ID: \(caseID)")
        .replacingOccurrences(of: "- 앱 상태:", with: "- 앱 상태: background")
        .replacingOccurrences(of: "- 인증 상태:", with: "- 인증 상태: member")
        .replacingOccurrences(of: "- Action Route:", with: "- Action Route: dogarea://widget/\(caseID.lowercased())")
        .replacingOccurrences(of: "- Expected Result:", with: "- Expected Result: app opens the correct surface")
        .replacingOccurrences(of: "- Summary:", with: "- Summary: \(summary)")
        .replacingOccurrences(of: "- Final Screen:", with: "- Final Screen: expected destination")
        .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
        .replacingOccurrences(of: "- `step-1`:", with: "- `step-1`: \(caseID)-step-1.png")
        .replacingOccurrences(of: "- `step-2`:", with: "- `step-2`: \(caseID)-step-2.png")
        .replacingOccurrences(of: "- `step-fail`:", with: "- `step-fail`: not needed")
        .replacingOccurrences(of: "[WidgetAction] ...", with: "[WidgetAction] route=\(caseID.lowercased())")
        .replacingOccurrences(of: "onOpenURL received: ...", with: "onOpenURL received: dogarea://widget/\(caseID.lowercased())")
        .replacingOccurrences(of: "consumePendingWidgetActionIfNeeded ...", with: "consumePendingWidgetActionIfNeeded action=\(caseID.lowercased())")
        .replacingOccurrences(of: "request_id=...", with: "request_id=req-\(caseID.lowercased())")
}

let widgetTempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
let widgetCases: [(String, String)] = [
    ("WD-001", "member start route converged"),
    ("WD-002", "member stop route converged"),
    ("WD-003", "guest route deferred into auth"),
    ("WD-004", "overlay replay converged"),
    ("WD-005", "territory deeplink converged"),
    ("WD-006", "quest deeplink converged"),
    ("WD-007", "hotspot deeplink converged"),
    ("WD-008", "pending action replay converged"),
]
for (caseID, summary) in widgetCases {
    _ = writeMarkdown(in: widgetTempDir, filename: "\(caseID).md", content: filledWidget(caseID: caseID, summary: summary))
}

let widgetDryRunOutput = runPoster(arguments: ["widget", "--issue", "408", widgetTempDir.path], expectSuccess: true)
assertTrue(widgetDryRunOutput.contains("실기기 위젯 액션 검증을 완료했습니다."), "widget dry-run should print closure comment")
assertTrue(widgetDryRunOutput.contains("DRY RUN: no GitHub comment was posted."), "widget dry-run should explain posting did not happen")

let widgetMismatchOutput = runPoster(arguments: ["widget", "--issue", "482", widgetTempDir.path], expectSuccess: false)
assertTrue(widgetMismatchOutput.contains("surface widget must target issue #408"), "widget poster should reject mismatched issue")

let fakeWidgetGH = makeFakeGH(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
let widgetPostOutput = runPoster(
    arguments: ["widget", "--issue", "408", widgetTempDir.path, "--post"],
    environment: ["DOGAREA_GH_BIN": fakeWidgetGH.binary.path],
    expectSuccess: true
)
let widgetGHLog = loadAbsolute(fakeWidgetGH.log)
assertTrue(widgetGHLog.contains("issue comment 408 --body-file"), "widget post should call gh issue comment with issue 408")
assertTrue(widgetPostOutput.contains("POSTED issue #408"), "widget post should report successful post")

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
    .replacingOccurrences(of: "- Pass / Fail:", with: "- Pass / Fail: Pass")
    .replacingOccurrences(of: "- Remaining Blockers:", with: "- Remaining Blockers: none")
    .replacingOccurrences(of: "- Linked Issue / PR Comment:", with: "- Linked Issue / PR Comment: issue comment url")

let authURL = writeMarkdown(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString), filename: "auth.md", content: filledAuth)
let authDryRunOutput = runPoster(
    arguments: [
        "auth-smtp",
        "--issue", "482",
        authURL.path,
        "--negative-guard", "SMTP-101: cooldown suppressed with retry_after_seconds=60",
        "--negative-provider-event", "SMTP-102: bounce observed with provider_event_id=evt-1",
    ],
    expectSuccess: true
)
assertTrue(authDryRunOutput.contains("custom SMTP rollout 운영 증적을 확인했습니다."), "auth dry-run should print closure comment")
assertTrue(authDryRunOutput.contains("DRY RUN: no GitHub comment was posted."), "auth dry-run should explain posting did not happen")

let fakeAuthGH = makeFakeGH(in: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
let authPostOutput = runPoster(
    arguments: [
        "auth-smtp",
        "--issue", "482",
        authURL.path,
        "--negative-guard", "SMTP-101: cooldown suppressed with retry_after_seconds=60",
        "--negative-provider-event", "SMTP-102: bounce observed with provider_event_id=evt-1",
        "--post",
    ],
    environment: ["DOGAREA_GH_BIN": fakeAuthGH.binary.path],
    expectSuccess: true
)
let authGHLog = loadAbsolute(fakeAuthGH.log)
assertTrue(authGHLog.contains("issue comment 482 --body-file"), "auth post should call gh issue comment with issue 482")
assertTrue(authPostOutput.contains("POSTED issue #482"), "auth post should report successful post")

print("PASS: manual closure comment poster contract checks")
