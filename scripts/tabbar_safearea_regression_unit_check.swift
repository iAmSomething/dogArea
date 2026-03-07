import Foundation

/// 조건이 거짓이면 표준 에러에 메시지를 출력하고 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 오류 메시지입니다.
/// - Returns: 없음. 실패 조건이면 프로세스를 종료합니다.
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

let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let scaffold = load("dogArea/Views/GlobalViews/BaseView/AppTabScaffold.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapTopChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let mapBottomControlOverlayView = load("dogArea/Views/MapView/MapSubViews/MapBottomControlOverlayView.swift")
let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let settingsView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let rivalView = load("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let territoryGoalView = load("dogArea/Views/HomeView/HomeSubView/TerritoryGoalView.swift")
let areaDetailView = load("dogArea/Views/HomeView/AreaDetailView.swift")
let walkListDetailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")

assertTrue(
    rootView.contains(".safeAreaInset(edge: .bottom, spacing: 0)"),
    "RootView should reserve bottom safe area for CustomTabBar"
)
assertTrue(
    rootView.contains("CustomTabBar(selectedTab: $selectedTab)"),
    "RootView should render CustomTabBar inside bottom safe area inset"
)
assertTrue(
    !rootView.contains("NavigationView"),
    "RootView should use NavigationStack-based tab roots instead of NavigationView"
)
assertTrue(
    rootView.contains("AppTabRootContainer"),
    "RootView should use the shared app tab root container"
)
assertTrue(
    scaffold.contains("func appTabBarContentPadding(extra: CGFloat = 0) -> some View"),
    "AppTabScaffold should expose shared bottom content padding"
)
assertTrue(
    scaffold.contains("func appTabBarVisibility(_ visibility: AppTabBarVisibility) -> some View"),
    "AppTabScaffold should expose declarative tab bar visibility"
)
assertTrue(
    scaffold.contains("func appTabRootScrollLayout("),
    "AppTabScaffold should expose shared tab root scroll layout"
)
assertTrue(
    scaffold.contains("func appTabFloatingOverlayPadding("),
    "AppTabScaffold should expose shared floating overlay padding"
)
assertTrue(
    scaffold.contains("static func topOverlaySpacing("),
    "AppTabLayoutMetrics should centralize top overlay spacing"
)
for (name, source) in [
    ("HomeView", homeView),
    ("MapView", mapView),
    ("WalkListView", walkListView),
    ("NotificationCenterView", settingsView),
    ("RivalTabView", rivalView)
] {
    assertTrue(
        !source.contains("CustomTabBar.reservedContentHeight"),
        "\(name) should not hard-code CustomTabBar reserved height"
    )
}
for (name, source) in [
    ("HomeView", homeView),
    ("WalkListView", walkListView),
    ("NotificationCenterView", settingsView),
    ("RivalTabView", rivalView)
] {
    assertTrue(
        source.contains(".appTabRootScrollLayout("),
        "\(name) should use shared app tab root scroll layout"
    )
}
assertTrue(
    mapView.contains("MapBottomControlOverlayView("),
    "MapView should compose bottom controls through the shared bottom overlay container"
)
assertTrue(
    mapBottomControlOverlayView.contains("@Environment(\\.appTabBarReservedHeight)"),
    "Map bottom control overlay should consume the shared reserved tab bar height"
)
assertTrue(
    mapBottomControlOverlayView.contains("AppTabLayoutMetrics.floatingOverlayLift"),
    "Map bottom control overlay should derive bottom spacing from shared floating overlay metrics"
)
assertTrue(
    mapBottomControlOverlayView.contains("AppTabLayoutMetrics.minimumBottomPadding"),
    "Map bottom control overlay should preserve shared minimum bottom padding"
)
assertTrue(
    mapBottomControlOverlayView.contains("MapChromeLayoutMetrics.horizontalPadding"),
    "Map bottom control overlay should align floating controls with shared chrome spacing"
)
assertTrue(
    mapBottomControlOverlayView.contains(".zIndex(3)"),
    "Map bottom control overlay should keep floating controls above the primary CTA and tray"
)
assertTrue(
    mapBottomControlOverlayView.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)"),
    "Map bottom control overlay should own the full bottom overlay frame"
)
assertTrue(
    !mapView.contains(".appTabFloatingOverlayPadding("),
    "MapView should no longer manage floating overlay padding inline after overlay extraction"
)
assertTrue(
    mapTopChromeView.contains("AppTabLayoutMetrics.topOverlaySpacing("),
    "MapTopChromeView should use shared top overlay spacing"
)
for (name, source) in [
    ("TerritoryGoalView", territoryGoalView),
    ("AreaDetailView", areaDetailView),
    ("WalkListDetailView", walkListDetailView)
] {
    assertTrue(
        source.contains(".appTabBarVisibility(.hidden)"),
        "\(name) should declaratively hide the tab bar"
    )
    assertTrue(
        !source.contains("TabAppear.shared"),
        "\(name) should not depend on TabAppear singleton state"
    )
}

print("PASS: tabbar safe area regression unit checks")
