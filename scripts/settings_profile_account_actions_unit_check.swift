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

let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let profileEditSheet = load("dogArea/Views/ProfileSettingView/ProfileFieldEditSheet.swift")
let notificationCenterView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let supabaseInfrastructure = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(settingViewModel.contains("private let imageRepository: ProfileImageRepository"), "setting view model should inject image repository")
assertTrue(settingViewModel.contains("private let accountDeletionService: AccountDeletionServiceProtocol"), "setting view model should inject account deletion service")
assertTrue(settingViewModel.contains("func updateProfileDetails(\n        profileName:"), "setting view model should expose async profile save with display name")
assertTrue(settingViewModel.contains("func deleteAccount() async -> Result<Void, Error>"), "setting view model should expose account deletion API")

assertTrue(profileEditSheet.contains("TextField(\"사용자 이름\""), "profile edit sheet should include user name field")
assertTrue(profileEditSheet.contains("Section(\"프로필 이미지\")"), "profile edit sheet should include profile image section")
assertTrue(profileEditSheet.contains("Button(\"앨범\")"), "profile edit sheet should provide photo library action")
assertTrue(profileEditSheet.contains("Button(\"카메라\")"), "profile edit sheet should provide camera action")

assertTrue(notificationCenterView.contains("settings.account.delete"), "settings should expose account deletion button")
assertTrue(notificationCenterView.contains("handleAccountDeletion"), "settings should handle account deletion action")

assertTrue(supabaseInfrastructure.contains("final class SupabaseAccountDeletionService"), "supabase layer should implement account deletion service")
assertTrue(supabaseInfrastructure.contains(".auth(path: \"user\")"), "account deletion service should call supabase auth user endpoint")

print("PASS: settings profile/account actions unit checks")
