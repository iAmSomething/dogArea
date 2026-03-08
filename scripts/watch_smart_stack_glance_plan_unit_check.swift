import Foundation

/// Fails the process when a required condition is not satisfied.
/// - Parameters:
///   - condition: The boolean result to validate.
///   - message: The failure message printed to stderr.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a UTF-8 text file from the repository root.
/// - Parameter relativePath: Repository-relative file path.
/// - Returns: Entire file contents decoded as UTF-8.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let plan = load("docs/watch-smart-stack-glance-plan-v1.md")
let accessoryPlan = load("docs/widget-lock-screen-accessory-family-plan-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for heading in [
    "# Watch Smart Stack Glance Plan v1",
    "## 1. 범위와 전제",
    "## 2. 우선 지원안 결정",
    "## 3. Surface 역할 분리",
    "## 4. Active Walk 정보 우선순위",
    "## 5. Inactive 정보 우선순위",
    "## 7. Refresh / Battery 정책",
    "## 8. watch app 본문과의 역할 경계",
    "## 9. 상태별 CTA/딥링크 규칙",
    "## 11. QA 체크포인트"
] {
    assertTrue(plan.contains(heading), "plan should contain heading \(heading)")
}

for issueToken in ["#525", "#511", "#521", "#522", "#523", "#524"] {
    assertTrue(plan.contains(issueToken), "plan should reference \(issueToken)")
}

for keyword in [
    "Smart Stack widget",
    "complication 유사",
    "`accessoryRectangular`",
    "`accessoryCircular`",
    "`accessoryInline`",
    "watch app 본문",
    "고빈도 실시간 스트리밍은 금지",
    "event-driven + coarse cadence"
] {
    assertTrue(plan.contains(keyword), "plan should define keyword \(keyword)")
}

for activePriority in [
    "산책 타이머",
    "현재 포인트 수",
    "selected pet",
    "sync 상태"
] {
    assertTrue(plan.contains(activePriority), "plan should include active priority \(activePriority)")
}

for inactivePriority in [
    "오늘 퀘스트 진행",
    "selected pet readiness",
    "territory next goal",
    "마지막 sync 상태"
] {
    assertTrue(plan.contains(inactivePriority), "plan should include inactive priority \(inactivePriority)")
}

for ctaRule in [
    "오늘 퀘스트 확인",
    "앱에서 반려견 확인",
    "다음 목표 보기",
    "다시 동기화 필요"
] {
    assertTrue(plan.contains(ctaRule), "plan should define CTA rule \(ctaRule)")
}

assertTrue(plan.contains("Widget Lock Screen Accessory Family Plan v1"), "plan should reference existing accessory plan")
assertTrue(accessoryPlan.contains("accessoryRectangular"), "accessory plan should still define accessory rectangular family")
assertTrue(readme.contains("docs/watch-smart-stack-glance-plan-v1.md"), "README should index watch smart stack glance plan")
assertTrue(iosPRCheck.contains("swift scripts/watch_smart_stack_glance_plan_unit_check.swift"), "ios_pr_check should run watch smart stack glance plan unit check")

print("PASS: watch smart stack glance plan unit checks")
