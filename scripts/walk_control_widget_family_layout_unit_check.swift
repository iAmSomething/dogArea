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

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let widget = read("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let doc = read("docs/walk-control-widget-family-layout-v1.md")
let readme = read("README.md")
let prCheck = read("scripts/ios_pr_check.sh")

require(widget.contains("@Environment(\\.widgetFamily) private var family"), "WalkControlWidget should read widgetFamily from the environment.")
require(widget.contains("if family == .systemSmall"), "WalkControlWidget should explicitly branch small and medium families.")
require(widget.contains("private var smallLayout"), "WalkControlWidget should provide a dedicated small layout.")
require(widget.contains("private var mediumLayout"), "WalkControlWidget should provide a dedicated medium layout.")
require(widget.contains("primaryActionButton(compact: true)"), "WalkControlWidget small layout should use compact CTA styling.")
require(widget.contains("primaryActionButton(compact: false)"), "WalkControlWidget medium layout should use standard CTA styling.")
require(widget.contains("compactActionBlockedTitle"), "WalkControlWidget should shorten the blocked inline-start CTA in small family.")
require(widget.contains("lineLimit(compact ? 1 : 2)"), "WalkControlWidget CTA lineLimit policy should split by family.")
require(widget.contains("minHeight: compact ? 34 : 40"), "WalkControlWidget CTA min-height policy should split by family.")
require(widget.contains("compactSupportText"), "WalkControlWidget should collapse support text for small family.")
require(widget.contains("WidgetFormatting.formattedTime(timestamp: entry.snapshot.updatedAt)"), "WalkControlWidget medium layout should keep update time inline.")
require(widget.contains("#Preview(as: .systemMedium)"), "WalkControlWidget should include a medium preview.")

require(doc.contains("## Canonical layout split"), "doc should describe the family layout split.")
require(doc.contains("### systemSmall"), "doc should describe the small family policy.")
require(doc.contains("### systemMedium"), "doc should describe the medium family policy.")
require(doc.contains("CTA minimum height: `34`"), "doc should pin the small CTA height budget.")
require(doc.contains("CTA minimum height: `40`"), "doc should pin the medium CTA height budget.")
require(doc.contains("Family branching must be explicit through `widgetFamily`"), "doc should require explicit widgetFamily branching.")

require(readme.contains("docs/walk-control-widget-family-layout-v1.md"), "README should link the widget family layout doc.")
require(prCheck.contains("walk_control_widget_family_layout_unit_check.swift"), "ios_pr_check should include the widget family layout check.")

print("PASS: walk control widget family layout unit checks")
