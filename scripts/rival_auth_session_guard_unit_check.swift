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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let rivalViewModel = loadMany([
    "dogArea/Views/ProfileSettingView/RivalTabViewModel.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SessionLifecycle.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+ModerationAndLocation.swift"
])

assertTrue(
    rivalViewModel.contains("guard authSessionStore.currentTokenSession() != nil else"),
    "rival tab should require token session before treating user as authenticated"
)
assertTrue(
    rivalViewModel.contains("private func isAuthFailure(_ error: Error) -> Bool"),
    "rival tab should classify auth failure status codes explicitly"
)
assertTrue(
    rivalViewModel.contains("return authSessionStore.currentTokenSession() == nil"),
    "rival tab should only downgrade to re-login UX when the local token session is actually gone"
)
assertTrue(
    rivalViewModel.contains("private func isSessionPreservedUnauthorizedStatus(_ error: Error) -> Bool"),
    "rival tab should distinguish session-preserved 401/403 responses from real auth expiry"
)
assertTrue(
    rivalViewModel.contains("로그인은 유지되어 있어요. 서버 인증 상태를 다시 확인 중이니 잠시 후 다시 시도해주세요."),
    "rival tab should show a non-login retry message when a valid session still exists"
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
