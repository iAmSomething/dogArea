import Foundation

/// 조건이 거짓일 때 즉시 실패 코드로 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 stderr에 출력할 설명 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 상대 경로의 텍스트 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 로드된 파일의 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let spec = load("docs/game-layer-observability-qa-v1.md")
let report = load("docs/cycle-206-game-layer-observability-qa-report-2026-03-03.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(spec.contains("## 3. 공통 이벤트 규약"), "spec should include common event contract section")
assertTrue(spec.contains("quest_progress_applied"), "spec should define quest progress event key")
assertTrue(spec.contains("season_score_applied"), "spec should define season score event key")
assertTrue(spec.contains("rival_privacy_guard_blocked"), "spec should define rival privacy guard event key")
assertTrue(spec.contains("weather_feedback_submitted"), "spec should define weather feedback event key")
assertTrue(spec.contains("sync_auth_refresh_failure_rate_24h"), "spec should include auth refresh KPI")
assertTrue(spec.contains("릴리즈 블로킹 규칙"), "spec should include release blocking section")

assertTrue(report.contains("Issue: `#206`"), "cycle report should link issue 206")
assertTrue(report.contains("docs/game-layer-observability-qa-v1.md"), "cycle report should reference spec document")

assertTrue(readme.contains("docs/game-layer-observability-qa-v1.md"), "README should list observability QA spec")
assertTrue(readme.contains("docs/cycle-206-game-layer-observability-qa-report-2026-03-03.md"), "README should list cycle 206 report")

assertTrue(prCheck.contains("scripts/game_layer_observability_qa_unit_check.swift"), "ios_pr_check should include observability QA unit check")

print("PASS: game layer observability qa unit checks")
