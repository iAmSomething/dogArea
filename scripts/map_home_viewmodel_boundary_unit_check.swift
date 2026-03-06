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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

func extractTypeBody(source: String, declarationPrefix: String) -> String? {
    guard let declarationRange = source.range(of: declarationPrefix) else { return nil }
    guard let openBrace = source[declarationRange.lowerBound...].firstIndex(of: "{") else { return nil }

    var depth = 0
    var index = openBrace
    while index < source.endIndex {
        let ch = source[index]
        if ch == "{" {
            depth += 1
        } else if ch == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openBrace...index])
            }
        }
        index = source.index(after: index)
    }
    return nil
}

let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let homeViewModel = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])

let mapBody = extractTypeBody(source: mapViewModel, declarationPrefix: "class MapViewModel")
let homeBody = extractTypeBody(source: homeViewModel, declarationPrefix: "final class HomeViewModel")

assertTrue(mapBody != nil, "MapViewModel class body should be detectable")
assertTrue(homeBody != nil, "HomeViewModel class body should be detectable")

if let mapBody {
    assertTrue(!mapBody.contains("UserDefaults.standard"), "MapViewModel should not access UserDefaults.standard directly")
    assertTrue(!mapBody.contains("NotificationCenter.default"), "MapViewModel should not access NotificationCenter.default directly")
    assertTrue(!mapBody.contains("UserdefaultSetting.shared"), "MapViewModel should not access UserdefaultSetting.shared directly")
}

if let homeBody {
    assertTrue(!homeBody.contains("UserDefaults.standard"), "HomeViewModel should not access UserDefaults.standard directly")
    assertTrue(!homeBody.contains("NotificationCenter.default"), "HomeViewModel should not access NotificationCenter.default directly")
    assertTrue(!homeBody.contains("UserdefaultSetting.shared"), "HomeViewModel should not access UserdefaultSetting.shared directly")
}

assertTrue(mapViewModel.contains("MapPreferenceStoreProtocol"), "MapViewModel should depend on MapPreferenceStoreProtocol")
assertTrue(mapViewModel.contains("UserSessionStoreProtocol"), "MapViewModel should depend on UserSessionStoreProtocol")
assertTrue(mapViewModel.contains("AppEventCenterProtocol"), "MapViewModel should depend on AppEventCenterProtocol")

assertTrue(homeViewModel.contains("UserSessionStoreProtocol"), "HomeViewModel should depend on UserSessionStoreProtocol")
assertTrue(homeViewModel.contains("AppEventCenterProtocol"), "HomeViewModel should depend on AppEventCenterProtocol")

print("PASS: map/home viewmodel boundary unit checks")
