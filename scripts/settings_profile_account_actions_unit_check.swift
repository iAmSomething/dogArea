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
let petManagementSheet = load("dogArea/Views/ProfileSettingView/Components/PetManagementSheet.swift")
let petManagementEditSheet = load("dogArea/Views/ProfileSettingView/Components/PetManagementEditPetSheet.swift")
let petManagementService = load("dogArea/Source/Domain/Profile/Services/SettingsPetManagementService.swift")
let supabaseInfrastructure = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let profileEditorCards = load("dogArea/Views/GlobalViews/ProfileEditor/ProfileEditorCards.swift")
let profileEditorImageSection = load("dogArea/Views/GlobalViews/ProfileEditor/ProfileEditorImageSection.swift")

assertTrue(settingViewModel.contains("private let petManagementService: SettingsPetManaging"), "setting view model should inject pet management service")
assertTrue(settingViewModel.contains("func addPet("), "setting view model should expose add pet API")
assertTrue(settingViewModel.contains("func setPrimaryPet(_ petId: String) throws"), "setting view model should expose primary pet API")
assertTrue(settingViewModel.contains("func setPetActive(_ petId: String, isActive: Bool) throws"), "setting view model should expose pet activation API")

assertTrue(profileEditSheet.contains("캐리커처 생성/재생성"), "profile edit sheet should preserve caricature action")
assertTrue(profileEditSheet.contains("ProfileEditorPetFieldsCard"), "profile edit sheet should reuse shared pet fields")
assertTrue(profileEditSheet.contains("ProfileEditorImageSection"), "profile edit sheet should reuse shared image section")
assertTrue(profileEditorCards.contains("settings.profile.field.userName"), "profile editor should expose user name accessibility identifier")
assertTrue(profileEditorCards.contains("settings.profile.field.profileMessage"), "profile editor should expose profile message accessibility identifier")
assertTrue(profileEditorCards.contains("settings.profile.field.petName"), "profile editor should expose pet name accessibility identifier")
assertTrue(profileEditorImageSection.contains("resetButtonEnabled"), "shared image section should support context-aware reset state")

assertTrue(notificationCenterView.contains("PetManagementSheet"), "settings should present pet management sheet")
assertTrue(notificationCenterView.contains("선택 반려견 편집"), "settings should expose selected pet edit action")
assertTrue(notificationCenterView.contains("반려견 관리"), "settings should expose pet management action")

assertTrue(petManagementSheet.contains("활성 반려견"), "pet management sheet should render active pet section")
assertTrue(petManagementSheet.contains("비활성 반려견"), "pet management sheet should render inactive pet section")
assertTrue(petManagementSheet.contains("반려견 추가"), "pet management sheet should render add pet action")
assertTrue(petManagementSheet.contains("PetManagementEditPetSheet"), "pet management sheet should present edit sheet")
assertTrue(petManagementEditSheet.contains("sheet.settings.petManagement.edit.save"), "pet edit sheet should expose save accessibility identifier")

assertTrue(petManagementService.contains("enum SettingsPetManagementError"), "pet management service should define domain errors")
assertTrue(petManagementService.contains("func setPetActive("), "pet management service should handle pet activation changes")
assertTrue(petManagementService.contains("func setPrimaryPet("), "pet management service should handle primary pet changes")
assertTrue(petManagementService.contains("func updatePet("), "pet management service should handle existing pet updates")

assertTrue(supabaseInfrastructure.contains("final class SupabaseAccountDeletionService"), "supabase layer should implement account deletion service")
assertTrue(supabaseInfrastructure.contains(".auth(path: \"user\")"), "account deletion service should call supabase auth user endpoint")

print("PASS: settings profile/account actions unit checks")
