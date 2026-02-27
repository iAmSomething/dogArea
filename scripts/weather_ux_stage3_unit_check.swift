import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let spec = load("docs/weather-ux-fallback-accessibility-v1.md")
let report = load("docs/cycle-135-weather-ux-fallback-report-2026-02-27.md")

assertTrue(homeViewModel.contains("weatherMissionStatusSummary"), "HomeViewModel should expose weather mission status summary")
assertTrue(homeViewModel.contains("weatherShieldDailySummary"), "HomeViewModel should expose daily shield summary")
assertTrue(homeViewModel.contains("weatherStatus(now:"), "IndoorMissionStore should expose weather status")
assertTrue(homeViewModel.contains("recordWeatherShieldUsage"), "IndoorMissionStore should record weather shield usage")
assertTrue(homeViewModel.contains("return (.clear, .fallback)"), "fallback should keep default clear risk")

assertTrue(homeView.contains("weatherMissionStatusCard(summary:"), "HomeView should render weather mission status card")
assertTrue(homeView.contains("weatherShieldSummaryCard(summary:"), "HomeView should render weather shield summary card")
assertTrue(homeView.contains("Fallback"), "HomeView should expose fallback badge text")

assertTrue(mapView.contains("weatherOverlayStatusText"), "MapView should display weather status text")
assertTrue(mapViewModel.contains("weatherOverlayFallbackActive"), "MapViewModel should track fallback state")
assertTrue(mapViewModel.contains("Fallback: 날씨 데이터 연결 불가"), "MapViewModel should define fallback status copy")

assertTrue(spec.contains("fallback"), "Weather UX spec should include fallback behavior")
assertTrue(spec.contains("접근성"), "Weather UX spec should include accessibility guidance")
assertTrue(spec.contains("기본 퀘스트"), "Weather UX spec should specify default quest behavior")
assertTrue(report.contains("#135"), "Cycle report should reference issue #135")

print("PASS: weather ux stage3 unit checks")
