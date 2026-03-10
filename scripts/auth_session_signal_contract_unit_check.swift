import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Reads a repository-relative UTF-8 file.
/// - Parameter path: Repository-relative file path.
/// - Returns: Decoded file contents.
func read(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to read \(path)\n", stderr)
        exit(1)
    }
    return text
}

/// Fails the check when the condition is false.
/// - Parameters:
///   - condition: Boolean condition to validate.
///   - message: Failure message.
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let profileRepository = read("dogArea/Source/ProfileRepository.swift")
let appSource = read("dogArea/dogAreaApp.swift")
let authFlowCoordinator = read("dogArea/Source/AppSession/AuthFlowCoordinator.swift")
let supabaseInfrastructure = read("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let contractDoc = read("docs/auth-session-signal-contract-v1.md")
let readme = read("README.md")
let iosPRCheck = read("scripts/ios_pr_check.sh")

expect(
    profileRepository.contains("func persistAuthenticatedSession(identity: AuthenticatedUserIdentity, tokenSession: AuthTokenSession)"),
    "auth session store should expose logical authenticated-session persist API"
)
expect(
    profileRepository.contains("private struct PendingAuthSessionChange"),
    "auth session store should keep a coalescing payload"
)
expect(
    profileRepository.contains("Task { @MainActor [self] in"),
    "auth session signal delivery should hop to MainActor"
)
expect(
    profileRepository.contains("flushPendingSessionDidChangeIfNeeded()"),
    "auth session store should flush pending session changes on main actor"
)
expect(
    profileRepository.contains("\"reasons\": pending.reasons"),
    "auth session notification should include coalesced reasons"
)
expect(
    profileRepository.contains("\"transition\": pending.transition"),
    "auth session notification should include transition classification"
)
expect(
    profileRepository.contains("persistAuthenticatedSession(identity: result.credential.identity, tokenSession: tokenSession)"),
    "auth use case should persist identity/token as one logical transition"
)
expect(
    supabaseInfrastructure.contains("persistAuthenticatedSession(identity: refreshed.identity, tokenSession: tokenSession)"),
    "supabase refresh flow should persist refreshed identity/token as one logical transition"
)
expect(
    appSource.contains("authFlow.refresh()") && appSource.contains(".onAppear"),
    "app root should still refresh auth flow on initial appear"
)
expect(
    appSource.contains(".onReceive(NotificationCenter.default.publisher(for: .authSessionDidChange))") == false,
    "dogAreaApp should not duplicate auth session observer after auth flow owns the signal"
)
expect(
    authFlowCoordinator.contains("NotificationCenter.default.publisher(for: .authSessionDidChange)"),
    "auth flow coordinator should remain the root auth session observer"
)
expect(
    authFlowCoordinator.contains(".receive(on: RunLoop.main)"),
    "auth flow coordinator observer should stay on the main run loop"
)
expect(
    contractDoc.contains("persistAuthenticatedSession(identity:tokenSession:)"),
    "contract doc should explain logical session persist API"
)
expect(
    contractDoc.contains("dogAreaApp") && contractDoc.contains("AuthFlowCoordinator"),
    "contract doc should describe observer ownership"
)
expect(
    readme.contains("docs/auth-session-signal-contract-v1.md"),
    "README should index the auth session signal contract doc"
)
expect(
    iosPRCheck.contains("swift scripts/auth_session_signal_contract_unit_check.swift"),
    "ios_pr_check should run the auth session signal contract check"
)

print("PASS: auth session signal contract unit checks")
