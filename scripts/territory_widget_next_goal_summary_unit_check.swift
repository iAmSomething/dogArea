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

let doc = load("docs/territory-widget-next-goal-summary-v1.md")
let readme = load("README.md")
let widget = load("dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let services = loadMany([
    "dogArea/Source/Domain/Home/Services/HomeAreaAggregationService.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift"
])
let iosPRCheck = load("scripts/ios_pr_check.sh")

/// 여러 파일을 읽어 하나의 문자열로 병합합니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

assertTrue(doc.contains("contextKey = userId|selectedPetId"), "doc should define territory widget context key policy")
assertTrue(doc.contains("다음 목표 / 남은 면적 / 진행률"), "doc should define next-goal summary scope")
assertTrue(doc.contains("goalContext"), "doc should describe goalContext payload")
assertTrue(doc.contains("selectedPet"), "doc should mention selected pet context preservation")

assertTrue(readme.contains("docs/territory-widget-next-goal-summary-v1.md"), "README should link territory widget next-goal summary doc")

assertTrue(snapshotStore.contains("struct TerritoryWidgetGoalContextSnapshot"), "snapshot store should define territory goal context snapshot")
assertTrue(snapshotStore.contains("let goalContext: TerritoryWidgetGoalContextSnapshot?"), "territory summary snapshot should persist goal context")
assertTrue(snapshotStore.contains("let contextKey: String"), "territory widget snapshot should persist context key")

assertTrue(services.contains("protocol TerritoryWidgetGoalContextServicing"), "home domain should define territory widget goal context protocol")
assertTrue(services.contains("struct TerritoryWidgetGoalContextService"), "home domain should define territory widget goal context service")
assertTrue(services.contains("resolveContextKey()"), "territory widget sync should resolve user/pet context key")
assertTrue(services.contains("goalContextService.makeGoalContext"), "territory widget sync should compute local goal context")
assertTrue(services.contains("current.contextKey == contextKey"), "failure path should guard cached territory snapshots by context key")

assertTrue(widget.contains("goalSummarySection"), "territory widget should render a next-goal summary section")
assertTrue(
    widget.contains("layoutBudget.areaText") || widget.contains("WidgetFormatting.formattedArea"),
    "territory widget should format remaining/goal area through shared budget or direct formatter"
)
assertTrue(widget.contains("WidgetFormatting.formattedPercent"), "territory widget should show goal progress percentage")
assertTrue(widget.contains("다음 목표"), "territory widget medium layout should expose next-goal copy")

assertTrue(iosPRCheck.contains("territory_widget_next_goal_summary_unit_check.swift"), "ios_pr_check should run territory widget next-goal summary check")

print("PASS: territory widget next-goal summary unit checks")
