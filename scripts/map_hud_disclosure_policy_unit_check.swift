import Foundation

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

let startModels = load("dogArea/Views/MapView/MapViewModelSupport/MapWalkStartPresentationModels.swift")
let startService = load("dogArea/Source/Domain/Map/Services/MapWalkStartPresentationService.swift")
let startCard = load("dogArea/Views/MapView/MapSubViews/MapWalkStartMeaningCardView.swift")
let activeModels = load("dogArea/Views/MapView/MapViewModelSupport/MapWalkValueFlowPresentationModels.swift")
let activeService = load("dogArea/Source/Domain/Map/Services/MapWalkValueFlowPresentationService.swift")
let activeCard = load("dogArea/Views/MapView/MapSubViews/MapWalkActiveValueCardView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/map-hud-disclosure-policy-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(startModels.contains("let meaningSummary: String"), "start presentation should expose a compact summary")
assertTrue(startModels.contains("let meaningDetail: String"), "start presentation should expose an expanded detail body")
assertTrue(startService.contains("meaningSummary: \"경로·영역·시간이 함께 저장돼요.\""), "start presentation service should define the compact disclosure summary")
assertTrue(startCard.contains("map.walk.startMeaning.expand"), "start meaning card should expose an expand identifier")
assertTrue(startCard.contains("map.walk.startMeaning.collapse"), "start meaning card should expose a collapse identifier")
assertTrue(startCard.contains("map.walk.startMeaning.detail"), "start meaning card should expose a detail identifier")
assertTrue(activeModels.contains("enum MapWalkTopHUDDisclosureMode"), "walking HUD should define a disclosure mode model")
assertTrue(activeService.contains("disclosureMode: hasCompetingTopChrome ? .openGuideSheet : .expandInline"), "walking HUD should fall back to guide sheet when competing overlays exist")
assertTrue(activeCard.contains("map.walk.activeValue.expand"), "walking HUD should expose an expand identifier")
assertTrue(activeCard.contains("map.walk.activeValue.detail.card"), "walking HUD should expose an inline detail card identifier")
assertTrue(activeCard.contains("map.walk.activeValue.collapse"), "walking HUD should expose a collapse identifier")
assertTrue(mapView.contains("walkingHUDDetailContent"), "MapView should wire the walking HUD detail slot into top chrome")
assertTrue(mapView.contains("handleWalkingHUDPrimaryDisclosure"), "MapView should own the walking HUD disclosure policy")
assertTrue(mapView.contains("if hasCompeting {\n                isWalkingHUDDetailPresented = false"), "MapView should auto-collapse walking inline detail when competing chrome appears")
assertTrue(featureTests.contains("testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested"), "feature regression tests should cover idle disclosure expansion")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested"), "feature regression tests should cover walking disclosure expansion")
assertTrue(featureScript.contains("testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested"), "feature regression script should run idle disclosure expansion coverage")
assertTrue(featureScript.contains("testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested"), "feature regression script should run walking disclosure expansion coverage")
assertTrue(uiMatrix.contains("FR-MAP-005A"), "ui regression matrix should include the idle disclosure regression")
assertTrue(uiMatrix.contains("FR-MAP-005B"), "ui regression matrix should include the walking disclosure regression")
assertTrue(doc.contains("시작 전 정책"), "policy doc should define a before-walk disclosure policy")
assertTrue(doc.contains("산책 중 정책"), "policy doc should define an in-walk disclosure policy")
assertTrue(doc.contains("overlay 우선순위"), "policy doc should define overlay priority rules")
assertTrue(readme.contains("docs/map-hud-disclosure-policy-v1.md"), "README should index the map HUD disclosure policy doc")
assertTrue(prCheck.contains("swift scripts/map_hud_disclosure_policy_unit_check.swift"), "ios_pr_check should include the disclosure policy unit check")

print("PASS: map hud disclosure policy checks")
