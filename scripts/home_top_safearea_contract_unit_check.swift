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
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let headerView = load("dogArea/Views/HomeView/HomeSubView/HomeHeaderSectionView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/home-top-safearea-contract-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    scaffold.contains("func appTabRootScrollLayout("),
    "AppTabScaffold should keep the shared root scroll layout contract"
)
assertTrue(
    scaffold.contains("nonMapRootTopSafeAreaPadding"),
    "AppTabScaffold should expose the shared non-map root top inset"
)
assertTrue(
    homeView.contains("private enum HomeRootLayoutMetrics"),
    "HomeView should centralize home-specific layout metrics"
)
assertTrue(
    homeView.contains("static let contentTopPadding"),
    "HomeView should keep content spacing independent from the root safe area contract"
)
assertTrue(
    homeView.contains(".appTabRootScrollLayout(extraBottomPadding: 12)"),
    "HomeView should use the shared non-map root scroll layout contract"
)
assertTrue(
    !homeView.contains("topSafeAreaPadding: HomeRootLayoutMetrics.rootTopSafeAreaPadding"),
    "HomeView should not override the root top inset directly"
)
assertTrue(
    homeView.contains(".padding(.top, HomeRootLayoutMetrics.contentTopPadding)"),
    "HomeView content spacing should remain a smaller content-only top padding"
)
assertTrue(
    headerView.contains("home.header.section"),
    "Home header should expose a root accessibility identifier for frame assertions"
)
assertTrue(
    headerView.contains("home.header.title") && headerView.contains("home.header.subtitle"),
    "Home header should expose title and subtitle accessibility identifiers"
)
assertTrue(
    headerView.contains(".fixedSize(horizontal: false, vertical: true)"),
    "Home header text should use fixed vertical sizing for long names and Dynamic Type"
)
assertTrue(
    featureTests.contains("testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames"),
    "Feature regression tests should cover home header safe area with long names"
)
assertTrue(
    featureScript.contains("testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames"),
    "Feature regression script should run the home header safe area test"
)
assertTrue(
    regressionMatrix.contains("FR-HOME-001"),
    "UI regression matrix should register the home header safe area case"
)
assertTrue(
    doc.contains("공통 scaffold 책임") &&
    doc.contains("홈 헤더 책임") &&
    doc.contains("AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding"),
    "Home safe area contract doc should document scaffold/header ownership and the shared non-map contract"
)
assertTrue(
    readme.contains("docs/home-top-safearea-contract-v1.md"),
    "README should index the home top safe area contract doc"
)
assertTrue(
    iosCheck.contains("swift scripts/home_top_safearea_contract_unit_check.swift"),
    "ios_pr_check should include the home safe area contract unit check"
)

print("PASS: home top safe area contract checks")
