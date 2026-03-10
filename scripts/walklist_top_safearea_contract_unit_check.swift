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
let walkList = load("dogArea/Views/WalkListView/WalkListView.swift")
let sectionHeader = load("dogArea/Views/WalkListView/WalkListSubView/WalkListSectionHeaderView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let contractDoc = load("docs/walklist-top-safearea-contract-v1.md")
let nonMapDoc = load("docs/non-map-tab-root-top-inset-contract-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    scaffold.contains(".safeAreaInset(edge: .top, spacing: 0)"),
    "AppTabScaffold should reserve non-map top inset with safeAreaInset"
)
assertTrue(
    !scaffold.contains(".safeAreaPadding(.top, topSafeAreaPadding)"),
    "AppTabScaffold should not use safeAreaPadding for the root top reservation anymore"
)
assertTrue(
    scaffold.contains("func nonMapRootPinnedHeaderLayout<Chrome: View>(") &&
    walkList.contains(".nonMapRootPinnedHeaderLayout(bottomSpacing: 18)") &&
    walkList.contains("TitleTextView(") &&
    walkList.contains("WalkListDashboardHeaderView("),
    "WalkListView should keep only the root title chrome fixed through the pinned-header layout and render dashboard cards in scroll content"
)
assertTrue(
    !walkList.contains("WalkListRootLayoutMetrics"),
    "WalkListView should not keep a per-screen root header top padding enum"
)
assertTrue(
    walkList.contains(".appTabRootScrollLayout(\n            extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,\n            topSafeAreaPadding: 0\n        )"),
    "WalkListView should use fixed top chrome and zero the blank top inset"
)
assertTrue(
    walkList.contains("pinnedViews: [.sectionHeaders]"),
    "WalkListView should keep the pinned section header structure covered by this contract"
)
assertTrue(
    !walkList.contains(".padding(.top, WalkListRootLayoutMetrics.contentTopPadding)"),
    "WalkListView should not reintroduce a dedicated root header top padding"
)
assertTrue(
    sectionHeader.contains(".accessibilityIdentifier(model.accessibilityIdentifier ?? \"\")"),
    "WalkListSectionHeaderView should expose stable accessibility identifiers for sticky header assertions"
)
assertTrue(
    featureTests.contains("testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar"),
    "Feature regression tests should cover the sticky section header safe area case"
)
assertTrue(
    featureScript.contains("testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar"),
    "Feature regression script should run the walk list sticky section header test"
)
assertTrue(
    regressionMatrix.contains("FR-WALK-002C"),
    "UI regression matrix should register the walk list sticky section header case"
)
assertTrue(
    contractDoc.contains("safeAreaInset(edge: .top)") &&
    contractDoc.contains("WalkListSectionHeaderView") &&
    contractDoc.contains("walklist.section.thisWeek") &&
    contractDoc.contains("nonMapRootPinnedHeaderLayout"),
    "WalkList top safe area contract doc should document the scaffold, fixed top chrome, sticky header, and QA target"
)
assertTrue(
    nonMapDoc.contains("safeAreaInset(edge: .top)") &&
    nonMapDoc.contains("pinnedViews: [.sectionHeaders]") &&
    nonMapDoc.contains("nonMapRootPinnedHeaderLayout"),
    "Non-map root contract doc should mention safeAreaInset, pinned-header top chrome, and pinned section header compatibility"
)
assertTrue(
    readme.contains("docs/walklist-top-safearea-contract-v1.md"),
    "README should index the walk list top safe area contract doc"
)
assertTrue(
    iosCheck.contains("swift scripts/walklist_top_safearea_contract_unit_check.swift"),
    "ios_pr_check should include the walk list top safe area contract unit check"
)

print("PASS: walk list top safe area contract checks")
