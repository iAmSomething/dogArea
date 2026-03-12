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

let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let actionDockView = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let queueCardView = load("dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let pagingHintView = load("dogAreaWatch Watch App/WatchSurfacePagingHintView.swift")
let doc = load("docs/watch-main-scroll-overflow-ux-v1.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(contentView.contains("TabView(selection: $selectedSurface)"), "watch content should split the main IA into explicit surfaces")
assertTrue(contentView.contains("screen.watch.main.control"), "watch content should expose a control surface identifier")
assertTrue(contentView.contains("screen.watch.main.info"), "watch content should expose an information surface identifier")
assertTrue(contentView.contains("syncLandingSurface"), "watch content should actively keep walking sessions on the control surface")
assertTrue(contentView.contains("hasVisitedInfoSurface"), "watch content should track whether users discovered the information surface")
assertTrue(contentView.contains("WatchSurfacePagingHintView"), "watch content should provide a lightweight paging affordance")
assertTrue(contentView.contains("shouldShowPagingHint"), "watch content should gate the paging affordance after first discovery")
assertTrue(statusSummaryView.contains("지금 산책 중입니다"), "control surface status summary should describe the active control page state")
assertTrue(actionDockView.contains("지금 할 수 있는 조작"), "action block should explicitly explain the control surface purpose")
assertTrue(controlSurfaceView.contains("WatchMainStatusSummaryView"), "control surface should embed the status summary section")
assertTrue(controlSurfaceView.contains("WatchPrimaryActionDockView"), "control surface should embed the action section")
assertTrue(!controlSurfaceView.contains("WatchActionBannerView"), "control surface should not own the feedback banner hierarchy any more")
assertTrue(contentView.contains("WatchActionBannerView"), "information surface should render the feedback banner")
assertTrue(contentView.contains("style: .card"), "information surface should render feedback as a card-style secondary surface")
assertTrue(pagingHintView.contains("watch.main.surfaceHint"), "paging hint view should expose an accessibility identifier")
assertTrue(queueCardView.contains("큐 상태 보기"), "information surface should still expose the queue detail route")
assertTrue(doc.contains("#698"), "watch IA doc should mention issue #698")
assertTrue(doc.contains("#738"), "watch IA doc should mention issue #738")
assertTrue(doc.contains("#724"), "watch IA doc should mention issue #724")
assertTrue(doc.contains("control surface"), "watch IA doc should define the control surface")
assertTrue(doc.contains("information surface"), "watch IA doc should define the information surface")
assertTrue(prCheck.contains("swift scripts/watch_control_info_surface_split_unit_check.swift"), "ios_pr_check should include the watch control/info split check")

print("PASS: watch control/info surface split checks")
