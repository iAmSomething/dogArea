import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 텍스트 파일을 로드합니다.
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
let rival = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let settings = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let matrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/non-map-custom-header-safearea-contract-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(scaffold.contains("nonMapRootHeaderTopSpacing: CGFloat = 12"), "AppTabScaffold should define the shared non-map root header top spacing")
assertTrue(scaffold.contains("struct NonMapRootHeaderContainer<Content: View>"), "AppTabScaffold should define a reusable non-map root header container")
assertTrue(scaffold.contains("struct NonMapRootTopChromeContainer<Content: View>"), "AppTabScaffold should define a reusable non-map root top chrome container")
assertTrue(scaffold.contains("func nonMapRootTopChrome<Chrome: View>("), "AppTabScaffold should expose the reusable non-map root top chrome modifier")
assertTrue(scaffold.contains("func nonMapRootPinnedHeaderLayout<Chrome: View>("), "AppTabScaffold should expose a pinned-header-specific fixed chrome layout")
assertTrue(scaffold.contains("topSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootHeaderTopSpacing"), "NonMapRootHeaderContainer should default to the shared header top spacing")
assertTrue(scaffold.contains("bottomSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootChromeBottomSpacing"), "NonMapRootTopChromeContainer should default to the shared chrome bottom spacing")

assertTrue(home.contains(".nonMapRootTopChrome {") && home.contains("homeHeaderSection"), "Home should render the first custom header through nonMapRootTopChrome")
assertTrue(!home.contains("HomeRootLayoutMetrics"), "Home should not keep a per-screen root header top padding enum")

assertTrue(walkList.contains(".nonMapRootPinnedHeaderLayout(bottomSpacing: 18)") && walkList.contains("WalkListDashboardHeaderView("), "WalkList should render the pinned-header root chrome through the separated layout")
assertTrue(!walkList.contains("WalkListRootLayoutMetrics"), "WalkList should not keep a per-screen root header top padding enum")

assertTrue(rival.contains(".nonMapRootTopChrome(bottomSpacing: 12)") && rival.contains("rivalHeaderSection"), "Rival should render the first custom header through nonMapRootTopChrome")
assertTrue(!rival.contains("RivalRootLayoutMetrics"), "Rival should not keep a per-screen root header top padding enum")

assertTrue(settings.contains(".nonMapRootTopChrome {") && settings.contains("settingsHeader("), "Settings should render the first custom header through nonMapRootTopChrome")
assertTrue(!settings.contains(".padding(.top, 24)"), "Settings should not keep a hard-coded root top padding above the custom header")

assertTrue(doc.contains("inline navigation bar 상세 화면"), "Contract doc should distinguish inline navigation detail screens")
assertTrue(doc.contains("지도(full-bleed) 화면"), "Contract doc should distinguish full-bleed map screens")
assertTrue(doc.contains("nonMapRootTopChrome"), "Contract doc should describe the reusable fixed top chrome modifier")
assertTrue(doc.contains("nonMapRootPinnedHeaderLayout"), "Contract doc should describe the pinned-header layout variant")
assertTrue(doc.contains("NonMapRootTopChromeContainer"), "Contract doc should describe the reusable top chrome container")
assertTrue(doc.contains("홈"), "Contract doc should list Home as a baseline screen")
assertTrue(doc.contains("산책 기록"), "Contract doc should list WalkList as a baseline screen")
assertTrue(doc.contains("라이벌"), "Contract doc should list Rival as a baseline screen")

assertTrue(featureTests.contains("testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar"), "FeatureRegressionUITests should keep the non-map tab root header regression test")
assertTrue(featureTests.contains("testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar"), "FeatureRegressionUITests should keep the sticky section header regression test")
assertTrue(matrix.contains("FR-TABROOT-001"), "UI regression matrix should keep the non-map tab root header regression row")
assertTrue(readme.contains("docs/non-map-custom-header-safearea-contract-v1.md"), "README should index the non-map custom header contract doc")
assertTrue(iosPRCheck.contains("swift scripts/non_map_custom_header_safearea_contract_unit_check.swift"), "ios_pr_check should run the non-map custom header contract check")

print("PASS: non-map custom header safe area contract checks")
