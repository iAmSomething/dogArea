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

let mainFile = load("dogArea/Views/HomeView/HomeViewModel.swift")
let sessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let areaProgress = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift")
let indoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let presentationModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let areaModels = load("dogArea/Source/Domain/Home/Models/AreaReferenceModels.swift")
let aggregationService = load("dogArea/Source/Domain/Home/Services/HomeAreaAggregationService.swift")

assertTrue(!mainFile.contains("enum QuestMotionEventType"), "HomeViewModel should no longer inline quest motion presentation types")
assertTrue(!mainFile.contains("struct WeatherMissionStatusSummary"), "HomeViewModel should no longer inline weather presentation summary types")
assertTrue(mainFile.contains("let areaAggregationService: HomeAreaAggregationServicing"), "HomeViewModel should inject area aggregation service")
assertTrue(!mainFile.contains("func fetchData("), "HomeViewModel main file should not own session lifecycle functions")
assertTrue(!mainFile.contains("func applySelectedPetStatistics"), "HomeViewModel main file should not own aggregation functions")
assertTrue(!mainFile.contains("func refreshIndoorMissions"), "HomeViewModel main file should not own indoor mission flow functions")

assertTrue(sessionLifecycle.contains("func fetchData(now: Date = Date())"), "session lifecycle support should own fetchData")
assertTrue(sessionLifecycle.contains("func refreshAreaReferenceCatalogs()"), "session lifecycle support should own area reference refresh")
assertTrue(sessionLifecycle.contains("func bindSelectedPetSync()"), "session lifecycle support should own selected pet sync binding")

assertTrue(areaProgress.contains("areaAggregationService.filteredPolygons"), "area progress support should delegate polygon filtering to area aggregation service")
assertTrue(areaProgress.contains("areaAggregationService.combinedAreas"), "area progress support should delegate combined area assembly")
assertTrue(areaProgress.contains("areaAggregationService.shouldPersistCurrentMeter"), "area progress support should delegate meter persistence decision")
assertTrue(areaProgress.contains("func evaluateAreaMilestones"), "area progress support should own milestone evaluation")

assertTrue(indoorMissionFlow.contains("func refreshIndoorMissions"), "indoor mission support should own mission refresh")
assertTrue(indoorMissionFlow.contains("func finalizeIndoorMission"), "indoor mission support should own mission completion flow")
assertTrue(indoorMissionFlow.contains("func refreshSeasonMotion"), "indoor mission support should own season motion refresh")

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
