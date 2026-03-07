import Foundation

/// 조건식을 검증하고 실패 시 stderr에 메시지를 출력한 뒤 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 파일 본문을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8로 디코딩한 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let readme = load("README.md")
let doc = load("docs/walk-live-activity-priority-v1.md")
let widget = load("dogAreaWidgetExtension/Widgets/WalkLiveActivityWidget.swift")
let formatting = load("dogAreaWidgetExtension/Shared/WidgetPresentationSupport.swift")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let mapSupport = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(readme.contains("docs/walk-live-activity-priority-v1.md"), "README should link live activity priority doc")

assertTrue(doc.contains("expanded"), "doc should define expanded surface priority")
assertTrue(doc.contains("compact"), "doc should define compact surface priority")
assertTrue(doc.contains("minimal"), "doc should define minimal surface priority")
assertTrue(doc.contains("capturedAreaM2"), "doc should define captured area contract")
assertTrue(doc.contains("Low Power / Reduce Motion"), "doc should describe low power / reduce motion policy")

assertTrue(formatting.contains("formattedElapsedCompact"), "widget formatting should expose compact elapsed formatter")
assertTrue(formatting.contains("formattedCompactArea"), "widget formatting should expose compact area formatter")

assertTrue(snapshotStore.contains("let capturedAreaM2: Double"), "live activity state should persist captured area")
assertTrue(snapshotStore.contains("capturedAreaM2: capturedAreaM2"), "content state should encode captured area")
assertTrue(mapSupport.contains("capturedAreaM2: walkHybridContributionSummary.finalAreaM2"), "map widget runtime support should pass captured area into live activity state")

assertTrue(widget.contains("WalkLiveActivityPresentationGuide"), "widget should use a dedicated presentation guide")
assertTrue(widget.contains("WalkLiveActivityMetricTileView"), "widget should define metric tile view")
assertTrue(widget.contains("DynamicIslandExpandedRegion(.bottom)"), "dynamic island expanded layout should use bottom safety region")
assertTrue(widget.contains("현재 확보"), "expanded live activity should surface captured area")
assertTrue(widget.contains("compactTrailingText"), "compact live activity should compute prioritized trailing text")
assertTrue(widget.contains("minimalSymbolName"), "minimal live activity should use prioritized state symbol")

assertTrue(iosPRCheck.contains("walk_live_activity_priority_unit_check.swift"), "ios_pr_check should run live activity priority unit check")

print("PASS: walk live activity priority unit checks")
