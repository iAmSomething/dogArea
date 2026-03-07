import Foundation

/// 조건이 거짓이면 stderr 출력 후 실패 코드로 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
/// - Returns: 없음. 실패 시 프로세스를 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 상대 경로의 파일을 UTF-8 문자열로 로드합니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let defaults = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionModels.swift",
    "dogArea/Source/UserDefaultsSupport/UserDefaultsCodableExtensions.swift",
    "dogArea/Source/UserDefaultsSupport/UserdefaultSetting+SessionFacade.swift",
    "dogArea/Source/UserDefaultsSupport/UserSessionStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppPreferenceStores.swift",
    "dogArea/Source/UserDefaultsSupport/FeatureFlagStore.swift",
    "dogArea/Source/UserDefaultsSupport/AppMetricTracker.swift",
    "dogArea/Source/UserDefaultsSupport/SyncOutboxStore.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let rivalViewModel = loadMany([
    "dogArea/Views/ProfileSettingView/RivalTabViewModel.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SessionLifecycle.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift",
    "dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+ModerationAndLocation.swift"
])
let rivalSpec = load("docs/rival-tab-ux-usecase-spec-v1.md")
let gameLayerSpec = load("docs/game-layer-observability-qa-v1.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(defaults.contains("case rivalPrivacyOptInCompleted = \"rival_privacy_opt_in_completed\""), "metric enum should define rival_privacy_opt_in_completed")
assertTrue(defaults.contains("case rivalLeaderboardFetched = \"rival_leaderboard_fetched\""), "metric enum should define rival_leaderboard_fetched")
assertTrue(defaults.contains("case rivalHotspotFetchSucceeded = \"rival_hotspot_fetch_succeeded\""), "metric enum should define rival_hotspot_fetch_succeeded")
assertTrue(defaults.contains("case rivalHotspotFetchFailed = \"rival_hotspot_fetch_failed\""), "metric enum should define rival_hotspot_fetch_failed")

assertTrue(rivalViewModel.contains("metricTracker: AppMetricTracker"), "rival view model should keep metric tracker dependency")
assertTrue(rivalViewModel.contains(".rivalPrivacyOptInCompleted"), "consent success should emit rival_privacy_opt_in_completed")
assertTrue(rivalViewModel.contains(".rivalHotspotFetchSucceeded"), "hotspot success should emit rival_hotspot_fetch_succeeded")
assertTrue(rivalViewModel.contains(".rivalHotspotFetchFailed"), "hotspot failure should emit rival_hotspot_fetch_failed")
assertTrue(rivalViewModel.contains(".rivalLeaderboardFetched"), "leaderboard fetch should emit rival_leaderboard_fetched")

assertTrue(rivalSpec.contains("rival_privacy_opt_in_completed"), "rival ux spec should include opt-in completed event")
assertTrue(rivalSpec.contains("rival_hotspot_fetch_succeeded"), "rival ux spec should include hotspot success event")
assertTrue(rivalSpec.contains("rival_hotspot_fetch_failed"), "rival ux spec should include hotspot failure event")
assertTrue(gameLayerSpec.contains("rival_privacy_opt_in_completed"), "game-layer spec should include rival privacy opt-in event")
assertTrue(gameLayerSpec.contains("rival_leaderboard_fetched"), "game-layer spec should include rival leaderboard fetched event")

assertTrue(prCheck.contains("scripts/rival_observability_metrics_unit_check.swift"), "ios_pr_check should include rival observability metrics check")

print("PASS: rival observability metrics unit checks")
