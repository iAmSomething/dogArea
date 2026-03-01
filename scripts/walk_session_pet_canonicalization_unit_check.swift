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

let walkRepository = load("dogArea/Source/Data/Walk/WalkRepository.swift")
let walkBackfill = load("dogArea/Source/Data/Walk/WalkBackfillDTO.swift")
let mapModel = load("dogArea/Views/MapView/MapModel.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let walkListModel = load("dogArea/Views/WalkListView/WalkListModel.swift")
let walkListViewModel = load("dogArea/Views/WalkListView/WalkListViewModel.swift")

assertTrue(walkRepository.contains("petId: normalizedPetUUIDString(polygon.petId)"), "repository should persist canonical petId")
assertTrue(walkRepository.contains("backfillPetIdsIfNeeded"), "repository should backfill missing canonical petId from metadata")
assertTrue(walkBackfill.contains("normalizedUUIDString(petId) ?? normalizedUUIDString(polygon.petId)"), "backfill converter should use canonical polygon petId")
assertTrue(walkBackfill.contains("normalizedUUIDStringOrNil(_ raw: String?)"), "canonical petId normalizer should exist")

assertTrue(mapModel.contains("var petId: String?"), "polygon model should carry petId")
assertTrue(mapViewModel.contains("self.polygon.petId = selectedPetId"), "walk end should pin current selected petId on polygon")
assertTrue(mapViewModel.contains("polygon.petId = selectedPetId"), "walk start should set canonical petId for new session")
assertTrue(mapViewModel.contains("petId: polygon.petId"), "outbox should sync petId from canonical polygon field")

assertTrue(homeViewModel.contains("$0.petId == selectedPetId"), "home should filter by canonical polygon petId")
assertTrue(walkListModel.contains("let petId: String?"), "walk list model should expose canonical petId")
assertTrue(walkListViewModel.contains("$0.petId == selectedPetId"), "walk list should filter by canonical walk data petId")

print("PASS: walk session pet canonicalization unit checks")
