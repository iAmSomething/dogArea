import Foundation

/// 조건이 거짓이면 실패 메시지를 stderr에 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 조건이 거짓일 때 출력할 오류 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let guideline = load("docs/ux-copy-guideline-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for requiredHeading in [
    "# UX Copy Guideline v1",
    "## 기본 원칙",
    "## 금지/지양 용어",
    "## 영어 사용 기준",
    "## 요소별 작성 원칙",
    "## 대표 치환 예시",
    "## QA 체크포인트"
] {
    assertTrue(guideline.contains(requiredHeading), "guideline should contain heading \(requiredHeading)")
}

for forbiddenTerm in [
    "`Fallback`",
    "`Heatmap`",
    "`Shield`",
    "`AUTO`",
    "`Undo`",
    "`today`"
] {
    assertTrue(guideline.contains(forbiddenTerm), "guideline should list \(forbiddenTerm)")
}

for replacement in [
    "날씨 정보를 잠시 불러오지 못했어요",
    "산책 분포",
    "자동 기록",
    "실행 취소",
    "오늘 +0"
] {
    assertTrue(guideline.contains(replacement), "guideline should include replacement \(replacement)")
}

assertTrue(guideline.contains("#461"), "guideline should reference the first sweep follow-up issue")
assertTrue(readme.contains("docs/ux-copy-guideline-v1.md"), "README should link the ux copy guideline doc")
assertTrue(iosPRCheck.contains("ux_copy_guideline_unit_check.swift"), "ios_pr_check should run ux copy guideline unit check")

print("PASS: ux copy guideline unit checks")
