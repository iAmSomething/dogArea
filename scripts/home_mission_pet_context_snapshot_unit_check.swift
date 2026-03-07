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

let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let areaProgress = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift")
let indoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let service = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPetContextSnapshotService.swift")
let doc = load("docs/home-mission-pet-context-snapshot-v1.md")
let readme = load("README.md")

assertTrue(homeViewModel.contains("let indoorMissionPetContextSnapshotService: HomeIndoorMissionPetContextSnapshotServicing"), "home view model should inject the pet context snapshot service")
assertTrue(homeViewModel.contains("var indoorMissionPetContextPolygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint? = nil"), "home view model should store the polygon fingerprint cache state")
assertTrue(homeViewModel.contains("var indoorMissionPetContextAggregationSnapshot: HomeIndoorMissionPetContextAggregationSnapshot? = nil"), "home view model should store the pet context aggregation snapshot")
assertTrue(homeViewModel.contains("indoorMissionPetContextSnapshotService: HomeIndoorMissionPetContextSnapshotServicing = HomeIndoorMissionPetContextSnapshotService()"), "home view model init should default the pet context snapshot service")

assertTrue(areaProgress.contains("updateIndoorMissionPetContextPolygonFingerprint(for: polygonList)"), "area progress should update the mission pet context fingerprint when polygonList changes")
assertTrue(areaProgress.contains("indoorMissionPetContextAggregationSnapshot = nil"), "fingerprint changes should invalidate the cached snapshot")

assertTrue(indoorMissionFlow.contains("indoorMissionPetContextSnapshotService.canReuseSnapshot("), "indoor mission flow should reuse snapshot only when inputs still match")
assertTrue(indoorMissionFlow.contains("makeAggregationSnapshot("), "indoor mission flow should rebuild the aggregation snapshot on cache miss")
assertTrue(indoorMissionFlow.contains("normalizedIndoorMissionPetContextPetId()"), "indoor mission flow should normalize selected pet id input")
assertTrue(indoorMissionFlow.contains("return makeIndoorMissionPetContext(\n                from: indoorMissionPetContextAggregationSnapshot,\n                selectedPetId: selectedPetId\n            )") || indoorMissionFlow.contains("return makeIndoorMissionPetContext(from: snapshot, selectedPetId: selectedPetId)"), "indoor mission flow should compose the final context from the cached snapshot")

assertTrue(service.contains("protocol HomeIndoorMissionPetContextSnapshotServicing"), "service file should define a protocol-first pet context snapshot contract")
assertTrue(service.contains("struct HomeIndoorMissionPetContextPolygonFingerprint: Equatable"), "service file should define the polygon fingerprint model")
assertTrue(service.contains("struct HomeIndoorMissionPetContextAggregationSnapshot: Equatable"), "service file should define the aggregation snapshot model")
assertTrue(service.contains("makePolygonFingerprint(from polygons: [Polygon])"), "service file should expose polygon fingerprint generation")
assertTrue(service.contains("canReuseSnapshot("), "service file should expose snapshot reuse validation")
assertTrue(service.contains("makeAggregationSnapshot("), "service file should expose snapshot building")
assertTrue(service.contains("createdAt + fourteenDayWindow"), "service file should compute the 14-day invalidation boundary")
assertTrue(service.contains("createdAt + twentyEightDayWindow"), "service file should compute the 28-day invalidation boundary")
assertTrue(service.contains("SHA256.hash"), "service file should use a stable digest for polygon fingerprinting")

[
    "명시적 입력",
    "polygonList",
    "selectedPetId",
    "reference",
    "validThrough",
    "reference == validThrough",
    "filter` 2회 + `reduce` 1회",
    "`canReuseSnapshot` O(1)"
].forEach { needle in
    assertTrue(doc.contains(needle), "doc should describe \(needle)")
}

assertTrue(readme.contains("docs/home-mission-pet-context-snapshot-v1.md"), "README should index the home mission pet context snapshot doc")

print("PASS: home mission pet context snapshot unit checks")
