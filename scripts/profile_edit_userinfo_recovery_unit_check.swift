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

let settingViewModel = loadMany([
    "dogArea/Views/ProfileSettingView/SettingViewModel.swift",
    "dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+ProfileEditing.swift"
])

assertTrue(
    settingViewModel.contains("let authSessionStore: AuthSessionStoreProtocol"),
    "setting view model should inject auth session store for user info recovery"
)
assertTrue(
    settingViewModel.contains("authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared"),
    "setting view model init should provide default auth session store"
)
assertTrue(
    settingViewModel.contains("currentEditableUserInfo("),
    "setting view model should recover editable user info when local snapshot is missing"
)
assertTrue(
    settingViewModel.contains("guard let identity = authSessionStore.currentIdentity()"),
    "recovery path should derive user id from current auth identity"
)
assertTrue(
    settingViewModel.contains("return .failure(ProfileEditValidationError.userNotFound)"),
    "profile save should still fail explicitly when both local and session identity are unavailable"
)

print("PASS: profile edit userinfo recovery unit checks")
