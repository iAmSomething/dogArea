import Foundation

@inline(__always)
/// 조건이 거짓이면 표준 에러에 실패 메시지를 출력하고 종료합니다.
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

/// 저장소 루트 기준 상대 경로의 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

/// 문자열 안의 특정 토큰 출현 횟수를 계산합니다.
/// - Parameters:
///   - token: 찾을 토큰 문자열입니다.
///   - text: 검색 대상 문자열입니다.
/// - Returns: 토큰이 등장한 횟수입니다.
func occurrences(of token: String, in text: String) -> Int {
    text.components(separatedBy: token).count - 1
}

let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let seasonPolicy = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+SeasonTileVisualPolicy.swift")
let doc = load("docs/map-season-tile-occupation-visualization-v1.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(mapSubView.contains("storedWalkPolygonFillLayer("), "MapSubView should render stored polygon fill through a dedicated helper")
assertTrue(mapSubView.contains("storedWalkPolygonStrokeLayer("), "MapSubView should render stored polygon stroke through a dedicated helper")
assertTrue(occurrences(of: ".foregroundStyle(Color.clear)", in: mapSubView) >= 3, "MapSubView should explicitly clear fill on stored stroke, season stroke, and selection halo overlays")
assertTrue(seasonPolicy.contains("storedWalkPolygonFillColor"), "season policy should own stored polygon fill suppression")
assertTrue(seasonPolicy.contains("storedWalkPolygonStrokeColor"), "season policy should own stored polygon stroke styling")
assertTrue(doc.contains("저장 polygon stroke"), "visualization doc should keep stored polygon as outline-only while season map is visible")
assertTrue(iosCheck.contains("swift scripts/map_season_overlay_fill_competition_unit_check.swift"), "ios_pr_check should include the season overlay fill competition regression check")

print("PASS: map season overlay fill competition checks")
