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
let homeStateModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let weatherPresentationService = load("dogArea/Source/Domain/Home/Services/HomeWeatherSnapshotPresentationService.swift")
let weatherCardView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherSnapshotCardView.swift")
let weatherMetricView = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherSnapshotMetricTileView.swift")
let homeIndoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let featureRegressionUITests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")

assertTrue(
    homeViewModel.contains("@Published var weatherDetailPresentation"),
    "HomeViewModel should publish a dedicated weather detail presentation state"
)
assertTrue(
    homeStateModels.contains("struct HomeWeatherSnapshotCardPresentation"),
    "Home presentation state models should define a dedicated weather detail card presentation"
)
assertTrue(
    weatherPresentationService.contains("protocol HomeWeatherSnapshotPresenting"),
    "Home weather snapshot presentation should be extracted behind a protocol"
)
assertTrue(
    homeView.contains("weatherDetailCard(presentation: viewModel.weatherDetailPresentation)"),
    "HomeView should render the dedicated weather detail card"
)
assertTrue(
    weatherCardView.contains("home.weather.snapshot"),
    "Home weather detail card should expose a stable accessibility identifier"
)
assertTrue(
    weatherMetricView.contains("home.weather.metric."),
    "Weather metric tiles should expose stable accessibility identifiers"
)
assertTrue(
    homeIndoorMissionFlow.contains("makeIndoorMissionUITestWeatherSnapshot"),
    "Home indoor mission flow should provide a deterministic weather snapshot UI test stub"
)
assertTrue(
    featureRegressionUITests.contains("testFeatureRegression_HomeWeatherDetailCardShowsRawSnapshotMetrics"),
    "FeatureRegressionUITests should cover the home weather detail card"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_HomeWeatherDetailCardShowsRawSnapshotMetrics"),
    "Feature regression runner should execute the home weather detail card UI test"
)

print("PASS: home weather detail card unit checks")
