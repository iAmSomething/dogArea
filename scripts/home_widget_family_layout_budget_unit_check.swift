import Foundation

@discardableResult
func require(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let support = read("dogAreaWidgetExtension/Shared/WidgetPresentationSupport.swift")
let walk = read("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let territory = read("dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift")
let hotspot = read("dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift")
let quest = read("dogAreaWidgetExtension/Widgets/QuestRivalStatusWidget.swift")
let doc = read("docs/home-widget-family-layout-budget-v1.md")
let readme = read("README.md")
let prCheck = read("scripts/ios_pr_check.sh")

require(support.contains("struct WidgetSurfaceLayoutBudget"), "공통 family layout budget 타입이 없습니다.")
require(support.contains("static let compact = WidgetSurfaceLayoutBudget("), "compact family 예산이 없습니다.")
require(support.contains("static let standard = WidgetSurfaceLayoutBudget("), "standard family 예산이 없습니다.")
require(support.contains("maxBadgeCount"), "badge 최대 개수 예산이 없습니다.")
require(support.contains("ctaMinHeight"), "CTA 최소 높이 예산이 없습니다.")
require(support.contains("ctaMaxHeight"), "CTA 최대 높이 예산이 없습니다.")
require(support.contains("metricTileMinHeight"), "metric tile 최소 높이 예산이 없습니다.")
require(support.contains("func elapsedText(_ elapsedSeconds: Int) -> String"), "경과 시간 compact fallback helper가 없습니다.")
require(support.contains("func areaText(_ areaM2: Double) -> String"), "면적 compact fallback helper가 없습니다.")
require(support.contains("struct WidgetBadgeStripView"), "badge strip 공통 뷰가 없습니다.")
require(support.contains("struct WidgetMetricTileView"), "metric tile 공통 뷰가 없습니다.")

for widget in [walk, territory, hotspot, quest] {
    require(widget.contains("private var layoutBudget: WidgetSurfaceLayoutBudget"), "각 홈 위젯은 layout budget을 가져야 합니다.")
}

require(walk.contains("layoutBudget.elapsedText(entry.snapshot.elapsedSeconds)"), "WalkControlWidget은 compact/full 시간 fallback을 budget으로 결정해야 합니다.")
require(walk.contains("WidgetBadgeStripView("), "WalkControlWidget은 badge strip 공통 뷰를 사용해야 합니다.")
require(territory.contains("WidgetMetricTileView("), "TerritoryStatusWidget은 metric tile 공통 뷰를 사용해야 합니다.")
require(territory.contains("WidgetStateCTAView(cta: guide.cta, budget: layoutBudget"), "TerritoryStatusWidget은 CTA budget을 사용해야 합니다.")
require(hotspot.contains("badgeStrip(primaryTitle:"), "HotspotStatusWidget은 상태/preset 배지를 공통 strip으로 구성해야 합니다.")
require(hotspot.contains("lineLimit(layoutBudget.detailLineLimit)"), "HotspotStatusWidget은 detail line budget을 사용해야 합니다.")
require(quest.contains("actionButtonLabel(title:"), "QuestRivalStatusWidget은 CTA 라벨을 공통 budget으로 렌더링해야 합니다.")
require(quest.contains("lineLimit(layoutBudget.detailLineLimit)"), "QuestRivalStatusWidget은 detail line budget을 사용해야 합니다.")

for heading in [
    "# Home Widget Family Layout Budget v1",
    "## Shared family budget",
    "### systemSmall",
    "### systemMedium",
    "## Surface-specific policy",
    "## State matrix to audit",
    "## Zero-base clipping rule",
    "## Evidence rule"
] {
    require(doc.contains(heading), "문서에 \(heading) 섹션이 없습니다.")
}

require(doc.contains("Issue: #692"), "문서는 이슈 #692를 참조해야 합니다.")
require(doc.contains("badge: 최대 `2개`"), "문서는 badge budget을 명시해야 합니다.")
require(doc.contains("CTA: `minHeight 34`"), "문서는 small CTA 높이를 명시해야 합니다.")
require(doc.contains("CTA: `minHeight 40`"), "문서는 medium CTA 높이를 명시해야 합니다.")
require(doc.contains("4 widgets x 2 families x representative states"), "문서는 실기기 증적 축을 명시해야 합니다.")

require(readme.contains("docs/home-widget-family-layout-budget-v1.md"), "README에 홈 위젯 family budget 문서 링크가 없습니다.")
require(prCheck.contains("home_widget_family_layout_budget_unit_check.swift"), "ios_pr_check에 홈 위젯 family budget 체크가 없습니다.")

print("PASS: home widget family layout budget unit checks")
