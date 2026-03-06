import Foundation

enum Risk: Int {
    case clear = 0
    case caution = 1
    case bad = 2
    case severe = 3
}

struct ProviderResult {
    let precipitationMMPerHour: Double
    let temperatureC: Double
    let windMps: Double
}

struct RiskEngine {
    func score(_ data: ProviderResult) -> Risk {
        let precip = riskForPrecip(data.precipitationMMPerHour)
        let temp = riskForTemperature(data.temperatureC)
        let wind = riskForWind(data.windMps)
        return [precip, temp, wind].max(by: { $0.rawValue < $1.rawValue }) ?? .clear
    }

    private func riskForPrecip(_ v: Double) -> Risk {
        if v >= 12 { return .severe }
        if v >= 6 { return .bad }
        if v >= 1 { return .caution }
        return .clear
    }

    private func riskForTemperature(_ v: Double) -> Risk {
        if v >= 33 || v <= -8 { return .severe }
        if v >= 30 || v <= -3 { return .bad }
        if v >= 28 || v <= 0 { return .caution }
        return .clear
    }

    private func riskForWind(_ v: Double) -> Risk {
        if v >= 14 { return .severe }
        if v >= 10 { return .bad }
        if v >= 6 { return .caution }
        return .clear
    }
}

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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/weather-risk-provider-policy-v1.md")
let homeVM = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let mapVM = load("dogArea/Views/MapView/MapViewModel.swift")
let report = load("docs/cycle-133-weather-risk-policy-report-2026-02-27.md")

assertTrue(doc.contains("Primary Provider"), "policy doc should define primary provider")
assertTrue(doc.contains("Secondary Provider"), "policy doc should define secondary provider")
assertTrue(doc.contains("cache TTL: `2h`"), "policy doc should define cache ttl")
assertTrue(doc.contains("데이터 갱신 주기: `1h`"), "policy doc should define refresh cadence")
assertTrue(doc.contains("geohash7"), "policy doc should define grid key policy")
assertTrue(doc.contains("Fallback"), "policy doc should define fallback behavior")

assertTrue(homeVM.contains("IndoorWeatherRiskLevel"), "home vm should expose weather risk levels")
assertTrue(homeVM.contains("fallback"), "home vm should include fallback source")
assertTrue(mapVM.contains("weatherOverlayFallbackActive"), "map vm should expose fallback badge state")
assertTrue(report.contains("#133"), "cycle report should reference issue #133")

let engine = RiskEngine()
assertTrue(engine.score(.init(precipitationMMPerHour: 0, temperatureC: 21, windMps: 1)) == .clear, "clear baseline should stay clear")
assertTrue(engine.score(.init(precipitationMMPerHour: 2, temperatureC: 21, windMps: 1)) == .caution, "light rain should be caution")
assertTrue(engine.score(.init(precipitationMMPerHour: 7, temperatureC: 21, windMps: 1)) == .bad, "heavy rain should be bad")
assertTrue(engine.score(.init(precipitationMMPerHour: 13, temperatureC: 21, windMps: 1)) == .severe, "extreme rain should be severe")
assertTrue(engine.score(.init(precipitationMMPerHour: 0, temperatureC: 34, windMps: 1)) == .severe, "extreme heat should be severe")
assertTrue(engine.score(.init(precipitationMMPerHour: 0, temperatureC: -4, windMps: 1)) == .bad, "cold wave should be bad")
assertTrue(engine.score(.init(precipitationMMPerHour: 0, temperatureC: 21, windMps: 11)) == .bad, "strong wind should be bad")

let deterministicInput = ProviderResult(precipitationMMPerHour: 6.2, temperatureC: 27, windMps: 5)
let first = engine.score(deterministicInput)
for _ in 0..<100 {
    assertTrue(engine.score(deterministicInput) == first, "same input should produce same risk")
}

print("PASS: weather risk policy stage1 unit checks")
