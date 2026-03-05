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

let rivalViewModel = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")

assertTrue(
    rivalViewModel.contains("guard authSessionStore.currentTokenSession() != nil else"),
    "rival tab should require token session before treating user as authenticated"
)
assertTrue(
    rivalViewModel.contains("private func isAuthFailure(_ error: Error) -> Bool"),
    "rival tab should classify auth failure status codes explicitly"
)
assertTrue(
    rivalViewModel.contains("persistLocationSharingPreference(false, for: affectedUserId)"),
    "rival tab should disable location sharing state on auth failure"
)
assertTrue(
    !rivalViewModel.contains("authSessionStore.clearTokenSession()"),
    "rival tab should not clear local token session on edge-function auth failure"
)
assertTrue(
    rivalViewModel.contains("인증 세션 확인이 필요해요. 다시 로그인 후 시도해주세요."),
    "rival tab should expose explicit re-login guidance on auth failure"
)

print("PASS: rival auth session guard unit checks")
