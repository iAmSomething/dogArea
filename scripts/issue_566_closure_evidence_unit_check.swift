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

let evidence = load("docs/issue-566-closure-evidence-v1.md")
let hierarchyDoc = load("docs/walk-primary-loop-information-hierarchy-v1.md")
let flowDoc = load("docs/walk-value-flow-onboarding-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#566"), "evidence doc should reference issue #566")
assertTrue(evidence.contains("PR `#585`"), "evidence doc should reference implementation PR #585")
assertTrue(evidence.contains("PR `#586`"), "evidence doc should reference implementation PR #586")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("FeatureRegressionUITests.testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop"), "evidence doc should cite the primary loop regression test")
assertTrue(evidence.contains("FeatureRegressionUITests.testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving"), "evidence doc should cite the walk value flow regression test")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(hierarchyDoc.contains("산책이 이 앱의 시작점"), "hierarchy doc should preserve the home primary loop message")
assertTrue(flowDoc.contains("산책 위에 얹힌 보조 시스템"), "walk value flow doc should preserve the secondary mission framing")
assertTrue(readme.contains("docs/issue-566-closure-evidence-v1.md"), "README should index the issue #566 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_566_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #566 closure evidence check")

print("PASS: issue #566 closure evidence unit checks")
