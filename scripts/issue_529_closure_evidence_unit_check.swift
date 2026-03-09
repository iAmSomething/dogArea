import Foundation

/// 조건이 참인지 검증합니다.
/// - Parameters:
///   - condition: 평가할 조건식입니다.
///   - message: 실패 시 출력할 설명입니다.
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

let evidence = load("docs/issue-529-closure-evidence-v1.md")
let designDoc = load("docs/walklist-design-refresh-v1.md")
let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let presentationService = load("dogArea/Views/WalkListView/WalkListPresentationService.swift")
let headerView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let walkListCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListCell.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#529"), "evidence doc should reference issue #529")
assertTrue(evidence.contains("PR: `#556`") || evidence.contains("PR `#556`"), "evidence doc should reference implementation PR #556")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("WalkListMetricTileView"), "evidence doc should mention the metric tile-based cell hierarchy")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(designDoc.contains("상단 허브"), "walk list design doc should describe the top hub hierarchy")
assertTrue(walkListView.contains("WalkListDashboardHeaderView"), "WalkListView should render the dashboard header")
assertTrue(presentationService.contains("func makeOverview"), "presentation service should define the overview builder")
assertTrue(headerView.contains("walklist.header"), "dashboard header should expose a stable accessibility identifier")
assertTrue(walkListCell.contains("WalkListMetricTileView"), "walk list cell should use metric tiles")
assertTrue(walkListCell.contains("title: \"넓이\"") || walkListCell.contains("영역 넓이"), "walk list cell should surface area")
assertTrue(walkListCell.contains("title: \"포인트\"") || walkListCell.contains("포인트 수"), "walk list cell should surface point count")
assertTrue(featureTests.contains("testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar"), "feature regression tests should cover the walk list tab-bar safety case")
assertTrue(featureTests.contains("testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards"), "feature regression tests should cover the walk list header hierarchy")
assertTrue(readme.contains("docs/issue-529-closure-evidence-v1.md"), "README should index the issue #529 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_529_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #529 closure evidence check")

print("PASS: issue #529 closure evidence unit checks")
