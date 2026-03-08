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
let actionButtonView = load("dogAreaWatch Watch App/WatchActionButtonView.swift")
let queueCardView = load("dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let doc = load("docs/watch-main-scroll-overflow-ux-v1.md")

assertTrue(contentView.contains("ScrollView"), "watch content view should keep a scroll container")
assertTrue(contentView.contains("safeAreaInset(edge: .bottom"), "watch content view should pin the action dock with safeAreaInset")
assertTrue(contentView.contains("WatchMainStatusSummaryView"), "watch content view should render a dedicated status summary view")
assertTrue(contentView.contains("WatchPrimaryActionDockView"), "watch content view should render a dedicated action dock view")
assertTrue(contentView.contains("screen.watch.main.scroll"), "watch content view should expose a watch main scroll accessibility identifier")
assertTrue(statusSummaryView.contains("watch.main.statusSummary"), "status summary view should expose an accessibility identifier")
assertTrue(actionDockView.contains("watch.main.actionsDock"), "action dock view should expose an accessibility identifier")
assertTrue(actionButtonView.contains("frame(maxWidth: .infinity, minHeight: 52"), "watch action buttons should preserve a minimum tap target")
assertTrue(actionButtonView.contains(".lineLimit(2)"), "watch action button title should allow wrapping")
assertTrue(queueCardView.contains("ViewThatFits(in: .horizontal)"), "watch queue card should provide horizontal-to-vertical fallback layouts")
assertTrue(readme.contains("docs/watch-main-scroll-overflow-ux-v1.md"), "README should index the watch main overflow UX doc")
assertTrue(prCheck.contains("swift scripts/watch_main_scroll_overflow_unit_check.swift"), "ios_pr_check should include the watch main overflow unit check")
assertTrue(doc.contains("정보 스크롤 영역"), "watch main overflow doc should describe the scroll region")
assertTrue(doc.contains("하단 CTA 도크"), "watch main overflow doc should describe the fixed CTA dock")

print("PASS: watch main scroll overflow unit checks")
