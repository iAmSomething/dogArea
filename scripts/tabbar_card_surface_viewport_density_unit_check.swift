import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let scaffold = load("dogArea/Views/GlobalViews/BaseView/AppTabScaffold.swift")
let tabBar = load("dogArea/Views/GlobalViews/BaseView/CustomTabBar.swift")
let home = load("dogArea/Views/HomeView/HomeView.swift")
let walkList = load("dogArea/Views/WalkListView/WalkListView.swift")
let rival = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let settings = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let doc = load("docs/tabbar-card-surface-viewport-density-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(scaffold.contains("defaultTabBarReservedHeight: CGFloat = 110"), "AppTabScaffold should tighten the reserved tab bar height")
assertTrue(scaffold.contains("nonMapRootTopSafeAreaPadding: CGFloat = 12"), "AppTabScaffold should use the compact non-map top safe area padding")
assertTrue(scaffold.contains("nonMapRootHeaderTopSpacing: CGFloat = 8"), "AppTabScaffold should use the compact non-map header top spacing")
assertTrue(scaffold.contains("nonMapRootChromeBottomSpacing: CGFloat = 12"), "AppTabScaffold should use the compact chrome-to-content spacing")
assertTrue(tabBar.contains("RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)"), "CustomTabBar should use a rounded card surface")
assertTrue(!tabBar.contains("LinearGradient("), "CustomTabBar should remove the full-width gradient band")
assertTrue(tabBar.contains("centerButtonLift: CGFloat = 10"), "CustomTabBar should keep the map button emphasis on a compact lift")

for (name, source) in [
    ("HomeView", home),
    ("WalkListView", walkList),
    ("RivalTabView", rival),
    ("NotificationCenterView", settings)
] {
    assertTrue(
        source.contains("AppTabLayoutMetrics.defaultScrollExtraBottomPadding"),
        "\(name) should use the shared default bottom padding contract"
    )
}

assertTrue(
    featureTests.contains("testFeatureRegression_TabBarUsesCompactCardSurfaceWithoutHeavyBand"),
    "Feature regression tests should cover the compact tab bar surface"
)
assertTrue(
    featureScript.contains("testFeatureRegression_TabBarUsesCompactCardSurfaceWithoutHeavyBand"),
    "Feature regression runner should include the compact tab bar surface case"
)
assertTrue(doc.contains("#728") && doc.contains("#773"), "tab bar density doc should reference both issues")
assertTrue(readme.contains("docs/tabbar-card-surface-viewport-density-v1.md"), "README should index the tab bar density doc")
assertTrue(iosCheck.contains("swift scripts/tabbar_card_surface_viewport_density_unit_check.swift"), "ios_pr_check should include the tab bar density unit check")

print("PASS: tab bar card surface viewport density unit checks")
