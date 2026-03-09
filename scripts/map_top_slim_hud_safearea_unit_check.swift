import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let topChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let startButtonView = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let activeCard = load("dogArea/Views/MapView/MapSubViews/MapWalkActiveValueCardView.swift")
let presentationService = load("dogArea/Source/Domain/Map/Services/MapWalkValueFlowPresentationService.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/map-top-slim-hud-safearea-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(mapView.contains("walkingHUDContent: walkingHUDContent"), "MapView should pass the walking HUD slot into MapTopChromeView")
assertTrue(mapView.contains("private var walkingHUDPresentation: MapWalkTopHUDPresentation?"), "MapView should build a dedicated walking HUD presentation")
assertTrue(mapView.contains("hasCompetingTopChrome"), "MapView should define top chrome competition state for the slim HUD")
assertTrue(topChromeView.contains("let walkingHUDContent: AnyView?"), "MapTopChromeView should accept the walking HUD slot")
assertTrue(topChromeView.contains("if let walkingHUDContent"), "MapTopChromeView should render the walking HUD below the primary chrome row")
assertTrue(startButtonView.contains("MapWalkActiveValueCardView") == false, "StartButtonView should not render the walking active card inside the bottom control bar anymore")
assertTrue(startButtonView.contains("walkingControlContextCard"), "StartButtonView should keep a dedicated control context card while walking")
assertTrue(activeCard.contains("ViewThatFits(in: .horizontal)"), "MapWalkActiveValueCardView should use ViewThatFits to enforce slim HUD wrapping")
assertTrue(activeCard.contains("map.walk.activeValue.card"), "MapWalkActiveValueCardView should preserve the walking HUD accessibility identifier")
assertTrue(activeCard.contains("map.walk.activeValue.openGuide"), "MapWalkActiveValueCardView should expose the guide reopen affordance identifier")
assertTrue(presentationService.contains("protocol MapWalkTopHUDPresenting"), "top HUD presentation should be protocol-first")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls"), "feature regression tests should cover the top slim HUD geometry")
assertTrue(featureScript.contains("testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls"), "feature regression script should run the top slim HUD regression")
assertTrue(uiMatrix.contains("FR-MAP-008"), "ui regression matrix should include the top slim HUD regression")
assertTrue(doc.contains("safe area 바로 아래 top chrome band"), "doc should record safe area anchored placement")
assertTrue(doc.contains("하단 control bar는 `조작`, 상단 HUD는 `상태`만 책임"), "doc should record the status/control separation")
assertTrue(readme.contains("docs/map-top-slim-hud-safearea-v1.md"), "README should index the top slim HUD doc")
assertTrue(prCheck.contains("swift scripts/map_top_slim_hud_safearea_unit_check.swift"), "ios_pr_check should include the top slim HUD unit check")

print("PASS: map top slim HUD safe area checks")
