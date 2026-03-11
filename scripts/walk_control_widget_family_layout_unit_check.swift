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
let widget = read("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let doc = read("docs/walk-control-widget-family-layout-v1.md")
let readme = read("README.md")
let prCheck = read("scripts/ios_pr_check.sh")

require(widget.contains("@Environment(\\.widgetFamily) private var family"), "WalkControlWidget should read widgetFamily from the environment.")
require(widget.contains("if family == .systemSmall"), "WalkControlWidget should explicitly branch small and medium families.")
require(widget.contains("private var layoutBudget: WidgetSurfaceLayoutBudget"), "WalkControlWidget should resolve a shared family budget.")
require(widget.contains("private var presentationMode: WalkControlPresentationMode"), "WalkControlWidget should derive a state-aware presentation mode.")
require(widget.contains("makeCompactPresentation()"), "WalkControlWidget should define compact state presentation copy.")
require(widget.contains("makeStandardPresentation()"), "WalkControlWidget should define standard state presentation copy.")
require(widget.contains("private var smallLayout"), "WalkControlWidget should provide a dedicated small layout.")
require(widget.contains("private var mediumLayout"), "WalkControlWidget should provide a dedicated medium layout.")
require(widget.contains("primaryActionButton(compact: true)"), "WalkControlWidget small layout should use compact CTA styling.")
require(widget.contains("primaryActionButton(compact: false)"), "WalkControlWidget medium layout should use standard CTA styling.")
require(widget.contains("compactActionBlockedTitle"), "WalkControlWidget should shorten the blocked inline-start CTA in small family.")
require(widget.contains("layoutBudget.elapsedText(entry.snapshot.elapsedSeconds)"), "WalkControlWidget should use shared elapsed formatting fallback.")
require(widget.contains("WidgetBadgeStripView("), "WalkControlWidget should render top badges through the shared badge strip.")
require(widget.contains("lineLimit(compact ? layoutBudget.ctaLineLimit : WidgetSurfaceLayoutBudget.standard.ctaLineLimit)"), "WalkControlWidget CTA line-limit policy should flow through the shared budget.")
require(widget.contains("WidgetSurfaceLayoutBudget.standard.ctaMinHeight"), "WalkControlWidget should pull CTA height from the shared budget.")
require(widget.contains("let presentation = makeCompactPresentation()"), "WalkControlWidget should build compact layout from compact presentation content.")
require(widget.contains("let presentation = makeStandardPresentation()"), "WalkControlWidget should build medium layout from standard presentation content.")
require(widget.contains("WidgetFormatting.formattedTime(timestamp: entry.snapshot.updatedAt)"), "WalkControlWidget medium layout should keep update time inline.")
require(widget.contains("#Preview(as: .systemMedium)"), "WalkControlWidget should include a medium preview.")

require(support.contains("static let compact = WidgetSurfaceLayoutBudget("), "shared support should define compact widget budget.")
require(support.contains("static let standard = WidgetSurfaceLayoutBudget("), "shared support should define standard widget budget.")
require(support.contains("WidgetBadgeStripView"), "shared support should provide badge strip view.")
require(support.contains("maxBadgeCount: 1"), "compact widget budget should restrict badge count to one.")

require(doc.contains("## Canonical layout split"), "doc should describe the family layout split.")
require(doc.contains("### systemSmall"), "doc should describe the small family policy.")
require(doc.contains("### systemMedium"), "doc should describe the medium family policy.")
require(doc.contains("CTA minimum height: `34`"), "doc should pin the small CTA height budget.")
require(doc.contains("CTA minimum height: `40`"), "doc should pin the medium CTA height budget.")
require(doc.contains("Family branching must be explicit through `widgetFamily`"), "doc should require explicit widgetFamily branching.")
require(doc.contains("Widget surface must use short family/state-specific copy"), "doc should require state-specific short copy to avoid ellipsis.")
require(doc.contains("Smallest supported real device is the acceptance baseline"), "doc should pin smallest-device acceptance.")

require(readme.contains("docs/walk-control-widget-family-layout-v1.md"), "README should link the widget family layout doc.")
require(prCheck.contains("walk_control_widget_family_layout_unit_check.swift"), "ios_pr_check should include the widget family layout check.")

print("PASS: walk control widget family layout unit checks")
