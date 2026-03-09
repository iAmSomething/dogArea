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

let evidence = load("docs/issue-503-closure-evidence-v1.md")
let designDoc = load("docs/map-heatmap-trigger-gating-v1.md")
let model = load("dogArea/Source/Domain/Map/Models/MapHeatmapSnapshot.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapHeatmapAggregationService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#503"), "evidence doc should reference issue #503")
assertTrue(evidence.contains("PR: `#562`") || evidence.contains("PR `#562`"), "evidence doc should reference implementation PR #562")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(designDoc.contains("전체 집계 `0회`"), "design doc should record hidden-state aggregation savings")
assertTrue(designDoc.contains("15분 bucket"), "design doc should record snapshot reuse bucket policy")
assertTrue(model.contains("struct MapHeatmapDatasetFingerprint"), "heatmap fingerprint model should exist")
assertTrue(model.contains("struct MapHeatmapAggregationSnapshot"), "heatmap snapshot model should exist")
assertTrue(service.contains("protocol MapHeatmapAggregationServicing"), "heatmap service protocol should exist")
assertTrue(service.contains("Task.detached(priority: .utility)"), "heatmap aggregation should run off the main thread")
assertTrue(service.contains("func canReuseSnapshot"), "heatmap service should expose reuse gating")
assertTrue(mapViewModel.contains("var isHeatmapVisibleInMapUI: Bool"), "MapViewModel should expose a single heatmap visibility rule")
assertTrue(mapViewModel.contains("clearHeatmapPresentation(preserveSnapshot: true)"), "MapViewModel should preserve snapshot when heatmap is hidden")
assertTrue(mapViewModel.contains("latestHeatmapRefreshRequestID"), "MapViewModel should track the latest heatmap request")
assertTrue(mapSubView.contains("isSeasonTileMapVisible") || mapSubView.contains("isHeatmapVisibleInMapUI"), "MapSubView should reuse shared heatmap visibility state")
assertTrue(mapView.contains("isHeatmapVisibleInMapUI") || mapView.contains("isSeasonTileMapVisible"), "MapView should reuse shared heatmap visibility state")
assertTrue(readme.contains("docs/issue-503-closure-evidence-v1.md"), "README should index the issue #503 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_503_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #503 closure evidence check")

print("PASS: issue #503 closure evidence unit checks")
