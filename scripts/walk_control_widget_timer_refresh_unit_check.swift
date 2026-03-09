import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Failed to load \(relativePath)\n", stderr)
        exit(1)
    }
    return text
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let doc = load("docs/walk-control-widget-timer-refresh-v1.md")
let widget = load("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let widgetRuntime = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("# Walk Control Widget Timer Refresh v1"), "doc title should exist")
assertTrue(doc.contains("Issue: #615"), "doc should reference issue #615")
assertTrue(doc.contains("active walk: next refresh after `60s`"), "doc should define active walk timeline cadence")
assertTrue(doc.contains("elapsed minute bucket"), "doc should define minute bucket reload rule")

assertTrue(widget.contains("enum WalkControlElapsedDisplayMode"), "widget should declare elapsed display mode")
assertTrue(widget.contains("struct WalkControlElapsedTextView"), "widget should render elapsed time through dedicated view")
assertTrue(widget.contains("Text(referenceDate, style: .timer)"), "widget should use timer-style elapsed rendering")
assertTrue(widget.contains("nextRefreshDate(for: snapshot, from: now)"), "widget provider should compute state-aware next refresh date")
assertTrue(widget.contains("return now.addingTimeInterval(60)"), "widget provider should refresh every minute while walking")

assertTrue(snapshotStore.contains("let startedAt: TimeInterval"), "snapshot should persist startedAt")
assertTrue(snapshotStore.contains("var timerReferenceDate: Date"), "snapshot should expose timer reference date")
assertTrue(snapshotStore.contains("var elapsedReloadMinuteBucket: Int"), "snapshot should derive elapsed minute bucket")
assertTrue(snapshotStore.contains("var updatedAtReloadMinuteBucket: Int"), "snapshot should derive updatedAt minute bucket")
assertTrue(snapshotStore.contains("String(Int(startedAt.rounded(.down)))"), "reload signature should include startedAt")

assertTrue(widgetRuntime.contains("resolveWalkWidgetStartedAt("), "widget runtime should resolve startedAt before saving")
assertTrue(readme.contains("docs/walk-control-widget-timer-refresh-v1.md"), "README should link the widget timer refresh doc")
assertTrue(iosPRCheck.contains("walk_control_widget_timer_refresh_unit_check.swift"), "ios_pr_check should run widget timer refresh check")

print("PASS: walk control widget timer refresh unit checks")
