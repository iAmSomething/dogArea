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

let policyDoc = load("docs/ui-overlap-ellipsis-small-screen-policy-v1.md")
let walkListCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListCell.swift")
let metricTileView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMetricTileView.swift")
let primaryLoopCard = load("dogArea/Views/WalkListView/WalkListSubView/WalkListPrimaryLoopSummaryCardView.swift")
let contextCard = load("dogArea/Views/WalkListView/WalkListSubView/WalkListContextSummaryCardView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(policyDoc.contains("겹침 금지"), "policy doc should define overlap prohibition")
assertTrue(policyDoc.contains("`...` 금지"), "policy doc should define ellipsis prohibition")
assertTrue(policyDoc.contains("작은 화면 우선"), "policy doc should define small-screen-first policy")
assertTrue(policyDoc.contains("WalkListCell"), "policy doc should name the applied walk list cell surface")

assertTrue(walkListCell.contains("lineLimit(2)"), "walk list cell should allow wrapping instead of forcing ellipsis-prone single lines")
assertTrue(metricTileView.contains("lineLimit(3)"), "metric tile should allow multi-line values on small screens")
assertTrue(primaryLoopCard.contains("lineLimit(2)"), "primary loop card secondary copy should wrap instead of clipping")
assertTrue(contextCard.contains("lineLimit(2)"), "context helper copy should wrap instead of clipping")

assertTrue(featureTests.contains("testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen"), "feature regression tests should cover long metric tiles on small screens")
assertTrue(featureScript.contains("testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen"), "feature regression script should include the long metric tile small-screen case")
assertTrue(regressionMatrix.contains("FR-WALK-001C"), "ui regression matrix should index the small-screen long metric walk list case")
assertTrue(readme.contains("docs/ui-overlap-ellipsis-small-screen-policy-v1.md"), "README should index the UI overlap/ellipsis policy doc")
assertTrue(prCheck.contains("ui_overlap_ellipsis_small_screen_policy_unit_check.swift"), "ios_pr_check should execute the UI overlap/ellipsis policy check")

print("PASS: ui overlap/ellipsis/small-screen policy unit checks")
