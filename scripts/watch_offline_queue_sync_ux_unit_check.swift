import Foundation

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = FileManager.default.currentDirectoryPath
let readme = read(root + "/README.md")
let doc = read(root + "/docs/watch-offline-queue-sync-ux-v1.md")
let contentView = read(root + "/dogAreaWatch Watch App/ContentView.swift")
let viewModel = read(root + "/dogAreaWatch Watch App/ContentsViewModel.swift")
let statusState = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusState.swift")
let cardView = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let sheetView = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusSheetView.swift")
let checkScript = read(root + "/scripts/ios_pr_check.sh")

assertTrue(readme.contains("watch-offline-queue-sync-ux-v1.md"), "README should index watch offline queue UX doc")
assertTrue(doc.contains("#522"), "doc should mention issue #522")
assertTrue(doc.contains("다시 동기화"), "doc should define manual resync policy")
assertTrue(doc.contains("90초"), "doc should define stale queue threshold")
assertTrue(doc.contains("action_id"), "doc should explain idempotency copy")
assertTrue(doc.contains("새 `syncState`를 queue에 추가하지 않음"), "doc should prevent offline syncState queue spam")

assertTrue(contentView.contains("WatchOfflineQueueStatusCardView"), "watch content should render queue status card")
assertTrue(contentView.contains("WatchOfflineQueueStatusSheetView"), "watch content should present queue status sheet")

assertTrue(viewModel.contains("@Published private(set) var queueStatus"), "view model should publish queue status snapshot")
assertTrue(viewModel.contains("@Published private(set) var lastAckAt"), "view model should persist last ack timestamp")
assertTrue(viewModel.contains("ackSnapshotStorageKey"), "view model should persist ack snapshot")
assertTrue(viewModel.contains("func handleManualQueueResync()"), "view model should expose manual queue resync action")
assertTrue(viewModel.contains("새 동기화 요청은 큐에 추가하지 않았습니다"), "offline syncState should not enqueue new queue work")
assertTrue(viewModel.contains("func refreshQueueStatus()"), "view model should recompute queue status snapshot")

assertTrue(statusState.contains("struct WatchOfflineQueueStatusState"), "watch target should define offline queue state model")
assertTrue(statusState.contains("lastQueuedAt"), "queue state should track latest queued time")
assertTrue(statusState.contains("oldestQueuedAt"), "queue state should track oldest queued time")
assertTrue(statusState.contains("var warningText"), "queue state should expose stale warning")

assertTrue(cardView.contains("큐 상태 보기"), "queue card should expose detail CTA")
assertTrue(cardView.contains("manualSyncButtonTitle"), "queue card should reuse manual sync title policy")
assertTrue(sheetView.contains("동기화 상태"), "queue sheet should explain sync status")
assertTrue(sheetView.contains("어긋남 징후"), "queue sheet should expose out-of-sync signals section")
assertTrue(sheetView.contains("회복 상태"), "queue sheet should expose recovery headline row")
assertTrue(sheetView.contains("중복 전송 안내"), "queue sheet should explain idempotency")
assertTrue(sheetView.contains("다음 행동"), "queue sheet should define next action guidance")

assertTrue(checkScript.contains("swift scripts/watch_offline_queue_sync_ux_unit_check.swift"), "ios_pr_check should run offline queue UX unit check")

print("PASS: watch offline queue sync UX unit checks")
