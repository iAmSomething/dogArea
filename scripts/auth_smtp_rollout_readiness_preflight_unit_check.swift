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

/// Writes UTF-8 text into a temporary file URL.
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

/// Writes a placeholder asset file for auth SMTP evidence tests.
/// - Parameter url: Asset file URL to create.
func writeAsset(_ url: URL) {
    write(url, content: "placeholder-asset")
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
    - `email_sent`: 2
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

/// Asserts that a condition holds for the readiness preflight contract.
/// - Parameters:
///   - condition: Condition to validate.
///   - message: Failure message printed to stderr.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

/// Runs the readiness preflight script and captures combined output.
/// - Parameters:
///   - arguments: CLI arguments passed to the script.
///   - environment: Extra environment values for the subprocess.
/// - Returns: Combined stdout and stderr.
func runPreflight(arguments: [String] = [], environment: [String: String] = [:]) -> String {
    let process = Process()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["scripts/auth_smtp_rollout_readiness_check.sh"] + arguments

    var mergedEnvironment = ProcessInfo.processInfo.environment
    environment.forEach { mergedEnvironment[$0.key] = $0.value }
    process.environment = mergedEnvironment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        fputs("Failed to launch preflight: \(error)\n", stderr)
        exit(1)
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        fputs("Preflight should have succeeded.\n\(output)\n", stderr)
        exit(1)
    }

    return output
}

let script = load("scripts/auth_smtp_rollout_readiness_check.sh")
let doc = load("docs/auth-smtp-rollout-readiness-preflight-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let missingEvidenceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

assertTrue(script.contains("DOGAREA_AUTH_SMTP_PROVIDER"), "script should require provider env")
assertTrue(script.contains("DOGAREA_AUTH_SMTP_DNS_SPF"), "script should require DNS SPF env")
assertTrue(script.contains("ready-to-post"), "script should report ready-to-post state")
assertTrue(doc.contains("# Auth SMTP Rollout Readiness Preflight v1"), "doc title should exist")
assertTrue(doc.contains("blocked:dns-unverified"), "doc should list dns blocked state")
assertTrue(readme.contains("docs/auth-smtp-rollout-readiness-preflight-v1.md"), "README should link preflight doc")
assertTrue(iosPRCheck.contains("auth_smtp_rollout_readiness_preflight_unit_check.swift"), "ios_pr_check should run preflight check")
assertTrue(backendPRCheck.contains("auth_smtp_rollout_readiness_preflight_unit_check.swift"), "backend_pr_check should run preflight check")

let missingOutput = runPreflight()
assertTrue(missingOutput.contains("config-inputs: missing"), "missing env should report missing config")
assertTrue(missingOutput.contains("overall: blocked:missing-config"), "missing env should block rollout")

let dnsBlockedOutput = runPreflight(environment: [
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": missingEvidenceURL.path,
    "DOGAREA_AUTH_SMTP_PROJECT": "ttjiknenynbhbpoqoesq",
    "DOGAREA_AUTH_SMTP_PROVIDER": "Resend",
    "DOGAREA_AUTH_SMTP_SENDER_DOMAIN": "auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_HOST": "smtp.resend.com",
    "DOGAREA_AUTH_SMTP_PORT": "587",
    "DOGAREA_AUTH_SMTP_USER_MASK": "re_***",
    "DOGAREA_AUTH_SMTP_SENDER_NAME": "DogArea Auth",
    "DOGAREA_AUTH_SMTP_SENDER_EMAIL": "auth@auth.dogarea.app"
])
assertTrue(dnsBlockedOutput.contains("config-inputs: ready"), "filled config should report ready config")
assertTrue(dnsBlockedOutput.contains("dns-claims: missing"), "missing dns claims should report missing")
assertTrue(dnsBlockedOutput.contains("overall: blocked:dns-unverified"), "missing dns claims should block rollout")

let noEvidenceOutput = runPreflight(environment: [
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": missingEvidenceURL.path,
    "DOGAREA_AUTH_SMTP_PROJECT": "ttjiknenynbhbpoqoesq",
    "DOGAREA_AUTH_SMTP_PROVIDER": "Resend",
    "DOGAREA_AUTH_SMTP_SENDER_DOMAIN": "auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_HOST": "smtp.resend.com",
    "DOGAREA_AUTH_SMTP_PORT": "587",
    "DOGAREA_AUTH_SMTP_USER_MASK": "re_***",
    "DOGAREA_AUTH_SMTP_SENDER_NAME": "DogArea Auth",
    "DOGAREA_AUTH_SMTP_SENDER_EMAIL": "auth@auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_DNS_SPF": "pass",
    "DOGAREA_AUTH_SMTP_DNS_DKIM": "verified",
    "DOGAREA_AUTH_SMTP_DNS_DMARC": "present"
])
assertTrue(noEvidenceOutput.contains("evidence-status: missing"), "missing evidence file should report missing")
assertTrue(noEvidenceOutput.contains("overall: ready-for-live-send-evidence"), "ready config without evidence should request live-send evidence")

let evidenceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
writeFilledAuthBundle(at: evidenceURL)

let completeOutput = runPreflight(arguments: ["--evidence", evidenceURL.path], environment: [
    "DOGAREA_AUTH_SMTP_EVIDENCE_PATH": missingEvidenceURL.path,
    "DOGAREA_AUTH_SMTP_PROJECT": "ttjiknenynbhbpoqoesq",
    "DOGAREA_AUTH_SMTP_PROVIDER": "Resend",
    "DOGAREA_AUTH_SMTP_SENDER_DOMAIN": "auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_HOST": "smtp.resend.com",
    "DOGAREA_AUTH_SMTP_PORT": "587",
    "DOGAREA_AUTH_SMTP_USER_MASK": "re_***",
    "DOGAREA_AUTH_SMTP_SENDER_NAME": "DogArea Auth",
    "DOGAREA_AUTH_SMTP_SENDER_EMAIL": "auth@auth.dogarea.app",
    "DOGAREA_AUTH_SMTP_DNS_SPF": "pass",
    "DOGAREA_AUTH_SMTP_DNS_DKIM": "verified",
    "DOGAREA_AUTH_SMTP_DNS_DMARC": "present"
])
assertTrue(completeOutput.contains("evidence-status: complete"), "complete evidence should report complete")
assertTrue(completeOutput.contains("overall: ready-to-post"), "complete readiness should report ready-to-post")

print("PASS: auth smtp rollout readiness preflight unit checks")
