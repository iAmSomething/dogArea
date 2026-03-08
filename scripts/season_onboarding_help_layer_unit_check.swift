import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let model = load("dogArea/Source/Domain/Season/Models/SeasonGuidePresentation.swift")
let service = load("dogArea/Source/Domain/Season/Services/SeasonGuidePresentationService.swift")
let store = load("dogArea/Source/UserDefaultsSupport/SeasonGuideStateStore.swift")
let guideSheet = load("dogArea/Views/GlobalViews/SeasonGuide/SeasonGuideSheetView.swift")
let mapSummaryCard = load("dogArea/Views/MapView/MapSubViews/MapSeasonTileSummaryCardView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let homeSeasonCard = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let uiTest = load("dogAreaUITests/FeatureRegressionUITests.swift")
let doc = load("docs/map-season-onboarding-help-layer-v1.md")
let readme = load("README.md")
let stage3Doc = load("docs/season-stage3-ui-integration-v1.md")
let iosCheck = load("scripts/ios_pr_check.sh")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(model.contains("enum SeasonGuideEntryContext"), "Season guide entry context model should exist")
assertTrue(model.contains("struct SeasonGuidePresentation"), "Season guide presentation model should exist")
assertTrue(service.contains("protocol SeasonGuidePresentationProviding"), "Season guide presentation protocol should exist")
assertTrue(service.contains("case .firstSeasonVisit"), "Season guide service should support the first-visit context")
assertTrue(service.contains("같은 자리만 짧은 시간 안에 반복하면"), "Season guide service should explain repeated-path score reduction")
assertTrue(store.contains("season.guide.initial.presented.v1"), "Season guide store should persist the first-presented flag")
assertTrue(guideSheet.contains("season.guide.sheet"), "Season guide sheet should expose a root accessibility identifier")
assertTrue(guideSheet.contains("season.guide.concept.tile"), "Season guide sheet should expose the tile concept card identifier")
assertTrue(guideSheet.contains("season.guide.rule.repeatWalk"), "Season guide sheet should expose the repeat-walk rule identifier")
assertTrue(mapSummaryCard.contains("map.season.summary.openGuide"), "Map season summary card should expose a season guide entry button")
assertTrue(homeSeasonCard.contains("home.season.guide"), "Home season card should expose a season guide entry button")
assertTrue(mapView.contains("SeasonGuideSheetView"), "MapView should present the shared season guide sheet")
assertTrue(mapViewModel.contains("func presentSeasonGuideFromMapHelp()"), "MapViewModel should expose a manual season guide presenter")
assertTrue(mapViewModel.contains("shouldAutoPresentSeasonGuideForUITest"), "MapViewModel should support explicit UI-test auto presentation")
assertTrue(homeView.contains("openSeasonGuideFromHomeCard"), "HomeView should wire the home season guide entry action")
assertTrue(uiTest.contains("testFeatureRegression_MapSeasonGuideAutoPresentsOnFirstVisit"), "UI tests should cover first season guide auto presentation")
assertTrue(uiTest.contains("testFeatureRegression_HomeSeasonGuideEntryReopensGuideSheet"), "UI tests should cover home guide re-entry")
assertTrue(doc.contains("최초 설명 위치는 `지도 시즌 요약`으로 고정"), "Doc should state the first-entry policy")
assertTrue(doc.contains("season.guide.initial.presented.v1"), "Doc should record the persisted first-entry flag")
assertTrue(readme.contains("docs/map-season-onboarding-help-layer-v1.md"), "README should index the season onboarding doc")
assertTrue(stage3Doc.contains("시즌이 뭔가요?"), "Season stage3 doc should mention the season guide re-entry CTA")
assertTrue(iosCheck.contains("swift scripts/season_onboarding_help_layer_unit_check.swift"), "ios_pr_check should run the season onboarding guide check")
assertTrue(project.contains("SeasonGuideSheetView.swift"), "Xcode project should include the season guide sheet view")

print("PASS: season onboarding help layer checks")
