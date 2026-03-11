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

let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let settingProductSurface = load("dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+ProductSurface.swift")
let settingsView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let surfaceModels = load("dogArea/Source/Domain/Profile/Models/SettingsSurfaceModels.swift")
let productSurfaceService = load("dogArea/Source/Domain/Profile/Services/SettingsProductSurfaceService.swift")
let actionCard = load("dogArea/Views/ProfileSettingView/Components/SettingsActionSectionCardView.swift")
let appInfoCard = load("dogArea/Views/ProfileSettingView/Components/SettingsAppInfoCardView.swift")
let documentSheet = load("dogArea/Views/ProfileSettingView/Components/SettingsDocumentSheetView.swift")
let featureRegression = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(settingViewModel.contains("@Published var notificationSettingsSummary"), "settings view model should publish notification summary")
assertTrue(settingViewModel.contains("@Published var appMetadata"), "settings view model should publish app metadata")
assertTrue(settingViewModel.contains("let appMetadataService: SettingsAppMetadataProviding"), "settings view model should inject app metadata service")
assertTrue(settingViewModel.contains("let notificationAuthorizationService: SettingsNotificationAuthorizationProviding"), "settings view model should inject notification authorization service")
assertTrue(settingViewModel.contains("let settingsSurfaceCatalogService: SettingsSurfaceCatalogProviding"), "settings view model should inject surface catalog service")

assertTrue(settingProductSurface.contains("func refreshProductSurface() async"), "settings product surface support should expose refreshProductSurface")
assertTrue(settingProductSurface.contains("var appSettingsActions: [SettingsSurfaceAction]"), "settings product surface support should expose app settings actions")
assertTrue(settingProductSurface.contains("var legalDocumentActions: [SettingsSurfaceAction]"), "settings product surface support should expose legal actions")
assertTrue(settingProductSurface.contains("var supportActions: [SettingsSurfaceAction]"), "settings product surface support should expose support actions")
assertTrue(settingProductSurface.contains("var appInfoRows: [SettingsInfoRow]"), "settings product surface support should expose app info rows")

assertTrue(surfaceModels.contains("struct SettingsDocumentContent"), "settings surface models should define document content")
assertTrue(surfaceModels.contains("enum SettingsSurfaceActionTarget"), "settings surface models should define action targets")
assertTrue(surfaceModels.contains("let badgeTone: SettingsPrivacyTone?"), "settings surface models should model badge tone explicitly")
assertTrue(surfaceModels.contains("supportEmail: \"st939823@gmail.com\""), "settings surface models should keep support email placeholder")

assertTrue(productSurfaceService.contains("UIApplication.openSettingsURLString"), "product surface service should expose system settings deep link")
assertTrue(productSurfaceService.contains("badgeText: \"허용됨\""), "product surface service should expose user-facing notification allow copy")
assertTrue(productSurfaceService.contains("badgeText: \"꺼짐\""), "product surface service should expose user-facing notification disabled copy")
assertTrue(productSurfaceService.contains("badgeText: \"미설정\""), "product surface service should expose user-facing notification unresolved copy")
assertTrue(productSurfaceService.contains("개인정보처리방침"), "product surface service should define privacy policy document")
assertTrue(productSurfaceService.contains("이용약관"), "product surface service should define terms document")
assertTrue(productSurfaceService.contains("오픈소스/SDK 안내"), "product surface service should define license/sdk document")
assertTrue(productSurfaceService.contains("issues/new/choose"), "product surface service should expose bug report URL")

assertTrue(settingsView.contains("SettingsActionSectionCardView"), "settings view should render action section card")
assertTrue(settingsView.contains("SettingsAppInfoCardView"), "settings view should render app info card")
assertTrue(settingsView.contains("SettingsDocumentSheetView"), "settings view should render document sheet")
assertTrue(settingsView.contains("settings.section.appSettings"), "settings view should expose app settings section identifier")
assertTrue(settingsView.contains("settings.section.legal"), "settings view should expose legal section identifier")
assertTrue(settingsView.contains("settings.section.support"), "settings view should expose support section identifier")
assertTrue(settingsView.contains("settings.section.appInfo"), "settings view should expose app info section identifier")
assertTrue(productSurfaceService.contains("settings.app.notifications"), "product surface service should define notification entry identifier")
assertTrue(productSurfaceService.contains("settings.support.email"), "product surface service should define support email entry identifier")

assertTrue(actionCard.contains("action.accessibilityIdentifier"), "settings action card should apply row accessibility identifiers")
assertTrue(actionCard.contains("badgeForegroundColor"), "settings action card should style badges by tone instead of a fixed color")
assertTrue(appInfoCard.contains("row.accessibilityIdentifier"), "settings app info card should apply row accessibility identifiers")
assertTrue(documentSheet.contains("sheet.settings.document."), "settings document sheet should expose accessibility identifier")

assertTrue(featureRegression.contains("testFeatureRegression_SettingsProductSectionsExposeOperationalEntries"), "feature regression UI tests should cover settings product sections")
assertTrue(featureRegression.contains("시스템 설정 열기"), "feature regression UI tests should assert app settings operational row")
assertTrue(featureRegression.contains("개인정보처리방침"), "feature regression UI tests should assert privacy row")
assertTrue(featureRegression.contains("개발자 문의 메일"), "feature regression UI tests should assert support operational row")
assertTrue(featureRegression.contains("앱 버전"), "feature regression UI tests should assert app info row")
assertTrue(featureRegressionScript.contains("testFeatureRegression_SettingsProductSectionsExposeOperationalEntries"), "feature regression runner should include settings product surface test")
assertTrue(iosCheck.contains("swift scripts/settings_product_surface_unit_check.swift"), "ios_pr_check should include settings product surface unit check")

print("PASS: settings product surface unit checks")
