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

assertTrue(
    homeView.contains("HomeMissionSectionView(") &&
    homeView.contains("weatherMissionStatusSummary: viewModel.weatherMissionStatusSummary"),
    "home daily mission section should render weather mission status card"
)
assertTrue(
    homeView.contains("weatherShieldDailySummary: viewModel.weatherShieldDailySummary"),
    "home daily mission section should render weather shield summary card when available"
)

print("PASS: home weather status card restore unit checks")
