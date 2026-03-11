import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트를 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/privacy-deletion-request-intake-tracking-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let privacyCenterView = load("dogArea/Views/ProfileSettingView/SettingsPrivacyCenterView.swift")
let notificationCenterView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let privacyCenterService = load("dogArea/Source/Domain/Profile/Services/SettingsPrivacyCenterService.swift")
let deletionRequestService = load("dogArea/Source/Domain/Profile/Services/SettingsPrivacyDeletionRequestService.swift")
let deletionRequestStore = load("dogArea/Source/UserDefaultsSupport/PrivacyDeletionRequestStore.swift")
let deletionRequestSheet = load("dogArea/Views/ProfileSettingView/Components/SettingsPrivacyDeletionRequestSheetView.swift")
let deletionRequestSheetViewModel = load("dogArea/Views/ProfileSettingView/SettingsPrivacyDeletionRequestSheetViewModel.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")

assertTrue(doc.contains("- Issue: #720"), "delete request tracking doc must reference issue #720")
assertTrue(doc.contains("요청 ID"), "delete request tracking doc must define request id usage")
assertTrue(doc.contains("24시간"), "delete request tracking doc must define first reply SLA")
assertTrue(doc.contains("MFMailComposeViewController"), "delete request tracking doc must define composer-first policy")
assertTrue(doc.contains("mailto:"), "delete request tracking doc must define mailto fallback policy")
assertTrue(doc.contains("전송 확인 대기"), "delete request tracking doc must define handoff state")
assertTrue(doc.contains("회신 대기"), "delete request tracking doc must define awaiting reply state")
assertTrue(doc.contains("상태 문의"), "delete request tracking doc must define inquiry path")

assertTrue(privacyCenterView.contains("settings.privacyCenter.deleteRequest"), "privacy center should expose a dedicated delete request card")
assertTrue(privacyCenterView.contains("settings.privacyCenter.deleteRequest.open"), "privacy center should expose a stable delete request CTA identifier")
assertTrue(notificationCenterView.contains("SettingsPrivacyDeletionRequestSheetView"), "settings host should present the dedicated delete request sheet")
assertTrue(privacyCenterService.contains("deleteRequestProcessDocument"), "privacy center service should expose a delete request process document")
assertTrue(deletionRequestService.contains("[DogArea 삭제요청]"), "deletion request service should prefix request emails with the canonical subject marker")
assertTrue(deletionRequestService.contains("requestIdPrefix = \"DEL\""), "deletion request service should generate canonical request ids")
assertTrue(deletionRequestStore.contains("privacy.center.deletionRequest.v1"), "deletion request store should persist records in a dedicated scoped key")
assertTrue(deletionRequestSheet.contains("sheet.settings.privacyDeletionRequest"), "delete request sheet should expose a stable accessibility identifier")
assertTrue(deletionRequestSheet.contains("settings.privacyDeletionRequest.primary"), "delete request sheet should expose primary send action identifier")
assertTrue(deletionRequestSheet.contains("settings.privacyDeletionRequest.inquiry"), "delete request sheet should expose status inquiry action identifier")
assertTrue(deletionRequestSheet.contains("settings.privacyDeletionRequest.copyBody"), "delete request sheet should expose copy body action identifier")
assertTrue(deletionRequestSheet.contains("settings.privacyDeletionRequest.copyRequestId"), "delete request sheet should expose copy request id action identifier")
assertTrue(deletionRequestSheetViewModel.contains("confirmExternalMailSent"), "delete request sheet view model should support fallback send confirmation")

assertTrue(featureRegression.contains("testFeatureRegression_SettingsPrivacyDeletionRequestFlowExplainsNextSteps"), "feature regression tests should cover the delete request flow surface")
assertTrue(featureRunner.contains("testFeatureRegression_SettingsPrivacyDeletionRequestFlowExplainsNextSteps"), "feature regression runner should include the delete request flow test")
assertTrue(readme.contains("docs/privacy-deletion-request-intake-tracking-v1.md"), "README must index the delete request tracking doc")
assertTrue(prCheck.contains("swift scripts/privacy_deletion_request_tracking_unit_check.swift"), "ios_pr_check must run the delete request tracking unit check")

print("PASS: privacy deletion request tracking unit checks")
