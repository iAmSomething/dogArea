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

let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let presentationModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let areaModels = load("dogArea/Source/Domain/Home/Models/AreaReferenceModels.swift")
let aggregationService = load("dogArea/Source/Domain/Home/Services/HomeAreaAggregationService.swift")

assertTrue(!homeViewModel.contains("enum QuestMotionEventType"), "HomeViewModel should no longer inline quest motion presentation types")
assertTrue(!homeViewModel.contains("struct WeatherMissionStatusSummary"), "HomeViewModel should no longer inline weather presentation summary types")
assertTrue(homeViewModel.contains("private let areaAggregationService: HomeAreaAggregationServicing"), "HomeViewModel should inject area aggregation service")
assertTrue(homeViewModel.contains("areaAggregationService.filteredPolygons"), "HomeViewModel should delegate polygon filtering to area aggregation service")
assertTrue(homeViewModel.contains("areaAggregationService.combinedAreas"), "HomeViewModel should delegate combined area assembly")
assertTrue(homeViewModel.contains("areaAggregationService.shouldPersistCurrentMeter"), "HomeViewModel should delegate meter persistence decision")

assertTrue(presentationModels.contains("enum QuestMotionEventType"), "presentation support file should define quest motion event type")
assertTrue(presentationModels.contains("struct SeasonMotionSummary"), "presentation support file should define season motion summary")
assertTrue(presentationModels.contains("struct WeatherMissionStatusSummary"), "presentation support file should define weather mission summary")

assertTrue(areaModels.contains("struct AreaMeter"), "domain area models file should define AreaMeter")
assertTrue(areaModels.contains("protocol AreaReferenceRepository"), "domain area models file should define repository contract")
assertTrue(!FileManager.default.fileExists(atPath: root.appendingPathComponent("dogArea/Views/HomeView/AreaMeters.swift").path), "legacy AreaMeters view file should be removed")

assertTrue(aggregationService.contains("protocol HomeAreaAggregationServicing"), "aggregation service should expose protocol contract")
assertTrue(aggregationService.contains("struct HomeAreaAggregationService"), "aggregation service should define default implementation")
assertTrue(aggregationService.contains("func milestoneCandidates"), "aggregation service should own milestone candidate calculation")

print("PASS: home viewmodel state aggregation split unit checks")
