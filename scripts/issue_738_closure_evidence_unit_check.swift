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

let evidence = load("docs/issue-738-closure-evidence-v1.md")
let densityDoc = load("docs/watch-control-surface-density-v1.md")
let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#738"), "evidence doc should reference issue #738")
assertTrue(evidence.contains("control page"), "evidence doc should describe the control page")
assertTrue(evidence.contains("feedback banner"), "evidence doc should mention the feedback banner move")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(controlSurfaceView.contains("WatchMainStatusSummaryView"), "control surface should keep the minimal status summary")
assertTrue(controlSurfaceView.contains("WatchPrimaryActionDockView"), "control surface should keep the action section")
assertTrue(!controlSurfaceView.contains("WatchActionBannerView"), "control surface should not render the feedback banner")
assertTrue(!statusSummaryView.contains("compactPetContext"), "status summary should not reintroduce pet context")
assertTrue(contentView.contains("WatchActionBannerView"), "information surface should render the feedback banner")
assertTrue(densityDoc.contains("#738"), "density doc should mention issue #738")
assertTrue(readme.contains("docs/issue-738-closure-evidence-v1.md"), "README should index the issue #738 evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_738_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #738 evidence check")

print("PASS: issue #738 closure evidence unit checks")
