import Foundation

/// 조건이 거짓일 때 실패 메시지를 출력하고 스크립트를 종료합니다.
/// - Parameters:
///   - condition: 반드시 참이어야 하는 검증 조건입니다.
///   - message: 실패 시 표준 에러에 출력할 설명입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 UTF-8 텍스트 파일을 읽어옵니다.
/// - Parameter relativePath: 저장소 루트에서 시작하는 상대 경로입니다.
/// - Returns: 파일의 전체 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let profileEditorImageSection = load("dogArea/Views/GlobalViews/ProfileEditor/ProfileEditorImageSection.swift")
let settingsView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let editableImageButton = load("dogArea/Views/ProfileSettingView/Components/SettingsEditableImageButton.swift")
let profileEditSheet = load("dogArea/Views/ProfileSettingView/ProfileFieldEditSheet.swift")
let petManagementSheet = load("dogArea/Views/ProfileSettingView/Components/PetManagementSheet.swift")
let petManagementEditSheet = load("dogArea/Views/ProfileSettingView/Components/PetManagementEditPetSheet.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(profileEditorImageSection.contains("previewAccessibilityIdentifier"), "profile editor image section should require preview accessibility identifiers")
assertTrue(profileEditorImageSection.contains("Button {"), "profile editor image section should open album from image tap")
assertTrue(profileEditorImageSection.contains("사진을 탭하면 앨범이 바로 열립니다."), "profile editor image section should explain tap-to-open album affordance")
assertTrue(profileEditorImageSection.contains("Label(\"사진 변경\""), "profile editor image section should render a photo change affordance label")
assertTrue(profileEditorImageSection.contains("Button(\"카메라\")"), "profile editor image section should keep camera as a secondary action")
assertTrue(profileEditorImageSection.contains("Button(resetButtonTitle)"), "profile editor image section should keep reset as a secondary action")
assertTrue(profileEditorImageSection.contains("\"앨범\"") == false, "profile editor image section should not keep a dedicated album CTA button")

assertTrue(editableImageButton.contains("SettingsEditableImageButton"), "settings should define a dedicated editable image button component")
assertTrue(editableImageButton.contains("accessibilityHint(\"탭하면 편집 화면으로 이동합니다.\")"), "editable image button should expose a clear accessibility hint")
assertTrue(editableImageButton.contains("Label(\"사진 변경\""), "editable image button should display the photo change badge")

assertTrue(settingsView.contains("settings.profile.image"), "settings view should expose user image entry accessibility identifier")
assertTrue(settingsView.contains("settings.pet.image"), "settings view should expose pet image entry accessibility identifier")
assertTrue(settingsView.contains("SettingsEditableImageButton("), "settings view should use the dedicated editable image button component")

assertTrue(profileEditSheet.contains("settings.profileEditor.userImage"), "profile edit sheet should expose user image tap target identifier")
assertTrue(profileEditSheet.contains("settings.profileEditor.petImage"), "profile edit sheet should expose pet image tap target identifier")
assertTrue(petManagementSheet.contains("settings.petManagement.add.image"), "pet management add sheet should expose image tap target identifier")
assertTrue(petManagementEditSheet.contains("settings.petManagement.edit.image"), "pet management edit sheet should expose image tap target identifier")

assertTrue(featureRegression.contains("testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit"), "feature regression UI tests should cover settings image tap affordance")
assertTrue(featureRunner.contains("testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit"), "feature regression runner should include the settings image affordance regression")
assertTrue(iosCheck.contains("swift scripts/settings_image_entry_affordance_unit_check.swift"), "ios_pr_check should include the settings image entry affordance check")

print("PASS: settings image entry affordance unit checks")
