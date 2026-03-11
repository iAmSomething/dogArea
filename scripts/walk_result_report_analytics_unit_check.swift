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

let metricTracker = load("dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift")
let explanationModels = load("dogArea/Source/Domain/Map/Models/WalkOutcomeExplanationModels.swift")
let interactionService = load("dogArea/Source/Domain/Map/Services/WalkOutcomeReportInteractionService.swift")
let mapCard = load("dogArea/Views/MapView/MapSubViews/MapWalkSavedOutcomeCardView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let detailSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailOutcomeReportSectionView.swift")
let detailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let matrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walk-result-report-analytics-instrumentation-v1.md")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(metricTracker.contains("walkOutcomeReportPresented"), "metric tracker should define report presented event")
assertTrue(metricTracker.contains("walkOutcomeReportDismissed"), "metric tracker should define report dismissed event")
assertTrue(metricTracker.contains("walkOutcomeReportHistoryOpened"), "metric tracker should define report history opened event")
assertTrue(metricTracker.contains("walkOutcomeReportDetailOpened"), "metric tracker should define report detail opened event")
assertTrue(metricTracker.contains("walkOutcomeReportDisclosureToggled"), "metric tracker should define report disclosure event")
assertTrue(metricTracker.contains("walkOutcomeReportInquiryOpened"), "metric tracker should define report inquiry event")

assertTrue(explanationModels.contains("WalkOutcomeReportAnalyticsContext"), "outcome explanation models should define shared analytics context")
assertTrue(explanationModels.contains("analyticsContext: WalkOutcomeReportAnalyticsContext"), "DTO should carry analytics context")

assertTrue(interactionService.contains("protocol WalkOutcomeReportInteracting"), "interaction service protocol should exist")
assertTrue(interactionService.contains("trackPresented"), "interaction service should track presented event")
assertTrue(interactionService.contains("trackDismissed"), "interaction service should track dismissed event")
assertTrue(interactionService.contains("trackHistoryOpened"), "interaction service should track history event")
assertTrue(interactionService.contains("trackDetailOpened"), "interaction service should track detail event")
assertTrue(interactionService.contains("trackDisclosureToggle"), "interaction service should track disclosure event")
assertTrue(interactionService.contains("trackInquiryOpened"), "interaction service should track inquiry event")
assertTrue(interactionService.contains("\"summary_state\""), "interaction service should include summary_state payload")
assertTrue(interactionService.contains("\"top_exclusion_reasons\""), "interaction service should include exclusion reasons payload")
assertTrue(interactionService.contains("\"connection_state_key\""), "interaction service should include connection state payload")

assertTrue(mapCard.contains("map.walk.savedOutcome.openDetail"), "saved outcome card should expose open detail CTA")
assertTrue(mapView.contains("trackDetailOpened"), "map view should track immediate detail openings")
assertTrue(mapView.contains("trackHistoryOpened"), "map view should track saved outcome history openings")
assertTrue(mapView.contains("trackDismissed"), "map view should track saved outcome dismissals")
assertTrue(mapViewModel.contains("detailModel = WalkDataModel(polygon: savedPolygon)"), "map view model should build immediate detail model from the saved polygon")
assertTrue(mapView.contains("presentation.detailModel"), "map view should route immediate detail using the saved outcome presentation model")

assertTrue(detailSection.contains("walklist.detail.outcomeReport.inquiry"), "detail section should expose inquiry CTA")
assertTrue(detailSection.contains("onDisclosureToggle"), "detail section should forward disclosure callbacks")
assertTrue(detailView.contains("trackDisclosureToggle"), "detail view should track disclosure toggles")
assertTrue(detailView.contains("trackInquiryOpened"), "detail view should track inquiry openings")

assertTrue(featureTests.contains("testFeatureRegression_MapSavedOutcomeCardOpensImmediateDetailReport"), "feature regression tests should cover immediate detail opening")
assertTrue(featureTests.contains("walklist.detail.outcomeReport.inquiry"), "feature regression tests should assert inquiry CTA visibility")
assertTrue(featureRunner.contains("testFeatureRegression_MapSavedOutcomeCardOpensImmediateDetailReport"), "feature regression runner should execute immediate detail test")

assertTrue(doc.contains("#721"), "analytics instrumentation doc should mention issue #721")
assertTrue(doc.contains("walk_outcome_report_detail_opened"), "doc should define immediate detail event")
assertTrue(doc.contains("walk_outcome_report_inquiry_opened"), "doc should define inquiry event")
assertTrue(readme.contains("docs/walk-result-report-analytics-instrumentation-v1.md"), "README should index analytics instrumentation doc")
assertTrue(matrix.contains("FR-MAP-005C"), "UI regression matrix should include immediate detail route case")
assertTrue(matrix.contains("FR-WALK-003C"), "UI regression matrix should include inquiry CTA case")
assertTrue(prCheck.contains("swift scripts/walk_result_report_analytics_unit_check.swift"), "ios_pr_check should run analytics instrumentation check")
assertTrue(project.contains("WalkOutcomeReportInteractionService.swift"), "Xcode project should include interaction service file")

print("PASS: walk result report analytics checks")
