import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/territory-widget-goal-deeplink-v1.md")
let bridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeStateModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let territoryGoalView = load("dogArea/Views/HomeView/HomeSubView/TerritoryGoalView.swift")
let territoryGoalViewModel = load("dogArea/Views/HomeView/HomeSubView/TerritoryGoalViewModel.swift")
let widget = load("dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let featureRegressionUITests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

for requiredToken in [
    "TerritoryGoalView",
    "`memberReady`",
    "`offlineCached`",
    "`syncDelayed`",
    "`emptyData`",
    "`guestLocked`",
    "AreaDetailView",
    "dogarea://widget/territory"
] {
    assertTrue(doc.contains(requiredToken), "doc should include \(requiredToken)")
}

assertTrue(bridge.contains("territoryDeepLinkPath"), "widget bridge should define territory deep link path")
assertTrue(bridge.contains("enum TerritoryWidgetDeepLinkDestination"), "widget bridge should define territory destination enum")
assertTrue(bridge.contains("struct TerritoryWidgetDeepLinkRoute"), "widget bridge should define territory route struct")
assertTrue(bridge.contains("territory_status"), "widget bridge should encode territory status query")

assertTrue(widget.contains(".widgetURL(territoryWidgetURL)"), "territory widget should register widgetURL")
assertTrue(widget.contains("TerritoryWidgetDeepLinkRoute("), "territory widget should build territory deep link route")
assertTrue(widget.contains("destination: .goalDetail"), "territory widget should open goal detail by default")

assertTrue(rootView.contains("pendingHomeRoute"), "RootView should keep pending home route state")
assertTrue(rootView.contains("deferredTerritoryWidgetRoute"), "RootView should defer territory route through auth overlay")
assertTrue(rootView.contains("initialUITestTerritoryWidgetRoute"), "RootView should expose UITest territory route parser")
assertTrue(rootView.contains("dispatchTerritoryWidgetRoute"), "RootView should dispatch territory widget routes")
assertTrue(rootView.contains("dispatchDeferredTerritoryWidgetRouteIfNeeded"), "RootView should retry deferred territory route after auth")
assertTrue(rootView.contains("HomeView(externalRoute: $pendingHomeRoute)"), "RootView should inject home external route binding")

assertTrue(homeStateModels.contains("struct HomeExternalRoute"), "home state models should define external route")
assertTrue(homeStateModels.contains("struct TerritoryGoalEntryContext"), "home state models should define territory entry context")
assertTrue(homeStateModels.contains("enum TerritoryGoalEntrySource"), "home state models should define entry source")

assertTrue(homeView.contains("@Binding private var externalRoute"), "HomeView should receive external route binding")
assertTrue(homeView.contains("consumeExternalRouteIfNeeded"), "HomeView should consume external route")
assertTrue(homeView.contains("TerritoryGoalViewModel("), "HomeView should build TerritoryGoalViewModel for destination")
assertTrue(homeView.contains("territoryGoalEntryContext"), "HomeView should preserve territory widget entry context")

assertTrue(territoryGoalView.contains("HomeStatusBannerView"), "TerritoryGoalView should render widget entry banner")
assertTrue(territoryGoalViewModel.contains("entryContext"), "TerritoryGoalViewModel should accept entry context")
assertTrue(territoryGoalViewModel.contains("entryBannerMessage"), "TerritoryGoalViewModel should expose entry banner message")

assertTrue(featureRegressionUITests.contains("testFeatureRegression_TerritoryWidgetRouteOpensGoalDetail"), "UI regression test should cover territory widget route")
assertTrue(readme.contains("territory-widget-goal-deeplink-v1.md"), "README should index the territory widget deeplink doc")
assertTrue(iosPRCheck.contains("territory_widget_goal_deeplink_unit_check.swift"), "ios_pr_check should run territory widget deeplink check")

print("PASS: territory widget goal deeplink unit checks")
