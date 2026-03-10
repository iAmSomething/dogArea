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

let notificationView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let productSurface = load("dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+ProductSurface.swift")
let privacyCenterView = load("dogArea/Views/ProfileSettingView/SettingsPrivacyCenterView.swift")
let privacyCenterViewModel = load("dogArea/Views/ProfileSettingView/SettingsPrivacyCenterViewModel.swift")
let privacyEntryCard = load("dogArea/Views/ProfileSettingView/Components/SettingsPrivacyCenterEntryCardView.swift")
let privacyCenterModels = load("dogArea/Source/Domain/Profile/Models/SettingsPrivacyCenterModels.swift")
let privacyCenterService = load("dogArea/Source/Domain/Profile/Services/SettingsPrivacyCenterService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalViewModel = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(notificationView.contains("case privacyCenter"), "settings screen should define a dedicated privacy center sheet route")
assertTrue(notificationView.contains("SettingsPrivacyCenterEntryCardView"), "settings screen should render the privacy center entry card")
assertTrue(settingViewModel.contains("@Published var privacyCenterEntrySummary"), "settings view model should publish a privacy center entry summary")
assertTrue(productSurface.contains("privacyCenterService.loadEntrySummary"), "settings surface refresh should compute the privacy center entry summary")
assertTrue(privacyCenterView.contains("screen.settings.privacyCenter"), "privacy center screen should expose a stable accessibility identifier")
assertTrue(privacyCenterView.contains("settings.privacyCenter.primaryAction"), "privacy center screen should expose the primary action identifier")
assertTrue(privacyCenterViewModel.contains("nearbyService.setVisibility"), "privacy center view model should sync visibility through the nearby service")
assertTrue(privacyEntryCard.contains("settings.privacyCenter.entry"), "privacy center entry card should expose a stable entry identifier")
assertTrue(
    privacyCenterModels.contains("로그인/회원가입 열기") || privacyCenterService.contains("로그인/회원가입 열기"),
    "privacy center guest CTA copy should keep the canonical sign-in entry title"
)
assertTrue(mapViewModel.contains("privacyControlStateStore: PrivacyControlStateStoreProtocol = DefaultPrivacyControlStateStore.shared"), "map view model should consume the shared privacy control state store")
assertTrue(rivalViewModel.contains("privacyControlStateStore: PrivacyControlStateStoreProtocol = DefaultPrivacyControlStateStore.shared"), "rival view model should consume the shared privacy control state store")
assertTrue(featureRegression.contains("testFeatureRegression_SettingsPrivacyCenterRouteSurfacesControlAndDocuments"), "feature regression UI tests should cover the privacy center route")
assertTrue(featureRunner.contains("testFeatureRegression_SettingsPrivacyCenterRouteSurfacesControlAndDocuments"), "feature regression runner should include the privacy center route regression")
assertTrue(prCheck.contains("swift scripts/settings_privacy_center_surface_unit_check.swift"), "ios_pr_check should run the privacy center surface unit check")

print("PASS: settings privacy center surface unit checks")
