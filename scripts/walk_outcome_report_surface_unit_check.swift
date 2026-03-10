import Foundation

/// 조건이 거짓이면 표준 에러에 메시지를 출력하고 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
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

let models = load("dogArea/Views/WalkListView/WalkListDetailPresentationModels.swift")
let service = load("dogArea/Views/WalkListView/WalkListDetailPresentationService.swift")
let detailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let outcomeSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailOutcomeReportSectionView.swift")
let metadataStore = load("dogArea/Source/WalkSessionMetadataStore.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(models.contains("outcomeExplanation: WalkOutcomeExplanationDTO"), "detail presentation snapshot should carry the shared outcome explanation DTO")
assertTrue(service.contains("makeOutcomeExplanation"), "detail presentation service should normalize stored-walk outcome explanations")
assertTrue(service.contains("sessionMetadata?.outcomeSnapshot"), "detail presentation service should prefer persisted outcome snapshots")
assertTrue(metadataStore.contains("outcomeSnapshot: WalkOutcomeCalculationSnapshot?"), "walk session metadata should persist outcome calculation snapshots")
assertTrue(mapViewModel.contains("outcomeSnapshot:"), "map view model should persist outcome snapshots when saving walks")
assertTrue(detailView.contains("WalkListDetailOutcomeReportSectionView"), "walk list detail view should render the outcome report section")
assertTrue(outcomeSection.contains("walklist.detail.outcomeReport"), "outcome report section should expose the root accessibility identifier")
assertTrue(outcomeSection.contains("walklist.detail.outcomeReport.summary"), "outcome report section should expose the summary identifier")
assertTrue(outcomeSection.contains("walklist.detail.outcomeReport.exclusions.toggle"), "outcome report section should expose the exclusions toggle identifier")
assertTrue(outcomeSection.contains("walklist.detail.outcomeReport.connections.toggle"), "outcome report section should expose the connections toggle identifier")
assertTrue(outcomeSection.contains("walklist.detail.outcomeReport.contribution.toggle"), "outcome report section should expose the contribution toggle identifier")
assertTrue(featureTests.contains("testFeatureRegression_WalkListDetailOutcomeReportExplainsAppliedExcludedAndConnections"), "feature regression tests should cover stored-walk outcome report disclosure")
assertTrue(featureScript.contains("testFeatureRegression_WalkListDetailOutcomeReportExplainsAppliedExcludedAndConnections"), "feature regression runner should execute the stored-walk outcome report test")
assertTrue(iosPRCheck.contains("swift scripts/walk_outcome_report_surface_unit_check.swift"), "ios_pr_check should run the outcome report surface unit check")

print("PASS: walk outcome report surface checks")
