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
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let actionDockView = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let bannerView = load("dogAreaWatch Watch App/WatchActionBannerView.swift")
let densityDoc = load("docs/watch-control-surface-density-v1.md")
let closureDoc = load("docs/issue-698-closure-evidence-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(contentView.contains("watch.main.info.header"), "information surface should expose an explicit heading to separate purpose from the control page")
assertTrue(controlSurfaceView.contains("watch.main.controlSurface.header"), "control surface should expose a dedicated page header")
assertTrue(controlSurfaceView.contains("watch.main.controlSurface.actions"), "control surface should expose a dedicated action section identifier")
assertTrue(statusSummaryView.contains("watch.main.statusSummary.metrics"), "status summary should expose a single metrics strip identifier")
assertTrue(statusSummaryView.contains("metricColumn("), "status summary should render metrics as strip columns")
assertTrue(!statusSummaryView.contains("metricTile("), "status summary should not keep legacy mini tile cards")
assertTrue(actionDockView.contains("sectionDetail"), "action section should explain the current control purpose with concise copy")
assertTrue(!actionDockView.contains("불필요한 정보 없이 시작 버튼을 먼저 보여줍니다."), "legacy explanatory filler copy should be removed from the action section")
assertTrue(bannerView.contains(".stroke("), "inline feedback banner should read as a light strip rather than a solid card")
assertTrue(densityDoc.contains("single metrics strip"), "density doc should lock the single metrics strip rule")
assertTrue(closureDoc.contains("overlay처럼 떠 있다"), "issue #698 closure evidence should record the reopen rationale")
assertTrue(readme.contains("docs/issue-698-closure-evidence-v1.md"), "README should index the issue #698 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/watch_control_surface_rehardening_unit_check.swift"), "ios_pr_check should include the watch control surface rehardening check")

print("PASS: watch control surface rehardening unit checks")
