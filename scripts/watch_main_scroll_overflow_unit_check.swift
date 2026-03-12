import Foundation

@inline(__always)
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

let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let actionDockView = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let actionButtonView = load("dogAreaWatch Watch App/WatchActionButtonView.swift")
let queueCardView = load("dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let doc = load("docs/watch-main-scroll-overflow-ux-v1.md")

assertTrue(contentView.contains("TabView(selection: $selectedSurface)"), "watch content view should split the main surface with a tab view")
assertTrue(contentView.components(separatedBy: "ScrollView").count >= 3, "watch content view should keep scroll containers for both control and information surfaces")
assertTrue(!contentView.contains("safeAreaInset(edge: .bottom"), "watch content view should no longer pin the action block as a bottom overlay inset")
assertTrue(contentView.contains("WatchControlSurfaceView"), "watch content view should render a single integrated control surface")
assertTrue(contentView.contains("screen.watch.main.pager"), "watch content view should expose a pager accessibility identifier")
assertTrue(contentView.contains("screen.watch.main.control"), "watch content view should expose a control surface accessibility identifier")
assertTrue(contentView.contains("screen.watch.main.info"), "watch content view should expose an information surface accessibility identifier")
assertTrue(statusSummaryView.contains("watch.main.statusSummary"), "status summary view should expose an accessibility identifier")
assertTrue(actionDockView.contains("watch.main.actionsDock"), "action dock view should expose an accessibility identifier")
assertTrue(controlSurfaceView.contains("watch.main.controlSurface"), "integrated control surface should expose an accessibility identifier")
assertTrue(!controlSurfaceView.contains("WatchActionBannerView"), "control surface should not keep the feedback banner in the overflow layout")
assertTrue(contentView.contains("WatchActionBannerView"), "information surface should expose the feedback banner in the overflow layout")
assertTrue(actionButtonView.contains("frame(maxWidth: .infinity, minHeight: 52"), "watch action buttons should preserve a minimum tap target")
assertTrue(actionButtonView.contains(".lineLimit(2)"), "watch action button title should allow wrapping")
assertTrue(queueCardView.contains("ViewThatFits(in: .horizontal)"), "watch queue card should provide horizontal-to-vertical fallback layouts")
assertTrue(readme.contains("docs/watch-main-scroll-overflow-ux-v1.md"), "README should index the watch main overflow UX doc")
assertTrue(prCheck.contains("swift scripts/watch_main_scroll_overflow_unit_check.swift"), "ios_pr_check should include the watch main overflow unit check")
assertTrue(doc.contains("control surface"), "watch main overflow doc should describe the control surface split")
assertTrue(doc.contains("information surface"), "watch main overflow doc should describe the information surface split")
assertTrue(doc.contains("WatchControlSurfaceView"), "watch main overflow doc should document the integrated control surface")
assertTrue(doc.contains("#698"), "watch main overflow doc should mention the watch IA follow-up issue")
assertTrue(doc.contains("#738"), "watch main overflow doc should mention the control-page minimization issue")

print("PASS: watch main scroll overflow unit checks")
