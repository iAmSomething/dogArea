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

let evidence = load("docs/issue-520-closure-evidence-v1.md")
let uxDoc = load("docs/watch-action-feedback-ux-v1.md")
let feedbackModels = load("dogAreaWatch Watch App/WatchActionFeedbackModels.swift")
let buttonView = load("dogAreaWatch Watch App/WatchActionButtonView.swift")
let actionDock = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let viewModel = load("dogAreaWatch Watch App/ContentsViewModel.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#520"), "evidence doc should reference issue #520")
assertTrue(evidence.contains("PR: `#548`") || evidence.contains("PR `#548`"), "evidence doc should reference implementation PR #548")
assertTrue(evidence.contains("addPoint 즉시 햅틱"), "evidence doc should record the addPoint tactile hardening follow-up")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("watchOS Simulator"), "evidence doc should record watch build verification")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(uxDoc.contains("processing") && uxDoc.contains("queued") && uxDoc.contains("duplicateSuppressed"), "ux doc should define staged action states")
assertTrue(uxDoc.contains("3초 안 재탭"), "ux doc should define endWalk confirmation window")
assertTrue(uxDoc.contains("탭 직후"), "ux doc should define addPoint immediate tap haptic feedback")
assertTrue(feedbackModels.contains("case processing") && feedbackModels.contains("case queued") && feedbackModels.contains("case duplicateSuppressed"), "feedback models should define processing queued and duplicate states")
assertTrue(feedbackModels.contains("var confirmationWindow: TimeInterval"), "feedback models should define confirmation window")
assertTrue(feedbackModels.contains("enum WatchActionHapticEvent"), "feedback models should define dedicated addPoint haptic events")
assertTrue(buttonView.contains("showsProgress"), "watch action button should render progress state")
assertTrue(actionDock.contains("WatchActionButtonView"), "action dock should compose action buttons")
assertTrue(contentView.contains("WatchPrimaryActionDockView"), "watch content should render the action dock")
assertTrue(viewModel.contains("func handleActionTap(_ action: WatchActionType)") , "view model should expose action tap handler")
assertTrue(viewModel.contains("shouldSuppressDuplicateTap(for: action)"), "view model should suppress duplicate taps")
assertTrue(viewModel.contains("transition(action, to: .confirmRequired"), "view model should require confirmation for endWalk")
assertTrue(viewModel.contains("playInputAcknowledgementIfNeeded"), "view model should add immediate addPoint haptic acknowledgement")
assertTrue(readme.contains("docs/issue-520-closure-evidence-v1.md"), "README should index the issue #520 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_520_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #520 closure evidence check")

print("PASS: issue #520 closure evidence unit checks")
