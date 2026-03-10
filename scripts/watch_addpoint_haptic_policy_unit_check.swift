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

let doc = load("docs/watch-action-feedback-ux-v1.md")
let models = load("dogAreaWatch Watch App/WatchActionFeedbackModels.swift")
let hapticService = load("dogAreaWatch Watch App/WatchActionHapticService.swift")
let viewModel = load("dogAreaWatch Watch App/ContentsViewModel.swift")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("#697"), "watch feedback doc should mention issue #697")
assertTrue(doc.contains("탭 직후"), "watch feedback doc should define immediate addPoint haptics")
assertTrue(doc.contains("0.35초"), "watch feedback doc should define the addPoint haptic throttle")
assertTrue(models.contains("enum WatchActionHapticEvent"), "watch models should define dedicated action haptic events")
assertTrue(models.contains("case addPointTapAccepted"), "watch models should define the immediate addPoint acceptance event")
assertTrue(models.contains("case addPointQueued"), "watch models should define the queued addPoint event")
assertTrue(models.contains("case addPointAcknowledged"), "watch models should define the acknowledged addPoint event")
assertTrue(models.contains("case addPointCompleted"), "watch models should define the completed addPoint event")
assertTrue(models.contains("case addPointDuplicateSuppressed"), "watch models should define the duplicate-suppressed addPoint event")
assertTrue(models.contains("case addPointFailed"), "watch models should define the failed addPoint event")
assertTrue(hapticService.contains("func playActionEvent"), "watch haptic service should expose dedicated action-event playback")
assertTrue(viewModel.contains("playInputAcknowledgementIfNeeded"), "view model should emit an immediate addPoint acknowledgement haptic")
assertTrue(viewModel.contains("lastAddPointTapHapticAt"), "view model should track addPoint haptic throttle state")
assertTrue(viewModel.contains(".addPointTapAccepted"), "view model should play the immediate addPoint acceptance haptic")
assertTrue(viewModel.contains(".addPointQueued"), "view model should play the queued addPoint haptic")
assertTrue(viewModel.contains(".addPointAcknowledged"), "view model should play the acknowledged addPoint haptic")
assertTrue(viewModel.contains(".addPointCompleted"), "view model should play the completed addPoint haptic")
assertTrue(viewModel.contains(".addPointDuplicateSuppressed"), "view model should play the duplicate-suppressed addPoint haptic")
assertTrue(viewModel.contains(".addPointFailed"), "view model should play the failed addPoint haptic")
assertTrue(prCheck.contains("swift scripts/watch_addpoint_haptic_policy_unit_check.swift"), "ios_pr_check should include the addPoint haptic policy check")

print("PASS: watch addPoint haptic policy checks")
