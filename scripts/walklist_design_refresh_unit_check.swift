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
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: UTF-8 디코딩 결과 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let walkListViewModel = load("dogArea/Views/WalkListView/WalkListViewModel.swift")
let walkListCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListCell.swift")
let headerView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let contextCardView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListContextSummaryCardView.swift")
let statusCardView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListStatusCardView.swift")
let sectionHeaderView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListSectionHeaderView.swift")
let metricTileView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMetricTileView.swift")
let presentationService = load("dogArea/Views/WalkListView/WalkListPresentationService.swift")
let models = load("dogArea/Views/WalkListView/WalkListPresentationModels.swift")
let featureRegressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let doc = load("docs/walklist-design-refresh-v1.md")
let readme = load("README.md")

assertTrue(walkListView.contains("WalkListDashboardHeaderView"), "WalkListView should render dashboard header view")
assertTrue(walkListView.contains("accessibilityIdentifierPrefix: \"walklist.header\""), "WalkListView should expose the fixed root header accessibility prefix")
assertTrue(walkListView.contains("WalkListStatusCardView"), "WalkListView should render shared status card view")
assertTrue(walkListView.contains("WalkListSectionHeaderView"), "WalkListView should render section header view")
assertTrue(!headerView.contains("walklist.header"), "Dashboard cards should no longer own the root header accessibility identifier")
assertTrue(walkListView.contains("walklist.guest.login"), "WalkListView should keep guest login CTA identifier")
assertTrue(walkListViewModel.contains("WalkListPresentationServicing"), "WalkListViewModel should depend on presentation service protocol")
assertTrue(walkListViewModel.contains("overviewModel"), "WalkListViewModel should publish overview model")
assertTrue(walkListViewModel.contains("sectionModels"), "WalkListViewModel should publish section models")
assertTrue(walkListViewModel.contains("stateCardModel"), "WalkListViewModel should publish state card model")
assertTrue(walkListViewModel.contains("refreshPresentation()"), "WalkListViewModel should refresh presentation snapshots")
assertTrue(walkListCell.contains("WalkListMetricTileView"), "WalkListCell should use metric tile subviews")
assertTrue(walkListCell.contains("title: \"넓이\"") || walkListCell.contains("영역 넓이"), "WalkListCell should surface area metrics")
assertTrue(walkListCell.contains("title: \"포인트\"") || walkListCell.contains("포인트 수"), "WalkListCell should surface point count metrics")
assertTrue(headerView.contains("walklist.summary"), "Header view should expose summary card identifier")
assertTrue(headerView.contains("WalkListContextSummaryCardView"), "Header view should compose the dedicated context card view")
assertTrue(contextCardView.contains("walklist.context"), "Context card view should expose context card identifier")
assertTrue(walkListView.contains("walklist.showAllRecords"), "WalkListView should keep filtered empty CTA identifier")
assertTrue(sectionHeaderView.contains("model.subtitle"), "Section header should render subtitle copy")
assertTrue(metricTileView.contains("appDynamicHex"), "Metric tile should adopt current surface color system")
assertTrue(models.contains("WalkListOverviewModel"), "Presentation models should define overview model")
assertTrue(models.contains("WalkListStateCardModel"), "Presentation models should define state card model")
assertTrue(presentationService.contains("makeOverview"), "Presentation service should build overview model")
assertTrue(presentationService.contains("makeSections"), "Presentation service should build grouped sections")
assertTrue(presentationService.contains("makeStateCard"), "Presentation service should build state card models")
assertTrue(featureRegressionTests.contains("testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards"), "FeatureRegressionUITests should cover the walk list header hub")
assertTrue(featureRegressionScript.contains("testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards"), "Feature regression script should run the walk list header hub regression")
assertTrue(doc.contains("상단 허브 구조"), "Walk list design doc should describe header hub structure")
assertTrue(doc.contains("리스트 셀 구조"), "Walk list design doc should describe cell structure")
assertTrue(readme.contains("docs/walklist-design-refresh-v1.md"), "README should index the walk list design refresh doc")

print("PASS: walk list design refresh unit checks")
