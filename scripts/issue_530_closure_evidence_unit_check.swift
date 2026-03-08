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

let evidence = load("docs/issue-530-closure-evidence-v1.md")
let designDoc = load("docs/walklist-detail-design-refresh-v1.md")
let detailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let heroSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailHeroSectionView.swift")
let mapSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailMapSectionView.swift")
let timelineSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailTimelineSectionView.swift")
let metaSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailMetaSectionView.swift")
let actionSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailActionSectionView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#530"), "evidence doc should reference issue #530")
assertTrue(evidence.contains("PR: `#557`") || evidence.contains("PR `#557`"), "evidence doc should reference implementation PR #557")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("Hero / Map / Timeline / Meta / Actions"), "evidence doc should record the section hierarchy")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(designDoc.contains("상단 요약 카드"), "detail design doc should describe the top summary hierarchy")
assertTrue(detailView.contains("WalkListDetailHeroSectionView"), "detail view should render the hero section")
assertTrue(detailView.contains("WalkListDetailMapSectionView"), "detail view should render the map section")
assertTrue(detailView.contains("WalkListDetailTimelineSectionView"), "detail view should render the timeline section")
assertTrue(detailView.contains("WalkListDetailMetaSectionView"), "detail view should render the meta section")
assertTrue(detailView.contains("WalkListDetailActionSectionView"), "detail view should render the action section")
assertTrue(heroSection.contains("walklist.detail.hero"), "hero section should expose a stable accessibility identifier")
assertTrue(mapSection.contains("walklist.detail.map"), "map section should expose a stable accessibility identifier")
assertTrue(timelineSection.contains("walklist.detail.timeline"), "timeline section should expose a stable accessibility identifier")
assertTrue(metaSection.contains("walklist.detail.meta"), "meta section should expose a stable accessibility identifier")
assertTrue(actionSection.contains("walklist.detail.actions"), "action section should expose a stable accessibility identifier")
assertTrue(featureTests.contains("testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy"), "feature regression tests should cover the detail action hierarchy")
assertTrue(readme.contains("docs/issue-530-closure-evidence-v1.md"), "README should index the issue #530 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_530_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #530 closure evidence check")

print("PASS: issue #530 closure evidence unit checks")
