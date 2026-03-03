import Foundation

struct Check {
    static var failed = false

    /// Assert a condition and print a CI-friendly result line.
    /// - Parameters:
    ///   - condition: Boolean assertion to evaluate.
    ///   - message: Human readable assertion description.
    /// - Returns: 없음. 실패 시 내부 `failed` 플래그를 `true`로 갱신합니다.
    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

let sensitiveKeys = [
    "OPENAI_API_KEY",
    "GEMINI_API_KEY",
    "GEMINI_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
]

let directSecretPatterns: [String] = [
    #"sk-[A-Za-z0-9]{20,}"#,
    #"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#,
]

/// Execute a shell command and return stdout as UTF-8 text.
/// - Parameters:
///   - launchPath: Executable path (for example `/usr/bin/env`).
///   - arguments: Command-line arguments passed to the executable.
/// - Returns: Captured stdout text. Returns empty string if execution fails.
func runCommand(_ launchPath: String, arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ""
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

/// Load all tracked files from git.
/// - Parameters: 없음.
/// - Returns: Repository-relative tracked file paths.
func trackedFiles() -> [String] {
    let output = runCommand("/usr/bin/env", arguments: ["git", "ls-files"])
    return output
        .split(separator: "\n")
        .map(String.init)
        .filter { !$0.isEmpty }
}

/// Read a UTF-8 text file if possible.
/// - Parameters:
///   - path: Repository-relative file path.
/// - Returns: File contents as UTF-8 text, or `nil` if unreadable/non-text.
func readTextFile(_ path: String) -> String? {
    try? String(contentsOfFile: path, encoding: .utf8)
}

/// Extract assignment RHS for a specific key from one line.
/// - Parameters:
///   - key: Sensitive key name to search.
///   - line: Single source line.
/// - Returns: RHS raw text after `=` or `:` if an assignment exists; otherwise `nil`.
func assignmentValue(for key: String, in line: String) -> String? {
    let escapedKey = NSRegularExpression.escapedPattern(for: key)
    let pattern = "(?:^|[^A-Za-z0-9_])\(escapedKey)\\s*[:=]\\s*(.*)$"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard let match = regex.firstMatch(in: line, options: [], range: range), match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: line) else {
        return nil
    }
    return String(line[valueRange])
}

/// Determine whether RHS text looks like a concrete hardcoded secret value.
/// - Parameters:
///   - rawValue: Raw assignment RHS text.
/// - Returns: `true` when value resembles a committed secret; otherwise `false`.
func looksLikeConcreteSecret(_ rawValue: String) -> Bool {
    var candidate = rawValue
    if let hashIndex = candidate.firstIndex(of: "#") {
        candidate = String(candidate[..<hashIndex])
    }

    candidate = candidate
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: ",;"))

    if candidate.count >= 2 &&
        ((candidate.hasPrefix("\"") && candidate.hasSuffix("\"")) ||
        (candidate.hasPrefix("'") && candidate.hasSuffix("'"))) {
        candidate.removeFirst()
        candidate.removeLast()
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if candidate.isEmpty { return false }

    let lower = candidate.lowercased()
    if candidate.hasPrefix("$") || candidate.hasPrefix("<") || candidate.hasPrefix("${{") ||
        lower.hasPrefix("env(") || lower.contains("secrets.") || lower.contains("server-only") {
        return false
    }

    if candidate.contains("sk-") || candidate.contains("AIza") {
        return true
    }

    return candidate.range(of: #"^[A-Za-z0-9._-]{20,}$"#, options: .regularExpression) != nil
}

/// Test a line against direct secret regex patterns.
/// - Parameters:
///   - line: Single source line.
/// - Returns: `true` when line contains explicit high-risk secret signatures.
func hasDirectSecretPattern(_ line: String) -> Bool {
    for pattern in directSecretPatterns {
        if line.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }
    return false
}

/// Scan repository files and collect secret exposure findings.
/// - Parameters: 없음.
/// - Returns: Array of findings in `path:line message` format.
func collectFindings() -> [String] {
    var findings: [String] = []
    for path in trackedFiles() {
        guard let text = readTextFile(path) else { continue }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, lineSub) in lines.enumerated() {
            let line = String(lineSub)
            let lineNo = index + 1

            if hasDirectSecretPattern(line) {
                findings.append("\(path):\(lineNo) direct secret pattern detected")
            }

            for key in sensitiveKeys {
                guard let value = assignmentValue(for: key, in: line) else { continue }
                if looksLikeConcreteSecret(value) {
                    findings.append("\(path):\(lineNo) hardcoded value for \(key)")
                }
            }
        }
    }
    return findings
}

let findings = collectFindings()
Check.assertTrue(findings.isEmpty, "repository should not contain hardcoded model/service secrets")

if !findings.isEmpty {
    findings.forEach { print("[DETAIL] \($0)") }
    exit(1)
}

print("PASS: security key exposure unit checks")
