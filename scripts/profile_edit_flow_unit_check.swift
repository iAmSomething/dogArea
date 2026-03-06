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

let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let profileEditSheet = load("dogArea/Views/ProfileSettingView/ProfileFieldEditSheet.swift")
let profileEditSheetViewModel = load("dogArea/Views/ProfileSettingView/ProfileFieldEditSheetViewModel.swift")
let sharedProfileEditor = load("dogArea/Views/GlobalViews/ProfileEditor/ProfileEditorCards.swift")
let sharedImageSection = load("dogArea/Views/GlobalViews/ProfileEditor/ProfileEditorImageSection.swift")
let petManagementEditSheet = load("dogArea/Views/ProfileSettingView/Components/PetManagementEditPetSheet.swift")
let onboardingViews = loadMany([
    "dogArea/Views/SigningView/ProfileSettingsView.swift",
    "dogArea/Views/SigningView/PetProfileSettingView.swift"
])
let specDoc = load("docs/profile-edit-flow-v1.md")

assertTrue(settingViewModel.contains("case invalidPetName"), "setting view model should validate empty pet names")
assertTrue(settingViewModel.contains("func updateProfileDetails(\n        profileName:"), "setting view model should expose async profile edit API")
assertTrue(settingViewModel.contains("petName:"), "profile edit save path should include pet name")
assertTrue(settingViewModel.contains("UserProfileDraft("), "profile edit should reuse shared user draft validation")
assertTrue(settingViewModel.contains("PetProfileDraft("), "profile edit should reuse shared pet draft validation")

assertTrue(profileEditSheet.contains("ProfileEditorUserFieldsCard"), "profile edit sheet should use shared user editor card")
assertTrue(profileEditSheet.contains("ProfileEditorPetFieldsCard"), "profile edit sheet should use shared pet editor card")
assertTrue(profileEditSheet.contains("ProfileEditorImageSection"), "profile edit sheet should use shared image section")
assertTrue(profileEditSheetViewModel.contains("@Published var petName: String"), "profile edit sheet view model should track editable pet name")
assertTrue(profileEditSheetViewModel.contains("petName: String"), "profile edit provider should pass pet name through save pipeline")

assertTrue(sharedProfileEditor.contains("struct ProfileEditorUserFieldsCard"), "shared profile editor should define user card")
assertTrue(sharedProfileEditor.contains("struct ProfileEditorPetFieldsCard"), "shared profile editor should define pet card")
assertTrue(sharedImageSection.contains("struct ProfileEditorImageSection"), "shared profile editor should define image section")
assertTrue(onboardingViews.contains("ProfileEditorUserFieldsCard"), "onboarding should reuse shared user card")
assertTrue(onboardingViews.contains("ProfileEditorPetFieldsCard"), "onboarding should reuse shared pet card")
assertTrue(onboardingViews.contains("ProfileEditorImageSection"), "onboarding should reuse shared image section")
assertTrue(petManagementEditSheet.contains("ProfileEditorPetFieldsCard"), "pet management edit should reuse shared pet editor card")
assertTrue(petManagementEditSheet.contains("ProfileEditorImageSection"), "pet management edit should reuse shared image section")

assertTrue(specDoc.contains("반려견 추가"), "spec doc should include pet add flow")
assertTrue(specDoc.contains("기존 반려견 편집"), "spec doc should include existing pet edit flow")
assertTrue(specDoc.contains("대표 반려견 지정"), "spec doc should include primary pet flow")
assertTrue(specDoc.contains("비활성/재활성"), "spec doc should include activation management flow")

print("PASS: profile edit flow unit checks")
