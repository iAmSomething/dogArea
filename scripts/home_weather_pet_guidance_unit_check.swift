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
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeSessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let homeStateModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let guidanceModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeWeatherGuidancePresentationModels.swift")
let guidanceService = load("dogArea/Source/Domain/Home/Services/HomeWeatherWalkGuidanceService.swift")
let weatherCardView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherSnapshotCardView.swift")
let guidanceSheetView = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeWeatherGuidanceSheetView.swift")
let primaryActionCardView = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeWeatherGuidancePrimaryActionCardView.swift")
let decisionFactorsCardView = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeWeatherGuidanceDecisionFactorsCardView.swift")
let uiTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let uiScript = load("scripts/run_feature_regression_ui_tests.sh")
let readme = load("README.md")
let doc = load("docs/home-weather-pet-guidance-sheet-v1.md")

assertTrue(
    homeViewModel.contains("@Published var weatherGuidancePresentation"),
    "HomeViewModel should publish a weather guidance presentation state"
)
assertTrue(
    homeViewModel.contains("let weatherWalkGuidanceService: HomeWeatherWalkGuidancePresenting"),
    "HomeViewModel should inject weather guidance presentation service behind a protocol"
)
assertTrue(
    homeSessionLifecycle.contains("weatherGuidancePresentation = weatherWalkGuidanceService.makePresentation"),
    "Home session lifecycle should update the weather guidance presentation"
)
assertTrue(
    homeStateModels.contains("let detailActionTitle: String"),
    "Home weather snapshot card presentation should expose a detail action title"
)
assertTrue(
    guidanceModels.contains("struct HomeWeatherGuidancePresentation"),
    "Home weather guidance presentation models should exist"
)
assertTrue(
    guidanceModels.contains("struct HomeWeatherGuidancePrimaryActionPresentation"),
    "Home weather guidance models should include a primary action presentation"
)
assertTrue(
    guidanceModels.contains("struct HomeWeatherGuidanceDecisionFactorPresentation"),
    "Home weather guidance models should include decision factor chips"
)
assertTrue(
    guidanceService.contains("protocol HomeWeatherWalkGuidancePresenting"),
    "Home weather guidance logic should be extracted behind a protocol"
)
assertTrue(
    guidanceService.contains("makePrimaryAction("),
    "Guidance service should compute a primary action summary"
)
assertTrue(
    guidanceService.contains("makeDecisionFactors("),
    "Guidance service should compute decision factor chips"
)
assertTrue(
    guidanceService.contains("title: localizedCopy(\"오늘 산책 시 주의\""),
    "Guidance service should define the caution section"
)
assertTrue(
    guidanceService.contains("title: localizedCopy(\"산책 권장 방식\""),
    "Guidance service should define the walk style section"
)
assertTrue(
    guidanceService.contains("title: localizedCopy(\"실내 대체 추천\""),
    "Guidance service should define the indoor alternative section"
)
assertTrue(
    homeView.contains(".sheet(isPresented: $isWeatherGuidancePresented)"),
    "HomeView should present the weather guidance sheet"
)
assertTrue(
    weatherCardView.contains("home.weather.more"),
    "Weather card should expose a stable detail CTA accessibility identifier"
)
assertTrue(
    guidanceSheetView.contains("sheet.home.weatherGuidance"),
    "Guidance sheet should expose a stable root accessibility identifier"
)
assertTrue(
    guidanceSheetView.contains("primaryActionCard"),
    "Guidance sheet should render the primary action card"
)
assertTrue(
    guidanceSheetView.contains("decisionFactorsCard"),
    "Guidance sheet should render the decision factors card"
)
assertTrue(
    primaryActionCardView.contains("home.weather.guidance.primaryAction"),
    "Primary action card should expose a stable accessibility identifier"
)
assertTrue(
    decisionFactorsCardView.contains("home.weather.guidance.decisionFactors"),
    "Decision factors card should expose a stable accessibility identifier"
)
assertTrue(
    guidanceSheetView.contains("home.weather.guidance.section.\\(section.id)"),
    "Guidance sheet should expose stable section identifiers"
)
assertTrue(
    uiTests.contains("testFeatureRegression_HomeWeatherGuidanceSheetShowsActionableFallbackAndSections"),
    "Feature regression UI tests should cover the weather guidance sheet"
)
assertTrue(
    uiScript.contains("testFeatureRegression_HomeWeatherGuidanceSheetShowsActionableFallbackAndSections"),
    "Feature regression runner should execute the weather guidance sheet UI test"
)
assertTrue(
    doc.contains("오늘 산책 시 주의") && doc.contains("산책 권장 방식") && doc.contains("실내 대체 추천"),
    "Guidance doc should describe the three action-oriented sections"
)
assertTrue(
    doc.contains("오늘 추천") && doc.contains("이렇게 판단했어요"),
    "Guidance doc should describe the primary action and decision factors blocks"
)
assertTrue(
    readme.contains("docs/home-weather-pet-guidance-sheet-v1.md"),
    "README should index the weather guidance sheet document"
)

print("PASS: home weather pet guidance sheet unit checks")
