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
let rivalView = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let titleView = load("dogArea/Views/GlobalViews/TitleTextView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/rival-top-safearea-contract-v1.md")
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
    rivalView.contains(".nonMapRootTopChrome(bottomSpacing: 12)") &&
    rivalView.contains("rivalHeaderSection"),
    "RivalTabView should move the first custom header into fixed nonMapRootTopChrome"
)
assertTrue(
    !rivalView.contains("RivalRootLayoutMetrics"),
    "RivalTabView should not keep a screen-specific root header top padding enum"
)
assertTrue(
    rivalView.contains(".appTabRootScrollLayout(\n            extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,\n            topSafeAreaPadding: 0\n        )"),
    "RivalTabView should use fixed top chrome and zero the blank top inset"
)
assertTrue(
    !rivalView.contains("topSafeAreaPadding: RivalRootLayoutMetrics.rootTopSafeAreaPadding"),
    "RivalTabView should not override the root top inset directly"
)
assertTrue(
    !rivalView.contains(".padding(.top, RivalRootLayoutMetrics.contentTopPadding)"),
    "RivalTabView should not reintroduce a dedicated root header top padding"
)
assertTrue(
    rivalView.contains("-UITest.RivalHeaderLongSubtitle"),
    "RivalTabView should expose a UITest long subtitle route"
)
assertTrue(
    rivalView.contains("rival.header.section") && rivalView.contains("rival.header.badges"),
    "RivalTabView should expose header and first badge row accessibility identifiers"
)
assertTrue(
    titleView.contains("accessibilityIdentifierPrefix"),
    "TitleTextView should support scoped accessibility identifiers for root headers"
)
assertTrue(
    titleView.contains(".fixedSize(horizontal: false, vertical: true)"),
    "TitleTextView text should use fixed vertical sizing for long subtitles and Dynamic Type"
)
assertTrue(
    titleView.contains(".appScaledFont("),
    "TitleTextView should use scaled fonts for Dynamic Type stability"
)
assertTrue(
    featureTests.contains("testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle"),
    "Feature regression tests should cover rival header safe area with long subtitles"
)
assertTrue(
    featureScript.contains("testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle"),
    "Feature regression script should run the rival header safe area test"
)
assertTrue(
    regressionMatrix.contains("FR-RIVAL-003"),
    "UI regression matrix should register the rival header safe area case"
)
assertTrue(
    doc.contains("공통 scaffold 책임") &&
    doc.contains("라이벌 헤더 책임") &&
    doc.contains("공통 TitleTextView 책임") &&
    doc.contains("AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding") &&
    doc.contains("nonMapRootTopChrome"),
    "Rival safe area contract doc should document scaffold, rival header, shared title responsibilities, and the fixed non-map top chrome"
)
assertTrue(
    readme.contains("docs/rival-top-safearea-contract-v1.md"),
    "README should index the rival top safe area contract doc"
)
assertTrue(
    iosCheck.contains("swift scripts/rival_top_safearea_contract_unit_check.swift"),
    "ios_pr_check should include the rival safe area contract unit check"
)

print("PASS: rival top safe area contract checks")
