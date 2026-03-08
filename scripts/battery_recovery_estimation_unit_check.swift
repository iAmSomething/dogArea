import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let walkListDetail = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let walkListDetailPresentationService = load("dogArea/Views/WalkListView/WalkListDetailPresentationService.swift")
let walkSessionMetadataStore = load("dogArea/Source/WalkSessionMetadataStore.swift")
let userDefaults = loadMany([
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
let spec = load("docs/battery-recovery-estimation-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(mapViewModel.contains("recoverableWalkEstimateText"), "view model should expose recoverable estimate text")
assertTrue(mapViewModel.contains("recoverableFinalizationEstimate("), "view model should compute finalization estimate")
assertTrue(mapViewModel.contains("finalizeRecoverableWalkSessionEstimated"), "view model should expose estimated finalize API")
assertTrue(mapViewModel.contains("autoFinalizeRecoverableSession") == false, "auto finalize should be removed for recoverable draft")
assertTrue(mapViewModel.contains("recoveryFinalizeConfirmed"), "view model should track recovery finalize metrics")
assertTrue(mapViewModel.contains("recoveryFinalizeFailed"), "view model should track recovery failure metrics")

assertTrue(mapView.contains("추정 종료"), "map recoverable banner should expose estimated finalize CTA")
assertTrue(mapView.contains("recoverableWalkEstimateText"), "map recoverable banner should display estimate text")
assertTrue(mapView.contains("case .recoverableSession: return 0"), "banner priority should rank recoverable session first")

assertTrue(
    walkSessionMetadataStore.contains("case recoveryEstimated = \"recovery_estimated\"") ||
    userDefaults.contains("case recoveryEstimated = \"recovery_estimated\""),
    "metadata reason should support recovery_estimated"
)
assertTrue(
    walkListDetail.contains("recovery_estimated") || walkListDetailPresentationService.contains("case .recoveryEstimated"),
    "walk list detail should render recovery_estimated reason"
)

assertTrue(spec.contains("자동 재개 금지"), "spec should forbid auto resume")
assertTrue(spec.contains("자동 종료/자동 확정 금지"), "spec should forbid auto finalize")
assertTrue(checklist.contains("배터리 종료 복구 배너"), "checklist should include battery recovery estimated finalize scenario")

print("PASS: battery recovery estimation unit checks")
