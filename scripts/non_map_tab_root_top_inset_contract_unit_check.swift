import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let scaffold = load("dogArea/Views/GlobalViews/BaseView/AppTabScaffold.swift")
let home = load("dogArea/Views/HomeView/HomeView.swift")
let walkList = load("dogArea/Views/WalkListView/WalkListView.swift")
let walkListHeader = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let rival = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let settings = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let mapTopChrome = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let matrix = load("docs/ui-regression-matrix-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let doc = load("docs/non-map-tab-root-top-inset-contract-v1.md")

assertTrue(scaffold.contains("nonMapRootTopSafeAreaPadding: CGFloat = 18"), "AppTabScaffold should define the non-map root top inset default")
assertTrue(scaffold.contains("mapOverlayTopExtraSpacing: CGFloat = 8"), "AppTabScaffold should keep a separate map overlay top spacing")
assertTrue(scaffold.contains("extra: CGFloat = mapOverlayTopExtraSpacing"), "topOverlaySpacing should default to the map overlay spacing")
assertTrue(scaffold.contains("topSafeAreaPadding: CGFloat = AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding"), "appTabRootScrollLayout should default to the non-map root top inset")
assertTrue(scaffold.contains(".safeAreaInset(edge: .top, spacing: 0)"), "AppTabScaffold should reserve non-map top inset with safeAreaInset")
assertTrue(!scaffold.contains(".safeAreaPadding(.top, topSafeAreaPadding)"), "AppTabScaffold should not use safeAreaPadding for non-map root top inset")
assertTrue(scaffold.contains("func nonMapRootTopChrome<Chrome: View>("), "AppTabScaffold should expose the fixed non-map root top chrome modifier")
assertTrue(scaffold.contains("func nonMapRootPinnedHeaderLayout<Chrome: View>("), "AppTabScaffold should expose the pinned-header fixed chrome layout")

assertTrue(home.contains(".appTabRootScrollLayout(extraBottomPadding: 12, topSafeAreaPadding: 0)"), "Home should move the root header into fixed top chrome")
assertTrue(home.contains(".nonMapRootTopChrome {"), "Home should render the root header in fixed top chrome")
assertTrue(!home.contains("topSafeAreaPadding: HomeRootLayoutMetrics.rootTopSafeAreaPadding"), "Home should not override the root top inset directly")
assertTrue(rival.contains(".appTabRootScrollLayout(\n            extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,\n            topSafeAreaPadding: 0\n        )"), "Rival should move the root header into fixed top chrome")
assertTrue(rival.contains(".nonMapRootTopChrome(bottomSpacing: 12)"), "Rival should render the root header in fixed top chrome")
assertTrue(!rival.contains("topSafeAreaPadding: RivalRootLayoutMetrics.rootTopSafeAreaPadding"), "Rival should not override the root top inset directly")
assertTrue(walkList.contains(".appTabRootScrollLayout(\n            extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,\n            topSafeAreaPadding: 0\n        )"), "WalkList should move the root header into fixed top chrome")
assertTrue(walkList.contains(".nonMapRootPinnedHeaderLayout(bottomSpacing: 18)"), "WalkList should render the root header in the pinned-header fixed chrome layout")
assertTrue(walkList.contains("accessibilityIdentifierPrefix: \"walklist.header\""), "WalkList should expose stable root header accessibility identifiers")
assertTrue(walkList.contains("-UITest.WalkListHeaderLongSubtitle"), "WalkList should support the long subtitle regression route")
assertTrue(settings.contains(".appTabRootScrollLayout(\n            extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,\n            topSafeAreaPadding: 0\n        )"), "Settings should move the root header into fixed top chrome")
assertTrue(settings.contains(".nonMapRootTopChrome {"), "Settings should render the root header in fixed top chrome")

assertTrue(!walkListHeader.contains("TitleTextView("), "WalkList dashboard cards should not own the shared title chrome anymore")
assertTrue(settings.contains("accessibilityIdentifierPrefix: \"settings.header\""), "Settings header should expose stable accessibility identifiers")
assertTrue(settings.contains("settings.header.section"), "Settings header should expose a section identifier")
assertTrue(settings.contains("-UITest.SettingsHeaderLongSubtitle"), "Settings header should support the long subtitle regression route")

assertTrue(mapTopChrome.contains("topOverlaySpacing(safeAreaTopInset: safeAreaTopInset, extra: 10)"), "Map should remain on the separate overlay spacing contract")
assertTrue(doc.contains("지도 탭은 `appTabRootScrollLayout` 공통 inset을 사용하지 않는다."), "Contract doc should declare the map exception")
assertTrue(doc.contains("safeAreaInset(edge: .top)"), "Contract doc should describe safeAreaInset as the shared root reservation mechanism")
assertTrue(doc.contains("pinnedViews: [.sectionHeaders]"), "Contract doc should describe pinned section header compatibility")
assertTrue(doc.contains("nonMapRootTopChrome"), "Contract doc should describe fixed top chrome outside scroll content")
assertTrue(doc.contains("nonMapRootPinnedHeaderLayout"), "Contract doc should describe the pinned-header top chrome layout")
assertTrue(doc.contains("#628`" ) || doc.contains("#628"), "Contract doc should link the related home issue")
assertTrue(doc.contains("#622`" ) || doc.contains("#622"), "Contract doc should link the related walk list issue")
assertTrue(doc.contains("#629`" ) || doc.contains("#629"), "Contract doc should link the related rival issue")

assertTrue(featureTests.contains("testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar"), "FeatureRegressionUITests should cover the non-map tab root safe area contract")
assertTrue(featureScript.contains("testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar"), "Feature regression script should run the non-map tab root safe area test")
assertTrue(matrix.contains("FR-TABROOT-001"), "UI regression matrix should document FR-TABROOT-001")
assertTrue(readme.contains("docs/non-map-tab-root-top-inset-contract-v1.md"), "README should index the non-map tab root top inset contract")
assertTrue(iosPRCheck.contains("swift scripts/non_map_tab_root_top_inset_contract_unit_check.swift"), "ios_pr_check should run the non-map tab root top inset check")

print("PASS: non-map tab root top inset contract checks")
