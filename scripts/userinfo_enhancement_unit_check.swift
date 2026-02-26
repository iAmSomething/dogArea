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

let userDefaultsFile = load("dogArea/Source/UserdefaultSetting.swift")
let signingViewModel = load("dogArea/Views/SigningView/SigningViewModel.swift")
let profileSettings = load("dogArea/Views/SigningView/ProfileSettingsView.swift")
let petProfileSettings = load("dogArea/Views/SigningView/PetProfileSettingView.swift")
let notificationCenterView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let checklist = load("docs/release-regression-checklist-v1.md")
let specDoc = load("docs/userinfo-enhancement-v1.md")

assertTrue(userDefaultsFile.contains("case profileMessage"), "user defaults should persist profile message key")
assertTrue(userDefaultsFile.contains("let profileMessage: String?"), "UserInfo should contain profileMessage")
assertTrue(userDefaultsFile.contains("enum PetGender"), "PetGender enum should exist")
assertTrue(userDefaultsFile.contains("var breed: String?"), "PetInfo should include breed field")
assertTrue(userDefaultsFile.contains("var ageYears: Int?"), "PetInfo should include ageYears field")
assertTrue(userDefaultsFile.contains("var gender: PetGender"), "PetInfo should include gender field")

assertTrue(signingViewModel.contains("@Published var userProfileMessage"), "signup view model should expose user profile message")
assertTrue(signingViewModel.contains("@Published var petBreed"), "signup view model should expose pet breed")
assertTrue(signingViewModel.contains("@Published var petAgeYearsText"), "signup view model should expose pet age input")
assertTrue(signingViewModel.contains("@Published var petGender"), "signup view model should expose pet gender")
assertTrue(signingViewModel.contains("profileMessage: normalizedProfileMessage"), "signup save should include profile message")

assertTrue(profileSettings.contains("프로필 메시지"), "profile settings should include profile message input")
assertTrue(petProfileSettings.contains("강아지 상세 정보"), "pet profile settings should include detail section")
assertTrue(petProfileSettings.contains("Picker(\"성별\""), "pet profile settings should include gender picker")

assertTrue(notificationCenterView.contains("petDetailsText"), "notification center should render pet detail summary")
assertTrue(notificationCenterView.contains("profileMessage"), "notification center should render user profile message")

assertTrue(checklist.contains("프로필 메시지"), "release checklist should include profile message regression check")
assertTrue(checklist.contains("품종/나이/성별"), "release checklist should include pet detail regression check")
assertTrue(specDoc.contains("profileMessage"), "spec should define profileMessage field")
assertTrue(specDoc.contains("breed"), "spec should define pet breed field")

print("PASS: userinfo enhancement unit checks")
