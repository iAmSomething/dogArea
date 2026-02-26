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
let notificationCenterView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let checklist = load("docs/release-regression-checklist-v1.md")
let specDoc = load("docs/profile-edit-flow-v1.md")

assertTrue(settingViewModel.contains("enum ProfileEditValidationError"), "setting view model should define edit validation errors")
assertTrue(settingViewModel.contains("func updateProfileDetails"), "setting view model should expose profile edit save API")
assertTrue(settingViewModel.contains("profile_edit_save"), "profile edit should publish selected pet sync source")
assertTrue(settingViewModel.contains("normalizeOptionalText"), "profile edit should trim optional text fields")
assertTrue(settingViewModel.contains("(0...30).contains"), "profile edit should validate age range 0...30")

assertTrue(notificationCenterView.contains("프로필 편집"), "notification center should expose profile edit entry")
assertTrue(notificationCenterView.contains("ProfileFieldEditSheet"), "notification center should present profile edit sheet")
assertTrue(notificationCenterView.contains("TextField(\"프로필 메시지\""), "profile edit sheet should include profile message field")
assertTrue(notificationCenterView.contains("TextField(\"나이 (0~30)\""), "profile edit sheet should include age input")
assertTrue(notificationCenterView.contains("Picker(\"성별\""), "profile edit sheet should include gender picker")

assertTrue(specDoc.contains("#113"), "spec doc should bind to issue #113")
assertTrue(specDoc.contains("나이(0~30)"), "spec doc should define age validation")
assertTrue(checklist.contains("기존 가입 사용자 프로필 편집"), "release checklist should include profile edit regression")

print("PASS: profile edit flow unit checks")
