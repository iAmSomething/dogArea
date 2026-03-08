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

let model = load("dogArea/Source/Domain/Home/Models/HomeMissionGuidePresentation.swift")
let service = load("dogArea/Source/Domain/Home/Services/HomeMissionGuidePresentationService.swift")
let store = load("dogArea/Source/UserDefaultsSupport/HomeMissionGuideStateStore.swift")
let sheet = load("dogArea/Views/GlobalViews/HomeGuide/HomeMissionGuideSheetView.swift")
let coachCard = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeMissionGuideCoachCardView.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/home-quest-help-layer-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(model.contains("enum HomeMissionGuideEntryContext"), "guide entry context model should exist")
assertTrue(model.contains("struct HomeMissionGuidePresentation"), "guide presentation model should exist")
assertTrue(service.contains("protocol HomeMissionGuidePresentationProviding"), "guide presentation service should be protocol-first")
assertTrue(service.contains("무엇을 하는 카드인가요?"), "guide service should include the 'what' axis")
assertTrue(service.contains("산책 기반 자동 기록"), "guide service should compare automatic walk tracking with manual indoor logging")
assertTrue(store.contains("home.mission.guide.initial.presented.v1"), "guide store should persist the first-presented flag")
assertTrue(sheet.contains("home.quest.help.sheet"), "guide sheet should expose a root accessibility identifier")
assertTrue(sheet.contains("home.quest.help.axis.what"), "guide sheet should expose the what axis identifier")
assertTrue(sheet.contains("home.quest.help.compare.auto"), "guide sheet should expose the automatic tracking comparison identifier")
assertTrue(coachCard.contains("home.quest.help.coach"), "coach card should expose a root accessibility identifier")
assertTrue(coachCard.contains("home.quest.help.coach.open"), "coach card should expose an open CTA identifier")
assertTrue(homeView.contains("homeMissionGuidePresentationService"), "HomeView should keep a dedicated guide service")
assertTrue(homeView.contains("openHomeMissionGuide(for:"), "HomeView should expose a guide re-entry action")
assertTrue(homeView.contains("evaluateHomeMissionGuideCoachIfNeeded"), "HomeView should evaluate the first-visit coach state")
assertTrue(featureTests.contains("testFeatureRegression_HomeMissionHelpLayerExplainsWhatWhyHowAndOutcome"), "UI tests should cover the mission help layer")
assertTrue(featureScript.contains("testFeatureRegression_HomeMissionHelpLayerExplainsWhatWhyHowAndOutcome"), "feature regression script should include the mission help layer test")
assertTrue(uiMatrix.contains("FR-HOME-QUEST-002"), "UI regression matrix should register the mission help layer case")
assertTrue(doc.contains("home.mission.guide.initial.presented.v1"), "doc should mention the persisted first-entry key")
assertTrue(readme.contains("docs/home-quest-help-layer-v1.md"), "README should index the home mission help layer doc")
assertTrue(iosCheck.contains("swift scripts/home_mission_help_layer_unit_check.swift"), "ios_pr_check should include the mission help layer unit check")
assertTrue(project.contains("HomeMissionGuideSheetView.swift"), "Xcode project should include the guide sheet file")
assertTrue(project.contains("HomeMissionGuideCoachCardView.swift"), "Xcode project should include the coach card file")

print("PASS: home mission help layer checks")
