import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 로드합니다.
/// - Parameter relativePath: 저장소 루트에서 시작하는 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeRowView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeIndoorMissionRowView.swift")
let missionService = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPresentationService.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let indoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let featureRegressionUITests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")

assertTrue(homeViewModel.contains("@Published var indoorMissionPresentation"), "HomeViewModel should publish indoor mission presentation state")
assertTrue(homeView.contains("home.quest.section.active"), "HomeView should expose the active mission section identifier")
assertTrue(homeView.contains("home.quest.section.completed"), "HomeView should expose the completed mission section identifier")
assertTrue(homeView.contains("진행 가이드"), "HomeView should render a mission guidance section")
assertTrue(homeRowView.contains("guideTitle"), "HomeIndoorMissionRowView should render self-report guide copy")
assertTrue(homeRowView.contains("home.quest.action.finalize."), "HomeIndoorMissionRowView should expose finalize CTA identifiers")
assertTrue(missionService.contains("오늘 완료한 미션"), "mission presentation service should define an archive section title")
assertTrue(missionService.contains("행동 +1 기록"), "mission presentation service should define a self-report action label")
assertTrue(indoorMissionFlow.contains("-UITest.HomeMissionLifecycleStub"), "HomeViewModel indoor mission flow should support a deterministic UI test scenario")
assertTrue(featureRegressionUITests.contains("testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState"), "FeatureRegressionUITests should cover the mission lifecycle UI")
assertTrue(featureRegressionScript.contains("testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState"), "feature regression runner should execute the mission lifecycle UI test")

print("PASS: home mission lifecycle ux unit checks")
