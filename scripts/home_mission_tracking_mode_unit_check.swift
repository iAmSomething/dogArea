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

let model = load("dogArea/Source/Domain/Home/Models/HomeMissionTrackingModels.swift")
let service = load("dogArea/Source/Domain/Home/Services/HomeMissionTrackingPresentationService.swift")
let indoorMissionPresentation = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPresentationService.swift")
let stateModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let rowView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeIndoorMissionRowView.swift")
let overviewView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeMissionTrackingModeOverviewView.swift")
let badgeView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeMissionTrackingBadgeView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let matrix = load("docs/ui-regression-matrix-v1.md")
let guideline = load("docs/home-quest-tracking-mode-guideline-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(model.contains("enum HomeMissionTrackingModeKind"), "tracking mode kind model should exist")
assertTrue(model.contains("struct HomeMissionTrackingModePresentation"), "tracking mode presentation model should exist")
assertTrue(service.contains("protocol HomeMissionTrackingModePresenting"), "tracking mode service should be protocol-first")
assertTrue(service.contains("자동 기록"), "tracking mode service should use canonical automatic wording")
assertTrue(service.contains("직접 체크"), "tracking mode service should use canonical manual wording")
assertTrue(indoorMissionPresentation.contains("trackingOverviewTitle"), "indoor mission board should expose tracking overview title")
assertTrue(indoorMissionPresentation.contains("trackingModes:"), "indoor mission board should populate tracking modes")
assertTrue(stateModels.contains("let trackingMode: HomeMissionTrackingModePresentation"), "row presentation should carry tracking mode presentation")
assertTrue(stateModels.contains("let trackingSummaryText: String"), "row presentation should carry tracking summary text")
assertTrue(stateModels.contains("let trackingOverviewTitle: String"), "board presentation should expose tracking overview title")
assertTrue(stateModels.contains("let trackingModes: [HomeMissionTrackingModePresentation]"), "board presentation should expose tracking mode cards")
assertTrue(homeView.contains("HomeMissionTrackingModeOverviewView"), "HomeView should render the tracking mode overview")
assertTrue(rowView.contains("home.quest.row.\\(mission.id).tracking"), "mission row should expose the tracking badge accessibility identifier")
assertTrue(rowView.contains("home.quest.row.\\(mission.id).trackingSummary"), "mission row should expose the tracking summary accessibility identifier")
assertTrue(service.contains("id: \"auto\""), "tracking mode service should define the automatic mode identifier")
assertTrue(service.contains("id: \"manual\""), "tracking mode service should define the manual mode identifier")
assertTrue(overviewView.contains("home.quest.tracking.\\(mode.id)"), "overview should expose the per-mode tracking card accessibility identifier")
assertTrue(badgeView.contains("case .automatic"), "badge view should style the automatic mode explicitly")
assertTrue(badgeView.contains("case .manual"), "badge view should style the manual mode explicitly")
assertTrue(featureTests.contains("testFeatureRegression_HomeMissionCardDifferentiatesAutoAndManualTrackingModes"), "feature regression tests should cover auto/manual tracking differentiation")
assertTrue(featureScript.contains("testFeatureRegression_HomeMissionCardDifferentiatesAutoAndManualTrackingModes"), "feature regression script should include the tracking differentiation test")
assertTrue(matrix.contains("FR-HOME-QUEST-003"), "UI regression matrix should register the tracking mode differentiation case")
assertTrue(guideline.contains("자동 기록"), "guideline should include the canonical automatic label")
assertTrue(guideline.contains("직접 체크"), "guideline should include the canonical manual label")
assertTrue(guideline.contains("산책 중 자동 반영"), "guideline should include the canonical automatic title")
assertTrue(guideline.contains("실내 행동 직접 기록"), "guideline should include the canonical manual title")
assertTrue(readme.contains("docs/home-quest-tracking-mode-guideline-v1.md"), "README should index the tracking mode guideline doc")
assertTrue(iosCheck.contains("swift scripts/home_mission_tracking_mode_unit_check.swift"), "ios_pr_check should include the tracking mode unit check")
assertTrue(project.contains("HomeMissionTrackingModels.swift"), "Xcode project should include HomeMissionTrackingModels.swift")
assertTrue(project.contains("HomeMissionTrackingPresentationService.swift"), "Xcode project should include HomeMissionTrackingPresentationService.swift")
assertTrue(project.contains("HomeMissionTrackingBadgeView.swift"), "Xcode project should include HomeMissionTrackingBadgeView.swift")
assertTrue(project.contains("HomeMissionTrackingModeOverviewView.swift"), "Xcode project should include HomeMissionTrackingModeOverviewView.swift")

print("PASS: home mission tracking mode checks")
