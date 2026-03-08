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

let evidence = load("docs/issue-522-closure-evidence-v1.md")
let uxDoc = load("docs/watch-offline-queue-sync-ux-v1.md")
let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let viewModel = load("dogAreaWatch Watch App/ContentsViewModel.swift")
let state = load("dogAreaWatch Watch App/WatchOfflineQueueStatusState.swift")
let cardView = load("dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let sheetView = load("dogAreaWatch Watch App/WatchOfflineQueueStatusSheetView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#522"), "evidence doc should reference issue #522")
assertTrue(evidence.contains("PR: `#550`") || evidence.contains("PR `#550`"), "evidence doc should reference implementation PR #550")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("watchOS Simulator"), "evidence doc should record watch build verification")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(uxDoc.contains("다시 동기화"), "offline queue UX doc should preserve manual resync policy")
assertTrue(contentView.contains("WatchOfflineQueueStatusCardView"), "watch content should render queue status card")
assertTrue(contentView.contains("WatchOfflineQueueStatusSheetView"), "watch content should present queue status sheet")
assertTrue(viewModel.contains("handleManualQueueResync"), "view model should expose manual queue resync handling")
assertTrue(state.contains("let lastQueuedAt: TimeInterval?"), "queue state should retain the last queued timestamp")
assertTrue(state.contains("let lastAckStatus: String"), "queue state should retain the last acknowledgement result")
assertTrue(cardView.contains("queueStatus.manualSyncButtonTitle"), "queue status card should surface the next action button")
assertTrue(sheetView.contains("formattedTimestamp(queueStatus.lastQueuedAt)"), "queue detail sheet should surface the last queued timestamp")
assertTrue(readme.contains("docs/issue-522-closure-evidence-v1.md"), "README should index the issue #522 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_522_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #522 closure evidence check")

print("PASS: issue #522 closure evidence unit checks")
