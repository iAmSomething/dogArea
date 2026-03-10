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

let evidence = load("docs/issues-465-467-closure-evidence-v1.md")
let feedbackDoc = load("docs/map-quest-feedback-hud-v1.md")
let infoSetDoc = load("docs/map-quest-hud-minimum-info-set-v1.md")
let priorityDoc = load("docs/map-quest-overlay-priority-matrix-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#465"), "evidence doc should reference issue #465")
assertTrue(evidence.contains("#467"), "evidence doc should reference issue #467")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("닫아도 된다"), "evidence doc should conclude that the issue bundle can close")
assertTrue(feedbackDoc.contains("HUD + milestone toast + expandable checklist"), "quest feedback hud doc should define the three-layer feedback model")
assertTrue(feedbackDoc.contains("critical banner"), "quest feedback hud doc should define banner priority assumptions")
assertTrue(infoSetDoc.contains("2줄 + 상태 배지 1개"), "quest HUD info set doc should define the collapsed information budget")
assertTrue(infoSetDoc.contains("대표 1개 + 추가 n개"), "quest HUD info set doc should define multi-mission compression")
assertTrue(priorityDoc.contains("overlay"), "quest overlay priority doc should exist as supporting evidence")
assertTrue(readme.contains("docs/issues-465-467-closure-evidence-v1.md"), "README should index the issue bundle closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issues_465_467_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue bundle closure evidence check")

print("PASS: issues #465 #467 closure evidence unit checks")
