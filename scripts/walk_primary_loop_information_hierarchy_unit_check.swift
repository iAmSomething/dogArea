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

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeCard = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWalkPrimaryLoopCardView.swift")
let homeService = load("dogArea/Source/Domain/Home/Services/HomeWalkPrimaryLoopPresentationService.swift")
let missionService = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPresentationService.swift")
let missionStatusBuilder = load("dogArea/Source/Domain/Home/Services/HomeWeatherMissionStatusBuilder.swift")
let startButtonView = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let mapMeaningCard = load("dogArea/Views/MapView/MapSubViews/MapWalkStartMeaningCardView.swift")
let mapMeaningService = load("dogArea/Source/Domain/Map/Services/MapWalkStartPresentationService.swift")
let walkListHeader = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let walkListService = load("dogArea/Views/WalkListView/WalkListPresentationService.swift")
let walkListPrimaryLoopCard = load("dogArea/Views/WalkListView/WalkListSubView/WalkListPrimaryLoopSummaryCardView.swift")
let walkListDetailHero = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailHeroSectionView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walk-primary-loop-information-hierarchy-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(homeView.contains("homeWalkPrimaryLoopSection"), "home should render a dedicated walk primary loop section")
assertTrue(homeCard.contains("home.walkPrimaryLoop.card"), "home walk primary loop card should expose an accessibility identifier")
assertTrue(homeService.contains("protocol HomeWalkPrimaryLoopPresenting"), "home walk primary loop should be protocol-first")
assertTrue(missionService.contains("실내 미션은 악천후나 예외 상황에서만 보조로 열립니다"), "indoor mission copy should explicitly position itself as secondary")
assertTrue(missionStatusBuilder.contains("실내 미션 전환 요약"), "weather mission summary should be reframed as indoor mission shift summary")
assertTrue(startButtonView.contains("MapWalkStartMeaningCardView"), "map start CTA should be preceded by a meaning card")
assertTrue(mapMeaningCard.contains("map.walk.startMeaning.card"), "map meaning card should expose an accessibility identifier")
assertTrue(mapMeaningService.contains("protocol MapWalkStartPresenting"), "map walk start meaning should be protocol-first")
assertTrue(walkListHeader.contains("WalkListPrimaryLoopSummaryCardView"), "walk list header should render a primary loop summary card")
assertTrue(walkListService.contains("primaryLoopTitle"), "walk list presentation service should define primary loop messaging")
assertTrue(walkListPrimaryLoopCard.contains("walklist.primaryLoop.card"), "walk list primary loop card should expose an accessibility identifier")
assertTrue(walkListDetailHero.contains("walklist.detail.loopSummary"), "walk list detail hero should surface walk value summary")
assertTrue(featureTests.contains("testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop"), "feature regression tests should cover home and map primary loop hierarchy")
assertTrue(featureScript.contains("testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop"), "feature regression script should run the home/map primary loop regression")
assertTrue(uiMatrix.contains("FR-HOME-002"), "ui regression matrix should include the home/map primary loop regression")
assertTrue(doc.contains("산책이 이 앱의 시작점"), "issue doc should record the home primary loop surface")
assertTrue(readme.contains("docs/walk-primary-loop-information-hierarchy-v1.md"), "README should index the walk primary loop hierarchy doc")
assertTrue(prCheck.contains("swift scripts/walk_primary_loop_information_hierarchy_unit_check.swift"), "ios_pr_check should include the primary loop hierarchy unit check")

print("PASS: walk primary loop information hierarchy checks")
