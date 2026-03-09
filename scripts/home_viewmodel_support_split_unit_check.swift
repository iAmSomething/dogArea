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

let mainFilePath = root.appendingPathComponent("dogArea/Views/HomeView/HomeViewModel.swift")
let mainFile = load("dogArea/Views/HomeView/HomeViewModel.swift")
let sessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let areaProgress = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift")
let indoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let mainLineCount = mainFile.components(separatedBy: .newlines).count

assertTrue(mainLineCount <= 220, "HomeViewModel main file should stay slim after support split")
assertTrue(mainFile.contains("final class HomeViewModel"), "HomeViewModel main file should still define the type")
assertTrue(mainFile.contains("let areaReferenceRepository: AreaReferenceRepository"), "HomeViewModel main file should keep dependency declarations")
assertTrue(mainFile.contains("deinit {"), "HomeViewModel main file should keep lifecycle cleanup")

assertTrue(sessionLifecycle.contains("extension HomeViewModel"), "session lifecycle support should extend HomeViewModel")
assertTrue(sessionLifecycle.contains("func syncQuestReminderOnLaunch(now: Date = Date()) async"), "session lifecycle support should own quest reminder launch sync")
assertTrue(areaProgress.contains("func combinedAreas() -> [AreaMeter]"), "area progress support should own combined area helpers")
assertTrue(areaProgress.contains("func makeDayBoundarySplitContribution(reference: Date) -> DayBoundarySplitContribution?"), "area progress support should own boundary contribution logic")
assertTrue(indoorMissionFlow.contains("func makeIndoorMissionPetContext(reference: Date) -> IndoorMissionPetContext"), "indoor mission support should own pet mission context")
assertTrue(indoorMissionFlow.contains("func syncSeasonScoreWithWalkSessions(now: Date)"), "indoor mission support should own season score sync")
assertTrue(FileManager.default.fileExists(atPath: mainFilePath.path), "HomeViewModel main file should exist")

print("PASS: home viewmodel support split unit checks")
