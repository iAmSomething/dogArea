import Foundation

@inline(__always)
/// 조건이 거짓이면 표준 에러에 메시지를 출력하고 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
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

let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let seasonPolicy = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+SeasonTileVisualPolicy.swift")
let visualizationDoc = load("docs/map-season-tile-occupation-visualization-v1.md")
let closureDoc = load("docs/issue-690-closure-evidence-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(seasonPolicy.contains("enum MapSeasonTileRenderScenario"), "season tile visual policy should define explicit render scenarios")
assertTrue(seasonPolicy.contains("seasonWithStoredPolygonSurface"), "season tile visual policy should include the stored polygon scenario")
assertTrue(seasonPolicy.contains("seasonWithActiveWalkRoute"), "season tile visual policy should include the active route scenario")
assertTrue(seasonPolicy.contains("func seasonTileRenderScenario("), "season tile visual policy should classify the current render scenario")
assertTrue(seasonPolicy.contains("func seasonTileFillOpacity("), "season tile visual policy should expose scenario-aware fill opacity")
assertTrue(seasonPolicy.contains("func storedWalkPolygonFillOpacity("), "season tile visual policy should tune stored polygon opacity alongside season layers")
assertTrue(seasonPolicy.contains("func storedWalkPolygonFillColor("), "season tile visual policy should decide when stored polygon fill is suppressed")
assertTrue(seasonPolicy.contains("guard isSeasonTileMapVisible == false else { return nil }"), "stored polygon fill should be removed while season map is visible")
assertTrue(seasonPolicy.contains("func storedWalkPolygonStrokeColor("), "season tile visual policy should derive a dedicated stored polygon outline color")
assertTrue(mapSubView.contains("let seasonTileRenderScenario = viewModel.seasonTileRenderScenario("), "MapSubView should derive an explicit season tile render scenario")
assertTrue(mapSubView.contains("// 1. 시즌 점령 fill은 항상 가장 아래의 보조 레이어로 둡니다."), "MapSubView should document the first render layer")
assertTrue(mapSubView.contains("// 6. 현재 산책 route는 season stroke보다 위에 둬 주 레이어를 명확히 합니다."), "MapSubView should document route-above-stroke priority")
assertTrue(mapSubView.contains("storedWalkPolygonFillLayer("), "MapSubView should separate stored polygon fill rendering from stroke rendering")
assertTrue(mapSubView.contains("storedWalkPolygonStrokeLayer("), "MapSubView should render stored polygon outline in its own pass")
assertTrue(mapSubView.contains(".foregroundStyle(Color.clear)"), "stroke-only overlay layers should explicitly clear fill")
assertTrue(visualizationDoc.contains("stroke가 주 신호"), "season occupation doc should state the stroke-first rule")
assertTrue(visualizationDoc.contains("seasonOnly / seasonWithStoredPolygonSurface / seasonWithActiveWalkRoute"), "season occupation doc should document all three render scenarios")
assertTrue(visualizationDoc.contains("저장 polygon fill을 끄고"), "season occupation doc should record stored polygon fill suppression while season map is visible")
assertTrue(closureDoc.contains("stroke-first"), "issue #690 closure evidence should record the stroke-first decision")
assertTrue(readme.contains("docs/issue-690-closure-evidence-v1.md"), "README should index the issue #690 closure evidence doc")
assertTrue(iosCheck.contains("swift scripts/map_season_render_priority_stroke_first_unit_check.swift"), "ios_pr_check should include the stroke-first render priority check")

print("PASS: map season stroke-first render priority checks")
