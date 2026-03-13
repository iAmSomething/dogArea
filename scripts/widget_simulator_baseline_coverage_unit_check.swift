import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

/// 검증 조건이 실패하면 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 메시지입니다.
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let coverageDoc = read("docs/widget-simulator-baseline-coverage-matrix-v1.md")
let runnerDoc = read("docs/manual-blocker-evidence-status-runner-v1.md")
let runner = read("scripts/manual_blocker_evidence_status.sh")
let actionRunner = read("scripts/run_widget_action_regression_ui_tests.sh")
let layoutRunner = read("scripts/run_pr_fast_smoke_widget_layout_checks.sh")
let support = read("scripts/lib/widget_simulator_baseline_status.sh")
let readme = read("README.md")
let iosPRCheck = read("scripts/ios_pr_check.sh")
let backendPRCheck = read("scripts/backend_pr_check.sh")

require(coverageDoc.contains("# Widget Simulator Baseline Coverage Matrix v1"), "coverage doc title should exist")
require(coverageDoc.contains("Issue: #802"), "coverage doc should reference issue #802")
require(coverageDoc.contains("action-regression"), "coverage doc should describe action-regression suite")
require(coverageDoc.contains("layout-fast-smoke"), "coverage doc should describe layout-fast-smoke suite")
require(coverageDoc.contains("WD-008"), "coverage doc should include WD-008 coverage")
require(coverageDoc.contains("WL-008"), "coverage doc should include WL-008 coverage")
require(coverageDoc.contains("testFeatureRegression_WidgetStartRouteDefersIntoAuthEntryWhenSessionMissing"), "coverage doc should map WD-008 to the auth-defer UI test")
require(coverageDoc.contains("repo contract / static layout gate"), "coverage doc should clarify layout-fast-smoke coverage type")
require(coverageDoc.contains("simulator-coverage-summary"), "coverage doc should define the runner summary line")

require(runnerDoc.contains("coverage"), "runner doc should describe suite coverage output")
require(runnerDoc.contains("simulator-coverage-summary"), "runner doc should describe simulator coverage summary output")
require(runnerDoc.contains("docs/widget-simulator-baseline-coverage-matrix-v1.md"), "runner doc should link the coverage matrix")

require(support.contains("coverage=$coverage"), "baseline helper should persist coverage metadata")
require(actionRunner.contains("BASELINE_COVERAGE=\"WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008\""), "action runner should stamp WD coverage")
require(layoutRunner.contains("BASELINE_COVERAGE=\"WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008\""), "layout runner should stamp WL coverage")

require(runner.contains("widget_expected_baseline_coverage()"), "status runner should define expected widget baseline coverage")
require(runner.contains("simulator-coverage-summary: action %s/8, layout %s/8"), "status runner should print plain coverage summary")
require(runner.contains("- Coverage Summary: `action %s/8`, `layout %s/8`"), "status runner should print markdown coverage summary")
require(runner.contains("widget_baseline_coverage_plain"), "status runner should print plain coverage lines")
require(runner.contains("widget_baseline_coverage_markdown"), "status runner should print markdown coverage lines")

require(readme.contains("docs/widget-simulator-baseline-coverage-matrix-v1.md"), "README should link the widget simulator coverage doc")
require(iosPRCheck.contains("widget_simulator_baseline_coverage_unit_check.swift"), "ios_pr_check should run simulator coverage checks")
require(backendPRCheck.contains("widget_simulator_baseline_coverage_unit_check.swift"), "backend_pr_check should run simulator coverage checks")

print("PASS: widget simulator baseline coverage unit checks")
