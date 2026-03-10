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

let evidence = load("docs/issues-618-619-622-closure-evidence-v1.md")
let disclosureDoc = load("docs/map-hud-disclosure-policy-v1.md")
let topHUDDoc = load("docs/map-top-slim-hud-safearea-v1.md")
let walkListSafeAreaDoc = load("docs/walklist-top-safearea-contract-v1.md")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#618"), "evidence doc should reference issue #618")
assertTrue(evidence.contains("#619"), "evidence doc should reference issue #619")
assertTrue(evidence.contains("#622"), "evidence doc should reference issue #622")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("닫아도 된다"), "evidence doc should conclude that the issue bundle can close")
assertTrue(disclosureDoc.contains("기본 상태는 `map.walk.activeValue.card` slim HUD"), "map hud disclosure doc should preserve slim HUD default policy")
assertTrue(topHUDDoc.contains("safe area 아래 top chrome"), "top slim HUD doc should preserve the top safe area contract")
assertTrue(walkListSafeAreaDoc.contains("safeAreaInset(edge: .top)"), "walk list safe area doc should preserve the root safe area inset contract")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested"), "feature regression tests should cover the walking HUD disclosure flow")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls"), "feature regression tests should cover the top slim HUD layout")
assertTrue(featureTests.contains("testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar"), "feature regression tests should cover the walk list sticky header safe area contract")
assertTrue(readme.contains("docs/issues-618-619-622-closure-evidence-v1.md"), "README should index the issue bundle closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issues_618_619_622_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue bundle closure evidence check")

print("PASS: issues #618 #619 #622 closure evidence unit checks")
