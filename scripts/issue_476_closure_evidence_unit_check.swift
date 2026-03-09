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

let evidence = load("docs/issue-476-closure-evidence-v1.md")
let designDoc = load("docs/map-walking-invalidation-reduction-v1.md")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let renderBudget = load("dogArea/Views/MapView/MapSubViews/MapRenderBudgetProbeOverlayView.swift")
let uiTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#476"), "evidence doc should reference issue #476")
assertTrue(evidence.contains("PR: `#560`") || evidence.contains("PR `#560`"), "evidence doc should reference implementation PR #560")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(designDoc.contains("250ms 루트 ticker 제거"), "design doc should record root ticker removal")
assertTrue(designDoc.contains("3초 동안 count <= 6"), "design doc should record the render budget threshold")
assertTrue(!mapSubView.contains("motionTicker"), "MapSubView should not keep a root motion ticker")
assertTrue(!mapSubView.contains("motionNow"), "MapSubView should not keep root motion state")
assertTrue(mapSubView.contains("MapTrailMarkerAnnotationView"), "MapSubView should isolate trail marker animation")
assertTrue(mapView.contains("MapRenderBudgetProbeOverlayView()"), "MapView should host the render budget overlay")
assertTrue(renderBudget.contains("struct MapRenderBudgetProbeOverlayView"), "render budget overlay type should exist")
assertTrue(startButton.contains("MapWalkingElapsedTimeValueText"), "elapsed time display should be localized to StartButtonView")
assertTrue(mapViewModel.contains("publishMapLocationIfNeeded"), "MapViewModel should gate location publishes")
assertTrue(mapViewModel.contains("shouldPublishMapLocation"), "MapViewModel should decide whether location changes are meaningful")
assertTrue(uiTests.contains("testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold"), "UI regression should cover the root render budget")
assertTrue(readme.contains("docs/issue-476-closure-evidence-v1.md"), "README should index the issue #476 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_476_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #476 closure evidence check")

print("PASS: issue #476 closure evidence unit checks")
