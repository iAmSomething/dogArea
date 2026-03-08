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
let doc = read(root + "/docs/watch-sync-recovery-ux-v1.md")
let project = read(root + "/dogArea.xcodeproj/project.pbxproj")
let viewModel = read(root + "/dogAreaWatch Watch App/ContentsViewModel.swift")
let statusState = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusState.swift")
let cardView = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let sheetView = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusSheetView.swift")
let recoveryModel = read(root + "/dogAreaWatch Watch App/WatchSyncRecoveryPresentation.swift")
let checkScript = read(root + "/scripts/ios_pr_check.sh")

assertTrue(readme.contains("watch-sync-recovery-ux-v1.md"), "README should index watch sync recovery doc")
assertTrue(doc.contains("Issue: #524"), "doc should mention issue #524")
assertTrue(doc.contains("마지막 동기화 오래됨"), "doc should define stale sync signal")
assertTrue(doc.contains("ACK 아직 없음"), "doc should define missing ACK signal")
assertTrue(doc.contains("큐 장기 적재"), "doc should define stale queue signal")
assertTrue(doc.contains("iPhone 연결 끊김"), "doc should define unreachable signal")
assertTrue(doc.contains("15초"), "doc should define manual sync cooldown")
assertTrue(doc.contains("8초"), "doc should define grace window")
assertTrue(doc.contains("WCSession"), "doc should confirm transport contract is preserved")

assertTrue(recoveryModel.contains("enum WatchManualSyncRecoveryPhase"), "watch target should define manual sync recovery phase")
assertTrue(recoveryModel.contains("struct WatchSyncRecoveryState"), "watch target should define sync recovery state")
assertTrue(recoveryModel.contains("protocol WatchSyncRecoveryPresenting"), "watch target should define sync recovery presentation protocol")
assertTrue(recoveryModel.contains("수동 확인 진행 중"), "recovery model should expose processing signal copy")
assertTrue(recoveryModel.contains("응답 대기 중"), "recovery model should expose waiting signal copy")
assertTrue(recoveryModel.contains("동기화 확인됨"), "recovery model should expose recovered signal copy")
assertTrue(recoveryModel.contains("잠시 후 다시"), "recovery model should expose cooldown CTA copy")

assertTrue(viewModel.contains("manualSyncCooldownInterval: TimeInterval = 15"), "view model should define manual sync cooldown interval")
assertTrue(viewModel.contains("manualSyncResponseGraceInterval: TimeInterval = 8"), "view model should define manual sync grace interval")
assertTrue(viewModel.contains("manualSyncRecoveryPhase = .processing"), "manual sync should enter processing phase")
assertTrue(viewModel.contains("manualSyncRecoveryPhase = .waiting"), "manual sync should enter waiting phase")
assertTrue(viewModel.contains("manualSyncRecoveryPhase = .recovered"), "manual sync should enter recovered phase")
assertTrue(viewModel.contains("scheduleManualSyncResponseTimeout"), "view model should schedule response timeout")
assertTrue(viewModel.contains("scheduleManualSyncCooldownRefresh"), "view model should schedule cooldown refresh")
assertTrue(viewModel.contains("completeManualSyncRecoveryIfNeeded"), "view model should complete recovery on fresh sync")

assertTrue(statusState.contains("let syncRecovery: WatchSyncRecoveryState"), "queue state should embed sync recovery snapshot")
assertTrue(statusState.contains("manualSyncButtonTone"), "queue state should expose recovery button tone")
assertTrue(statusState.contains("syncRecoveryService: WatchSyncRecoveryPresenting"), "queue state factory should depend on recovery presenter")

assertTrue(cardView.contains("syncRecovery.signals"), "queue card should render sync recovery signals")
assertTrue(sheetView.contains("어긋남 징후"), "queue sheet should expose sync signal section")
assertTrue(sheetView.contains("회복 상태"), "queue sheet should expose recovery status row")
assertTrue(sheetView.contains("syncRecovery.cooldownRemainingText"), "queue sheet should render cooldown guidance")

assertTrue(project.contains("WatchSyncRecoveryPresentation.swift"), "xcode project should include watch sync recovery file")
assertTrue(checkScript.contains("swift scripts/watch_sync_recovery_ux_unit_check.swift"), "ios_pr_check should run sync recovery unit check")

print("PASS: watch sync recovery UX unit checks")
