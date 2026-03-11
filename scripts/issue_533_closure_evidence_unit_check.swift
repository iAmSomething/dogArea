import Foundation

/// 조건이 참인지 검증합니다.
/// - Parameters:
///   - condition: 평가할 조건식입니다.
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

let evidence = load("docs/issue-533-closure-evidence-v1.md")
let uxDoc = load("docs/watch-main-scroll-overflow-ux-v1.md")
let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let actionDockView = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#533"), "evidence doc should reference issue #533")
assertTrue(evidence.contains("PR: `#558`") || evidence.contains("PR `#558`"), "evidence doc should reference implementation PR #558")
assertTrue(evidence.contains("control surface / information surface"), "evidence doc should record the control/info split follow-up")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("WatchControlSurfaceView"), "evidence doc should explain the integrated control surface")
assertTrue(evidence.contains("watchOS Simulator"), "evidence doc should record watch build verification")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(uxDoc.contains("control surface"), "overflow UX doc should preserve the split control surface decision")
assertTrue(uxDoc.contains("information surface"), "overflow UX doc should preserve the split information surface decision")
assertTrue(contentView.contains("TabView(selection: $selectedSurface)"), "watch content view should use a tab view to split main surfaces")
assertTrue(contentView.components(separatedBy: "ScrollView").count >= 3, "watch content view should keep scroll views for both main surfaces")
assertTrue(!contentView.contains(".safeAreaInset(edge: .bottom"), "watch content view should no longer pin the action dock as a bottom overlay")
assertTrue(contentView.contains("WatchControlSurfaceView"), "watch content should render the integrated control surface view")
assertTrue(controlSurfaceView.contains("WatchMainStatusSummaryView"), "control surface should render the status summary view")
assertTrue(controlSurfaceView.contains("WatchPrimaryActionDockView"), "control surface should render the action block view")
assertTrue(statusSummaryView.contains("watch.main.statusSummary"), "status summary should expose a stable accessibility identifier")
assertTrue(actionDockView.contains("watch.main.actionsDock"), "action dock should expose a stable accessibility identifier")
assertTrue(readme.contains("docs/issue-533-closure-evidence-v1.md"), "README should index the issue #533 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_533_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #533 closure evidence check")

print("PASS: issue #533 closure evidence unit checks")
