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

let plan = load("docs/widget-lock-screen-accessory-family-plan-v1.md")
let hotspotPrivacy = load("docs/hotspot-widget-privacy-mapping-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let widgetBundle = load("dogAreaWidgetExtension/WalkControlWidgetBundle.swift")
let walkWidget = load("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let territoryWidget = load("dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift")
let hotspotWidget = load("dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift")
let questWidget = load("dogAreaWidgetExtension/Widgets/QuestRivalStatusWidget.swift")

for heading in [
    "# Widget Lock Screen Accessory Family Plan v1",
    "## 2. Family 밀도 규칙",
    "## 3. 위젯별 Family 정보 구조",
    "## 4. 상태별 축약 규칙",
    "## 5. 핫스팟 프라이버시 유지 규칙",
    "## 6. 딥링크 규칙",
    "## 7. 기존 Family 호환성",
    "## 9. QA 체크포인트"
] {
    assertTrue(plan.contains(heading), "plan should contain heading \(heading)")
}

for family in [
    "`accessoryCircular`",
    "`accessoryRectangular`",
    "`accessoryInline`"
] {
    assertTrue(plan.contains(family), "plan should define family \(family)")
}

for widget in [
    "`WalkControlWidget`",
    "`TerritoryStatusWidget`",
    "`HotspotStatusWidget`",
    "`QuestRivalStatusWidget`"
] {
    assertTrue(plan.contains(widget), "plan should define widget row \(widget)")
}

for state in [
    "산책 중",
    "대기 중",
    "게스트",
    "오프라인",
    "`empty` 내부 상태"
] {
    assertTrue(plan.contains(state), "plan should define state abbreviation \(state)")
}

for destination in [
    "`지도` 탭",
    "`홈 > 영역 목표`",
    "`라이벌 > 익명 핫스팟`",
    "`라이벌` 탭"
] {
    assertTrue(plan.contains(destination), "plan should define deeplink destination \(destination)")
}

for privacyRule in [
    "좌표",
    "정밀 위치",
    "개별 핫스팟 수",
    "높음/보통/낮음/없음"
] {
    assertTrue(plan.contains(privacyRule), "plan should preserve hotspot privacy rule \(privacyRule)")
}

assertTrue(plan.contains("hotspot-widget-privacy-mapping-v1.md"), "plan should reference hotspot privacy mapping doc")
assertTrue(plan.contains("#511"), "plan should reference issue #511")
assertTrue(plan.contains("#408"), "plan should reference widget epic #408")
assertTrue(plan.contains("기존 `systemSmall`, `systemMedium`는 그대로 유지한다."), "plan should keep existing system widget families")

for supportedFamilyToken in [".systemSmall", ".systemMedium"] {
    assertTrue(walkWidget.contains(supportedFamilyToken), "walk widget should continue to support \(supportedFamilyToken)")
    assertTrue(territoryWidget.contains(supportedFamilyToken), "territory widget should continue to support \(supportedFamilyToken)")
    assertTrue(hotspotWidget.contains(supportedFamilyToken), "hotspot widget should continue to support \(supportedFamilyToken)")
    assertTrue(questWidget.contains(supportedFamilyToken), "quest widget should continue to support \(supportedFamilyToken)")
}

for widgetRegistration in [
    "WalkControlWidget()",
    "TerritoryStatusWidget()",
    "HotspotStatusWidget()",
    "QuestRivalStatusWidget()"
] {
    assertTrue(widgetBundle.contains(widgetRegistration), "widget bundle should still register \(widgetRegistration)")
}

assertTrue(hotspotPrivacy.contains("좌표 미노출"), "existing privacy mapping should still ban coordinate exposure")
assertTrue(readme.contains("docs/widget-lock-screen-accessory-family-plan-v1.md"), "README should link the lock screen accessory plan")
assertTrue(iosPRCheck.contains("widget_lock_screen_accessory_plan_unit_check.swift"), "ios_pr_check should run the accessory plan unit check")

print("PASS: widget lock screen accessory plan unit checks")
