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

let doc = load("docs/walk-result-report-card-information-architecture-v1.md")
let primaryLoopDoc = load("docs/walk-primary-loop-information-hierarchy-v1.md")
let flowDoc = load("docs/walk-value-flow-onboarding-v1.md")
let savedOutcomeCard = load("dogArea/Views/MapView/MapSubViews/MapWalkSavedOutcomeCardView.swift")
let completionCard = load("dogArea/Views/MapView/MapSubViews/WalkCompletionValueFlowCardView.swift")
let walkListHero = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailHeroSectionView.swift")
let walkListService = load("dogArea/Views/WalkListView/WalkListDetailPresentationService.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("#702"), "doc should mention issue #702")
assertTrue(doc.contains("짧은 요약 + 펼쳐보기 상세"), "doc should define the compact summary plus disclosure structure")
assertTrue(doc.contains("map.walk.savedOutcome.card"), "doc should anchor the immediate post-end surface")
assertTrue(doc.contains("walk.detail.valueFlow.card"), "doc should preserve the pre-save value flow card as a support surface")
assertTrue(doc.contains("walklist.detail.loopSummary"), "doc should anchor the stored-walk detail surface")
assertTrue(doc.contains("거의 반영 안 됨"), "doc should define the low-applied tone")
assertTrue(doc.contains("정상 반영"), "doc should define the normal-applied tone")
assertTrue(doc.contains("정책 제외 다수"), "doc should define the policy-heavy tone")
assertTrue(doc.contains("이번 산책에서 얼마나 반영됐는가"), "doc should prioritize applied-result understanding")
assertTrue(doc.contains("왜 일부는 제외됐는가"), "doc should prioritize exclusion understanding")
assertTrue(doc.contains("어디에 이어지는가"), "doc should prioritize follow-up understanding")
assertTrue(doc.contains("영역 표시 기여"), "doc should translate mark contribution for user-facing detail")
assertTrue(doc.contains("경로 기여"), "doc should translate route contribution for user-facing detail")
assertTrue(doc.contains("감쇠 적용"), "doc should translate decay contribution for user-facing detail")
assertTrue(doc.contains("상한 적용"), "doc should translate cap contribution for user-facing detail")
assertTrue(doc.contains("320pt급 작은 폭"), "doc should include small-screen density rules")

assertTrue(primaryLoopDoc.contains("상세 화면에는 `이 산책이 남기는 것` 요약"), "existing hierarchy doc should still define a stored-walk summary anchor")
assertTrue(flowDoc.contains("저장 직후"), "existing value flow doc should still define the immediate saved-outcome stage")
assertTrue(savedOutcomeCard.contains("map.walk.savedOutcome.openHistory"), "saved outcome card should keep a single post-end CTA")
assertTrue(completionCard.contains("walk.detail.valueFlow.card"), "completion card should keep its accessibility identifier")
assertTrue(walkListHero.contains("walklist.detail.loopSummary"), "walk list detail hero should keep its summary anchor")
assertTrue(walkListService.contains("이 산책이 남기는 것"), "walk list detail presentation service should keep the stored-walk summary language")
assertTrue(readme.contains("docs/walk-result-report-card-information-architecture-v1.md"), "README should index the walk result report IA doc")
assertTrue(prCheck.contains("swift scripts/walk_result_report_card_ia_unit_check.swift"), "ios_pr_check should include the walk result report IA unit check")

print("PASS: walk result report card IA checks")
