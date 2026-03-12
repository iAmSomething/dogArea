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
let authTemplate = load("docs/auth-smtp-rollout-evidence-template-v1.md")
let missingEvidenceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("md")

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
    .replacingOccurrences(of: "- `email_sent`:", with: "- `email_sent`: 2")
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

let evidenceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("md")
write(evidenceURL, content: filledAuth)

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
