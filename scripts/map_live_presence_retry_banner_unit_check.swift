import Foundation

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    return try! String(contentsOf: url, encoding: .utf8)
}

let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let retrySupport = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+LivePresenceRetrySupport.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let project = load("dogArea.xcodeproj/project.pbxproj")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(mapViewModel.contains("@Published var livePresenceRetryBannerText: String = \"\""), "MapViewModel should expose live presence retry banner text")
assertTrue(mapViewModel.contains("var livePresenceRetryState = MapLivePresenceRetryState()"), "MapViewModel should keep live presence retry state")
assertTrue(mapViewModel.contains("guard shouldSkipLivePresenceFlush(now: Date()) == false else { return }"), "flush should honor retry backoff gate")
assertTrue(mapViewModel.contains("self.applyLivePresenceFailureBackoff(for: error, now: now)"), "retryable failure should apply backoff")
assertTrue(mapViewModel.contains("self.presentLivePresenceFailureBannerIfNeeded(for: error, now: now)"), "retryable failure should surface banner")
assertTrue(mapViewModel.contains("self.resetLivePresenceRetryFailureState()"), "successful flush should reset retry failure state")
assertTrue(retrySupport.contains("struct MapLivePresenceRetryState"), "retry support file should define retry state model")
assertTrue(retrySupport.contains("static let baseBackoffInterval: TimeInterval = 10"), "retry support should define base backoff")
assertTrue(retrySupport.contains("static let maxBackoffInterval: TimeInterval = 120"), "retry support should define max backoff")
assertTrue(retrySupport.contains("static let bannerCooldownInterval: TimeInterval = 20"), "retry support should define banner cooldown")
assertTrue(retrySupport.contains("func applyLivePresenceFailureBackoff"), "retry support should define failure backoff helper")
assertTrue(retrySupport.contains("func presentLivePresenceFailureBannerIfNeeded"), "retry support should define banner dedupe helper")
assertTrue(mapView.contains("case .livePresenceRetry:"), "MapView banner switch should render live presence retry banner")
assertTrue(mapView.contains("if viewModel.hasLivePresenceRetryBanner"), "MapView should enqueue live presence retry banner candidate")
assertTrue(mapView.contains("viewModel.clearLivePresenceRetryBanner()"), "MapView should clear retry banner when dismissed")
assertTrue(mapView.contains("case livePresenceRetry"), "MapView banner kinds should include live presence retry")
assertTrue(project.contains("MapViewModel+LivePresenceRetrySupport.swift"), "Xcode project should include live presence retry support file")
assertTrue(iosCheck.contains("map_live_presence_retry_banner_unit_check.swift"), "ios_pr_check should run live presence retry banner unit check")

print("PASS: map live presence retry banner unit checks")
