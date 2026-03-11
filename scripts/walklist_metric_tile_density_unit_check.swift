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
/// - Returns: UTF-8 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let metricTileView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMetricTileView.swift")
let walkListCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListCell.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walklist-metric-tile-density-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(metricTileView.contains("minHeight: 64"), "metric tile should enforce a compact fixed minimum height")
assertTrue(metricTileView.contains("lineLimit(3)"), "metric tile should allow up to three lines for long values")
assertTrue(metricTileView.contains("allowsTightening(true)"), "metric tile should tighten long values before clipping")
assertTrue(metricTileView.contains(".accessibilityIdentifier(accessibilityIdentifier ?? \"\")"), "metric tile should expose its root accessibility identifier")
assertTrue(metricTileView.contains("detail: String?"), "metric tile detail should be optional")

assertTrue(walkListCell.contains("title: \"시간\""), "walk list cell should shorten duration metric title")
assertTrue(walkListCell.contains("title: \"넓이\""), "walk list cell should shorten area metric title")
assertTrue(walkListCell.contains("title: \"포인트\""), "walk list cell should shorten point metric title")
assertTrue(walkListCell.contains("detail: nil"), "walk list cell should remove verbose detail copy")
assertTrue(walkListCell.contains("size: 76"), "walk list cell should reduce thumbnail size")
assertTrue(walkListCell.contains("padding(12)"), "walk list cell should reduce outer padding")
assertTrue(walkListCell.contains("metricAccessibilityIdentifier"), "walk list cell should expose metric tile identifiers")
assertTrue(walkListCell.contains("lineLimit(2)"), "walk list cell should allow headline and pet context wrapping")
assertTrue(walkListCell.contains("walklist.cell."), "walk list cell should expose stable cell identifiers")

assertTrue(featureTests.contains("testFeatureRegression_WalkListMetricTilesStayCompactWithoutVerboseCopy"), "feature regression should cover walk list compact metric tiles")
assertTrue(featureTests.contains("testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen"), "feature regression should cover long value compactness on small screens")
assertTrue(featureScript.contains("testFeatureRegression_WalkListMetricTilesStayCompactWithoutVerboseCopy"), "feature regression script should run the compact metric tile test")
assertTrue(featureScript.contains("testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen"), "feature regression script should run the long-value compact tile test")
assertTrue(regressionMatrix.contains("FR-WALK-001B"), "ui regression matrix should include walk list metric density regression")
assertTrue(doc.contains("장문 설명은 제거"), "doc should describe verbose copy removal")
assertTrue(doc.contains("minHeight 64pt"), "doc should describe the compact tile height contract")
assertTrue(doc.contains("작은 화면"), "doc should describe the small-screen contract")
assertTrue(readme.contains("docs/walklist-metric-tile-density-v1.md"), "README should index the metric density doc")
assertTrue(prCheck.contains("walklist_metric_tile_density_unit_check.swift"), "ios_pr_check should run the metric density check")

print("PASS: walk list metric tile density unit checks")
