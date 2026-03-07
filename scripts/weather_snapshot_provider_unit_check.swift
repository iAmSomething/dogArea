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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let snapshotModel = load("dogArea/Source/Domain/Weather/Models/WeatherSnapshot.swift")
let provider = load("dogArea/Source/Domain/Weather/Services/OpenMeteoWeatherSnapshotProvider.swift")
let store = load("dogArea/Source/Domain/Weather/Stores/WeatherSnapshotStore.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let indoorMissionStore = load("dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift")
let homeMissionModels = load("dogArea/Source/Domain/Home/Models/HomeMissionModels.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let doc = load("docs/weather-snapshot-provider-v1.md")
let readme = load("README.md")

[
    "let temperatureC: Double",
    "let apparentTemperatureC: Double",
    "let relativeHumidityPercent: Double",
    "let isPrecipitating: Bool",
    "let precipitationMMPerHour: Double",
    "let windMps: Double",
    "let pm2_5: Double?",
    "let pm10: Double?",
    "enum WeatherSnapshotDataSource"
].forEach { needle in
    assertTrue(snapshotModel.contains(needle), "weather snapshot model should contain \(needle)")
}

assertTrue(provider.contains("https://api.open-meteo.com/v1/forecast"), "provider should use forecast endpoint")
assertTrue(provider.contains("temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m"), "provider should request detailed current weather fields")
assertTrue(provider.contains("https://air-quality-api.open-meteo.com/v1/air-quality"), "provider should use air quality endpoint")
assertTrue(provider.contains("current: \"pm10,pm2_5\"") || provider.contains("value: \"pm10,pm2_5\""), "provider should request PM fields")
assertTrue(store.contains("weather.snapshot.latest.v1"), "weather snapshot store should persist shared snapshot")
assertTrue(homeViewModel.contains("@Published var latestWeatherSnapshot: WeatherSnapshot? = nil"), "home view model should expose latest weather snapshot")
assertTrue(homeViewModel.contains("let weatherSnapshotStore: WeatherSnapshotStoreProtocol"), "home view model should receive weather snapshot store")
assertTrue(homeLifecycle.contains("refreshWeatherSnapshot()"), "home lifecycle should refresh weather snapshot state")
assertTrue(indoorMissionStore.contains("weatherSnapshotStore.loadSnapshot()"), "indoor mission store should consult shared weather snapshot")
assertTrue(homeMissionModels.contains("case snapshot"), "indoor weather source should represent shared snapshot source")
assertTrue(mapViewModel.contains("weatherSnapshotStore.save(snapshot)"), "map view model should persist shared weather snapshot")

assertTrue(doc.contains("`pm2_5`, `pm10`은 optional 필드"), "weather snapshot doc should define PM optional policy")
assertTrue(doc.contains("core weather 필드가 누락되면 provider 요청은 실패"), "weather snapshot doc should define core field failure policy")
assertTrue(doc.contains("`2h`를 초과하면 `clear`로 강등하지 않고 최소 `caution`"), "weather snapshot doc should define stale conservative fallback policy")

assertTrue(readme.contains("docs/weather-snapshot-provider-v1.md"), "README should index weather snapshot provider doc")

print("PASS: weather snapshot provider unit checks")
