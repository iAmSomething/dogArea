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

let detailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let detailModels = load("dogArea/Views/WalkListView/WalkListDetailPresentationModels.swift")
let detailService = load("dogArea/Views/WalkListView/WalkListDetailPresentationService.swift")
let heroSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailHeroSectionView.swift")
let mapSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailMapSectionView.swift")
let timelineSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailTimelineSectionView.swift")
let metaSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailMetaSectionView.swift")
let actionSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailActionSectionView.swift")
let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let featureRegressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walklist-detail-design-refresh-v1.md")
let readme = load("README.md")

assertTrue(detailView.contains("WalkListDetailHeroSectionView"), "detail view should render hero section")
assertTrue(detailView.contains("WalkListDetailMapSectionView"), "detail view should render map section")
assertTrue(detailView.contains("WalkListDetailTimelineSectionView"), "detail view should render timeline section")
assertTrue(detailView.contains("WalkListDetailMetaSectionView"), "detail view should render meta section")
assertTrue(detailView.contains("WalkListDetailActionSectionView"), "detail view should render action section")
assertTrue(detailView.contains("screen.walkListDetail.content"), "detail view should expose detail screen accessibility identifier")
assertTrue(detailView.contains("prepareShareItems"), "detail view should still prepare share items")
assertTrue(detailView.contains("ActivityShareSheet(isPresented: $showShareSheet, items: shareItems)"), "detail view should still present share sheet through direct presenter")
assertTrue(detailView.contains("walklist.detail.share.presenter.active"), "detail view should expose share presenter regression marker")
assertTrue(detailModels.contains("WalkListDetailPresentationSnapshot"), "detail presentation models should define snapshot")
assertTrue(detailModels.contains("WalkListDetailPresentationServicing"), "detail presentation models should define service protocol")
assertTrue(detailService.contains("makeVisibleTimelineLocations"), "detail service should condense long timelines")
assertTrue(detailService.contains("pointRoleBreakdown"), "detail service should summarize point roles")
assertTrue(heroSection.contains("walklist.detail.hero"), "hero section should expose accessibility identifier")
assertTrue(mapSection.contains("walklist.detail.map"), "map section should expose accessibility identifier")
assertTrue(timelineSection.contains("walklist.detail.timeline"), "timeline section should expose accessibility identifier")
assertTrue(metaSection.contains("walklist.detail.meta"), "meta section should expose accessibility identifier")
assertTrue(actionSection.contains("walklist.detail.action.share"), "action section should expose share CTA identifier")
assertTrue(actionSection.contains("walklist.detail.action.save"), "action section should expose save CTA identifier")
assertTrue(actionSection.contains("walklist.detail.action.dismiss"), "action section should expose dismiss CTA identifier")
assertTrue(walkListView.contains("-UITest.WalkDetailPreviewRoute"), "walk list should support a UI test detail preview route")
assertTrue(featureRegressionTests.contains("testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy"), "feature regression tests should cover walk list detail hierarchy")
assertTrue(featureRegressionScript.contains("testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy"), "feature regression script should run walk list detail hierarchy regression")
assertTrue(uiMatrix.contains("FR-WALK-003"), "ui regression matrix should document the walk list detail regression")
assertTrue(doc.contains("CTA 위계"), "detail design doc should define CTA hierarchy")
assertTrue(doc.contains("포인트 타임라인 카드"), "detail design doc should define timeline hierarchy")
assertTrue(readme.contains("docs/walklist-detail-design-refresh-v1.md"), "README should index the walk list detail doc")

print("PASS: walk list detail design refresh unit checks")
