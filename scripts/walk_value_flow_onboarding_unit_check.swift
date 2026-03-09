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

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let topChrome = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let startMeaningCard = load("dogArea/Views/MapView/MapSubViews/MapWalkStartMeaningCardView.swift")
let activeCard = load("dogArea/Views/MapView/MapSubViews/MapWalkActiveValueCardView.swift")
let savedCard = load("dogArea/Views/MapView/MapSubViews/MapWalkSavedOutcomeCardView.swift")
let walkDetailView = load("dogArea/Views/MapView/WalkDetailView.swift")
let walkDetailVM = load("dogArea/Views/MapView/WalkDetailViewModel.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let guideSheet = load("dogArea/Views/GlobalViews/WalkGuide/WalkValueGuideSheetView.swift")
let guideService = load("dogArea/Source/Domain/Map/Services/WalkValueGuidePresentationService.swift")
let guideStore = load("dogArea/Source/UserDefaultsSupport/WalkValueGuideStateStore.swift")
let flowService = load("dogArea/Source/Domain/Map/Services/MapWalkValueFlowPresentationService.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walk-value-flow-onboarding-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(mapView.contains("walkValueGuideSheetPresentation"), "MapView should bind the walk value guide sheet state")
assertTrue(mapViewModel.contains("walkValueGuidePresentation"), "MapViewModel should publish walk value guide presentation state")
assertTrue(mapViewModel.contains("walkSavedOutcomePresentation"), "MapViewModel should publish saved outcome presentation state")
assertTrue(mapView.contains("walkingHUDContent: walkingHUDContent"), "MapView should route the walking slim HUD through top chrome")
assertTrue(topChrome.contains("if let walkingHUDContent"), "MapTopChromeView should render the walking slim HUD slot")
assertTrue(startButton.contains("walkingControlContextCard"), "StartButtonView should keep a compact control context card while walking")
assertTrue(startButton.contains("MapWalkActiveValueCardView") == false, "StartButtonView should no longer render the walking value helper directly")
assertTrue(startMeaningCard.contains("map.walk.guide.reopen"), "start meaning card should expose a guide reopen affordance")
assertTrue(activeCard.contains("map.walk.activeValue.card"), "active value card should expose an accessibility identifier")
assertTrue(savedCard.contains("map.walk.savedOutcome.card"), "saved outcome card should expose an accessibility identifier")
assertTrue(savedCard.contains("map.walk.savedOutcome.openHistory"), "saved outcome card should expose a history CTA identifier")
assertTrue(walkDetailView.contains("WalkCompletionValueFlowCardView"), "WalkDetailView should render the completion value flow card")
assertTrue(walkDetailVM.contains("makeCompletionValuePresentation"), "WalkDetailViewModel should build completion value presentation")
assertTrue(rootView.contains("openWalkHistoryRequested"), "RootView should react to open walk history notifications")
assertTrue(guideSheet.contains("map.walk.guide.sheet"), "walk value guide sheet should expose an accessibility identifier")
assertTrue(guideService.contains("protocol WalkValueGuidePresentationProviding"), "walk value guide should be protocol-first")
assertTrue(guideStore.contains("protocol WalkValueGuideStateStoring"), "walk value guide state store should be protocol-first")
assertTrue(flowService.contains("protocol MapWalkValueFlowPresenting"), "walk value flow helper should be protocol-first")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkValueGuideAutoPresentsOnFirstVisit"), "feature regression tests should cover automatic walk value guide presentation")
assertTrue(featureTests.contains("testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving"), "feature regression tests should cover during/end flow guidance")
assertTrue(featureScript.contains("testFeatureRegression_MapWalkValueGuideAutoPresentsOnFirstVisit"), "feature regression script should include walk value guide regression")
assertTrue(featureScript.contains("testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving"), "feature regression script should include value flow regression")
assertTrue(uiMatrix.contains("FR-MAP-004"), "ui regression matrix should include the walk value guide regression entry")
assertTrue(uiMatrix.contains("FR-MAP-005"), "ui regression matrix should include the during/end value flow regression entry")
assertTrue(uiMatrix.contains("FR-MAP-008"), "ui regression matrix should include the slim top HUD regression entry")
assertTrue(doc.contains("map.walk.savedOutcome.card"), "doc should mention the saved outcome card surface")
assertTrue(readme.contains("docs/walk-value-flow-onboarding-v1.md"), "README should index the walk value flow doc")
assertTrue(prCheck.contains("swift scripts/walk_value_flow_onboarding_unit_check.swift"), "ios_pr_check should include the walk value flow unit check")

print("PASS: walk value flow onboarding checks")
