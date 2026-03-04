import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let authSource = load("dogArea/Source/ProfileRepository.swift")
let sessionSource = load("dogArea/Source/UserdefaultSetting.swift")

assertTrue(
    authSource.contains("switch request"),
    "auth use case should branch onboarding decision by request type"
)
assertTrue(
    authSource.contains("case .emailSignUp:"),
    "email signup should be the explicit onboarding entry path"
)
assertTrue(
    authSource.contains("case .emailSignIn, .apple:"),
    "email login and apple login should not force onboarding by local profile mismatch"
)
assertTrue(
    sessionSource.contains("guard DefaultAuthSessionStore.shared.currentTokenSession() != nil else"),
    "feature gate session should require token session to treat user as member"
)
assertTrue(
    sessionSource.contains("guard authSessionStore.currentTokenSession() != nil else"),
    "auth flow member user id resolution should require token session"
)

print("PASS: auth onboarding/session consistency unit checks")
