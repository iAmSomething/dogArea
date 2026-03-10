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

let evidence = load("docs/issues-610-611-612-closure-evidence-v1.md")
let hierarchyDoc = load("docs/walk-primary-loop-information-hierarchy-v1.md")
let startCompactDoc = load("docs/map-start-meaning-card-compact-v1.md")
let hudDisclosureDoc = load("docs/map-hud-disclosure-policy-v1.md")
let topHUDDoc = load("docs/map-top-slim-hud-safearea-v1.md")
let homeCard = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWalkPrimaryLoopCardView.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#610"), "evidence doc should reference issue #610")
assertTrue(evidence.contains("#611"), "evidence doc should reference issue #611")
assertTrue(evidence.contains("#612"), "evidence doc should reference issue #612")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("FeatureRegressionUITests.testFeatureRegression_HomeWalkPrimaryLoopCardStaysCompactAndOpensGuideOnDemand"), "evidence doc should cite the home compact disclosure regression")
assertTrue(evidence.contains("닫아도 된다"), "evidence doc should conclude that the issue bundle can close")
assertTrue(hierarchyDoc.contains("compact summary 카드"), "walk primary loop hierarchy doc should describe the compact summary card")
assertTrue(hierarchyDoc.contains("설명 보기"), "walk primary loop hierarchy doc should describe explicit disclosure")
assertTrue(startCompactDoc.contains("compact helper 카드"), "map start compact doc should preserve the helper card contract")
assertTrue(hudDisclosureDoc.contains("기본 상태는 `map.walk.activeValue.card` slim HUD"), "map hud disclosure doc should preserve slim HUD default policy")
assertTrue(topHUDDoc.contains("safe area 아래 top chrome"), "top slim HUD doc should preserve the top safe area contract")
assertTrue(homeCard.contains("home.walkPrimaryLoop.openGuide"), "home walk primary loop card should expose the guide entry affordance")
assertTrue(homeCard.contains("home.walkPrimaryLoop.guide.sheet"), "home walk primary loop guide sheet should exist")
assertTrue(homeCard.contains("home.walkPrimaryLoop.guide.pillar."), "guide sheet should host the pillar blocks for compact home primary loop disclosure")
assertTrue(homeView.contains("isWalkPrimaryLoopGuidePresented"), "HomeView should own the walk primary loop guide sheet state")
assertTrue(featureTests.contains("testFeatureRegression_HomeWalkPrimaryLoopCardStaysCompactAndOpensGuideOnDemand"), "feature regression tests should cover the home compact guide flow")
assertTrue(readme.contains("docs/issues-610-611-612-closure-evidence-v1.md"), "README should index the issue bundle closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issues_610_611_612_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue bundle closure evidence check")

print("PASS: issues #610 #611 #612 closure evidence unit checks")
