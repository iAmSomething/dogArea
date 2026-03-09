import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 조건이 거짓일 때 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let widget = load("dogAreaWidgetExtension/Widgets/WalkLiveActivityWidget.swift")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let doc = load("docs/walk-live-activity-copy-timer-v1.md")

assertTrue(doc.contains("# Walk Live Activity Copy And Timer v1"), "doc should declare title")
assertTrue(doc.contains("Issue: #616"), "doc should reference issue #616")
assertTrue(doc.contains("autoEndStage"), "doc should define stage-first rule")
assertTrue(doc.contains("self-updating timer"), "doc should define timer contract")
assertTrue(doc.contains("산책이 종료되었어요"), "doc should pin ended headline")

assertTrue(widget.contains("enum WalkLiveActivityElapsedDisplayMode"), "widget should declare elapsed display mode")
assertTrue(widget.contains("struct WalkLiveActivityElapsedTextView"), "widget should render elapsed time through dedicated view")
assertTrue(widget.contains("Text(referenceDate, style: .timer)"), "widget should use timer-style elapsed rendering")
assertTrue(widget.contains("case .ended:"), "widget should branch ended stage explicitly")
assertTrue(widget.contains("산책이 종료되었어요"), "widget should use ended headline copy")
assertTrue(widget.contains("autoEndStage == .ended"), "widget should freeze elapsed time when ended")
assertTrue(widget.contains("progressPresentation("), "widget should resolve summary copy through stage-aware helper")
assertTrue(widget.contains("Text(presentation.progressDetail)"), "widget surfaces should reuse unified detail copy")
assertTrue(widget.contains("return \"확인\""), "auto-ending compact trailing text should prompt confirmation")

assertTrue(readme.contains("docs/walk-live-activity-copy-timer-v1.md"), "README should link the Live Activity copy/timer doc")
assertTrue(iosPRCheck.contains("walk_live_activity_copy_timer_unit_check.swift"), "ios_pr_check should run Live Activity copy/timer unit check")

print("PASS: walk live activity copy/timer unit checks")
