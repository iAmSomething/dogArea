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
let doc = read(root + "/docs/watch-action-feedback-ux-v1.md")
let view = read(root + "/dogAreaWatch Watch App/ContentView.swift")
let viewModel = read(root + "/dogAreaWatch Watch App/ContentsViewModel.swift")
let models = read(root + "/dogAreaWatch Watch App/WatchActionFeedbackModels.swift")
let buttonView = read(root + "/dogAreaWatch Watch App/WatchActionButtonView.swift")
let actionDockView = read(root + "/dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let bannerView = read(root + "/dogAreaWatch Watch App/WatchActionBannerView.swift")
let queueCardView = read(root + "/dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift")
let controlSurfaceView = read(root + "/dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let hapticService = read(root + "/dogAreaWatch Watch App/WatchActionHapticService.swift")
let checkScript = read(root + "/scripts/ios_pr_check.sh")

assertTrue(readme.contains("watch-action-feedback-ux-v1.md"), "README should index watch action feedback doc")
assertTrue(doc.contains("#520"), "doc should mention issue #520")
assertTrue(doc.contains("#697"), "doc should mention issue #697")
assertTrue(doc.contains("processing"), "doc should define processing state")
assertTrue(doc.contains("queued"), "doc should define queued state")
assertTrue(doc.contains("duplicateSuppressed"), "doc should define duplicate suppression state")
assertTrue(doc.contains("3초 안 재탭"), "doc should define endWalk confirmation window")
assertTrue(doc.contains("햅틱"), "doc should document haptic policy")
assertTrue(doc.contains("탭 직후"), "doc should define immediate addPoint haptic feedback")
assertTrue(doc.contains("0.35초"), "doc should define addPoint haptic throttle policy")

assertTrue(models.contains("enum WatchActionExecutionState"), "models should define execution state enum")
assertTrue(models.contains("case confirmRequired"), "models should include confirmRequired state")
assertTrue(models.contains("var cooldownInterval"), "models should define cooldown policy")
assertTrue(models.contains("enum WatchActionHapticEvent"), "models should define dedicated watch action haptic events")
assertTrue(models.contains("var inputAcknowledgementHapticThrottleInterval"), "models should define immediate haptic throttle policy")

assertTrue(viewModel.contains("@Published private var executionStates"), "view model should publish execution states")
assertTrue(viewModel.contains("func handleActionTap"), "view model should handle user taps with UX guardrails")
assertTrue(viewModel.contains("shouldSuppressDuplicateTap"), "view model should suppress duplicate taps")
assertTrue(viewModel.contains("presentBanner"), "view model should publish banner feedback")
assertTrue(viewModel.contains("DefaultWatchActionHapticService"), "view model should use haptic service")
assertTrue(viewModel.contains("transition(action, to: .confirmRequired"), "end walk should require confirmation")
assertTrue(viewModel.contains("playInputAcknowledgementIfNeeded"), "view model should emit an immediate addPoint acknowledgement haptic")
assertTrue(viewModel.contains(".addPointTapAccepted"), "view model should trigger addPoint immediate haptic events")
assertTrue(viewModel.contains(".addPointQueued"), "view model should differentiate queued addPoint haptics")
assertTrue(viewModel.contains(".addPointCompleted"), "view model should differentiate completed addPoint haptics")

assertTrue(view.contains("WatchControlSurfaceView"), "watch content should render the unified control surface")
assertTrue(!controlSurfaceView.contains("WatchActionBannerView"), "control surface should no longer render banner view")
assertTrue(view.contains("WatchActionBannerView"), "information surface should render banner view")
assertTrue(controlSurfaceView.contains("WatchPrimaryActionDockView"), "control surface should render a dedicated action dock")
assertTrue(actionDockView.contains("WatchActionButtonView"), "watch action dock should render action button view")
assertTrue(view.contains("WatchOfflineQueueStatusCardView"), "watch content should render queue status card")
assertTrue(queueCardView.contains("ACK \\(queueStatus.lastAckStatus)"), "queue card should keep ACK visibility")
assertTrue(queueCardView.contains("큐 \\(queueStatus.pendingCount)건"), "queue card should keep queue visibility")

assertTrue(buttonView.contains("showsProgress"), "button view should support progress state")
assertTrue(bannerView.contains("WatchActionFeedbackBanner"), "banner view should render typed banner model")
assertTrue(doc.contains("info page"), "feedback doc should record that banner lives on the info page")
assertTrue(hapticService.contains("WKInterfaceDevice.current().play"), "haptic service should trigger watch haptics")
assertTrue(hapticService.contains("func playActionEvent"), "haptic service should expose dedicated action-event playback")

assertTrue(checkScript.contains("swift scripts/watch_action_feedback_ux_unit_check.swift"), "ios_pr_check should run watch feedback unit check")

print("PASS: watch action feedback UX unit checks")
