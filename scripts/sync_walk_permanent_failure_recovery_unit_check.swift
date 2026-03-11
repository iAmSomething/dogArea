import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 파일을 문자열로 읽습니다.
/// - Parameter path: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to load \(path)\n", stderr)
        exit(1)
    }
    return contents
}

/// 조건식이 거짓이면 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let outboxStore = load("dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift")
let recoveryDomain = load("dogArea/Source/Domain/Recovery/RecoveryIssue.swift")
let recoveryBanner = load("dogArea/Views/GlobalViews/Recovery/RecoveryActionBanner.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapRecoverySupport = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+SyncOutboxRecoverySupport.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let featureUITests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let doc = load("docs/sync-walk-permanent-failure-recovery-ux-v1.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(outboxStore.contains("struct SyncOutboxPermanentFailureSessionSnapshot"), "sync outbox store should expose permanent failure session snapshots")
assertTrue(outboxStore.contains("func permanentFailureSessions() -> [SyncOutboxPermanentFailureSessionSnapshot]"), "sync outbox store should group permanent failure sessions")
assertTrue(outboxStore.contains("func replaceStagesForSessions(_ sessionDTOs: [WalkSessionBackfillDTO]) -> Int"), "sync outbox store should support rebuilding failed sessions")
assertTrue(outboxStore.contains("func archivePermanentFailures(walkSessionIds: Set<String>) -> Int"), "sync outbox store should support archive-only cleanup")

assertTrue(recoveryDomain.contains("enum SyncOutboxPermanentFailureDisposition"), "recovery domain should classify permanent failure dispositions")
assertTrue(recoveryDomain.contains("struct SyncOutboxPermanentFailureOverview"), "recovery domain should expose recovery overview model")
assertTrue(recoveryDomain.contains("SyncOutboxPermanentFailurePresentationService"), "recovery domain should include presentation service")
assertTrue(recoveryDomain.contains("makeSupportMailURL"), "recovery domain should support contact mail routing")

assertTrue(mapViewModel.contains("@Published var syncOutboxRecoveryOverview"), "map view model should publish recovery overview")
assertTrue(mapRecoverySupport.contains("func rebuildRecoverableSyncOutboxSessions()"), "map view model should support rebuild action")
assertTrue(mapRecoverySupport.contains("func archiveCleanupEligibleSyncOutboxSessions()"), "map view model should support archive action")
assertTrue(mapRecoverySupport.contains("func syncOutboxSupportMailURL() -> URL?"), "map view model should support support mail routing")
assertTrue(mapRecoverySupport.contains("MapSyncOutboxPermanentFailurePreview"), "map view model should support UI-test preview for permanent failure recovery")

assertTrue(recoveryBanner.contains("struct SyncOutboxRecoveryBanner"), "recovery banner view should exist")
assertTrue(recoveryBanner.contains("map.syncOutbox.rebuild"), "recovery banner should expose rebuild action identifier")
assertTrue(recoveryBanner.contains("map.syncOutbox.archive"), "recovery banner should expose archive action identifier")
assertTrue(recoveryBanner.contains("map.syncOutbox.contactSupport"), "recovery banner should expose support action identifier")

assertTrue(mapView.contains("SyncOutboxRecoveryBanner("), "map view should render actionable sync outbox recovery banner")
assertTrue(mapView.contains("suppressFor: 1800"), "map view should lengthen suppression for permanent failure banner")

assertTrue(featureUITests.contains("testFeatureRegression_MapSyncPermanentFailureBannerSurfacesRecoveryChoices"), "feature regression tests should cover recovery banner surface")
assertTrue(featureUITests.contains("testFeatureRegression_MapSyncPermanentFailureRebuildActionReducesFailureCount"), "feature regression tests should cover rebuild action state transition")

assertTrue(doc.contains("rebuildable"), "recovery doc should describe rebuildable bucket")
assertTrue(doc.contains("archiveOnly"), "recovery doc should describe archive bucket")
assertTrue(doc.contains("supportRequired"), "recovery doc should describe support bucket")
assertTrue(doc.contains("동기화 목록 정리"), "recovery doc should describe archive action")
assertTrue(doc.contains("문의 메일"), "recovery doc should describe support route")

assertTrue(iosPRCheck.contains("sync_walk_permanent_failure_recovery_unit_check.swift"), "ios_pr_check should run permanent failure recovery check")

print("PASS: sync walk permanent failure recovery unit checks")
