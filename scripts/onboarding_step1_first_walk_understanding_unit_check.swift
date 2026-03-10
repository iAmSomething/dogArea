import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트를 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 문서 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/first-walk-onboarding-step1-understanding-v1.md")
let readme = load("README.md")
let walkValueDoc = load("docs/walk-value-flow-onboarding-v1.md")
let guideService = load("dogArea/Source/Domain/Map/Services/WalkValueGuidePresentationService.swift")
let startMeaningCard = load("dogArea/Views/MapView/MapSubViews/MapWalkStartMeaningCardView.swift")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("- Issue: #703"), "step1 doc must reference issue #703")
assertTrue(doc.contains("산책을 시작하면 무엇이 기록되는가"), "step1 doc must include the first user question")
assertTrue(doc.contains("이 기록이 어디에 이어지는가"), "step1 doc must include the second user question")
assertTrue(doc.contains("실내 미션은 기본 루프의 어느 위치"), "step1 doc must include the mission positioning question")
assertTrue(doc.contains("1. 기록"), "step1 doc must define the first priority")
assertTrue(doc.contains("2. 영역"), "step1 doc must define the second priority")
assertTrue(doc.contains("3. 시즌"), "step1 doc must define the third priority")
assertTrue(doc.contains("4. 미션"), "step1 doc must define the fourth priority")
assertTrue(doc.contains("Step1에서는 설정값"), "step1 doc must keep settings out of step1")
assertTrue(doc.contains("가이드 다시 보기"), "step1 doc must define a reopen path")
assertTrue(doc.contains("Step2"), "step1 doc must connect to step2")
assertTrue(walkValueDoc.contains("기록되는 것: `경로`, `영역`, `시간`, `포인트`"), "existing walk value doc must keep the canonical recorded values")
assertTrue(guideService.contains("첫 산책 가이드"), "walk value guide service should still expose first walk guide naming")
assertTrue(startMeaningCard.contains("map.walk.guide.reopen"), "map start meaning card should still expose guide reopen action")
assertTrue(readme.contains("docs/first-walk-onboarding-step1-understanding-v1.md"), "README must index step1 doc")
assertTrue(prCheck.contains("swift scripts/onboarding_step1_first_walk_understanding_unit_check.swift"), "ios_pr_check must run step1 onboarding check")

print("PASS: onboarding step1 first walk understanding unit checks")
