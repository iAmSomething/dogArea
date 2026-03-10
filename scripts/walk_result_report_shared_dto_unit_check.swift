import Foundation

/// 조건이 거짓이면 표준 에러에 메시지를 출력하고 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
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

let doc = load("docs/walk-result-report-shared-dto-v1.md")
let flowDoc = load("docs/walk-value-flow-onboarding-v1.md")
let runtimeDoc = load("docs/walk-runtime-guardrails-v1.md")
let flowService = load("dogArea/Source/Domain/Map/Services/MapWalkValueFlowPresentationService.swift")
let savedOutcomeCard = load("dogArea/Views/MapView/MapSubViews/MapWalkSavedOutcomeCardView.swift")
let completionCard = load("dogArea/Views/MapView/MapSubViews/WalkCompletionValueFlowCardView.swift")
let walkListHero = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailHeroSectionView.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("#701"), "doc should mention issue #701")
assertTrue(doc.contains("#267"), "doc should mention umbrella issue #267")
assertTrue(doc.contains("숫자 계산 소스와 사용자 문구 소스를 분리"), "doc should separate calculation and copy sources")
assertTrue(doc.contains("WalkOutcomeCalculationSnapshot"), "doc should define the calculation snapshot layer")
assertTrue(doc.contains("WalkOutcomeExplanationDTO"), "doc should define the shared explanation DTO")
assertTrue(doc.contains("반영 포인트 수"), "doc should require applied point count")
assertTrue(doc.contains("제외 포인트 수"), "doc should require excluded point count")
assertTrue(doc.contains("제외 비율"), "doc should require excluded ratio")
assertTrue(doc.contains("주요 제외 사유별 카운트"), "doc should require exclusion reason breakdown")
assertTrue(doc.contains("mark"), "doc should keep mark contribution in the DTO contract")
assertTrue(doc.contains("route"), "doc should keep route contribution in the DTO contract")
assertTrue(doc.contains("감쇠 적용값"), "doc should define decay contribution in the DTO contract")
assertTrue(doc.contains("cap 적용값"), "doc should define cap contribution in the DTO contract")
assertTrue(doc.contains("영역/목표"), "doc should require territory/goal connection metadata")
assertTrue(doc.contains("시즌"), "doc should require season connection metadata")
assertTrue(doc.contains("미션/퀘스트"), "doc should require mission/quest connection metadata")
assertTrue(doc.contains("거의 반영 안 됨"), "doc should define low-applied edge state")
assertTrue(doc.contains("정책 제외 다수"), "doc should define policy-dominant exclusion state")

assertTrue(flowDoc.contains("저장 직후"), "existing walk value flow doc should still define a saved-outcome surface")
assertTrue(runtimeDoc.contains("폐기 샘플은"), "runtime guardrail doc should still define excluded samples")
assertTrue(flowService.contains("makeSavedOutcomePresentation"), "map flow service should still expose saved outcome presentation")
assertTrue(flowService.contains("makeCompletionValuePresentation"), "map flow service should still expose completion value presentation")
assertTrue(savedOutcomeCard.contains("map.walk.savedOutcome.card"), "saved outcome card should remain the immediate result surface")
assertTrue(completionCard.contains("walk.detail.valueFlow.card"), "completion card should remain the pre-save value flow surface")
assertTrue(walkListHero.contains("walklist.detail.loopSummary"), "walk list detail hero should remain the stored-walk detail anchor")
assertTrue(readme.contains("docs/walk-result-report-shared-dto-v1.md"), "README should index the shared DTO doc")
assertTrue(prCheck.contains("swift scripts/walk_result_report_shared_dto_unit_check.swift"), "ios_pr_check should include the shared DTO unit check")

print("PASS: walk result report shared DTO checks")
