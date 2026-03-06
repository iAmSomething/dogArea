import Foundation

enum Check {
    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() == false {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func readMany(_ relativePaths: [String]) -> String {
    relativePaths.map(read).joined(separator: "\n")
}

let backfill = read("dogArea/Source/Data/Walk/WalkBackfillDTO.swift")
let mapViewModel = read("dogArea/Views/MapView/MapViewModel.swift")
let userDefault = readMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])

Check.assertTrue(backfill.contains("struct WalkSessionBackfillDTO"), "backfill session DTO should exist")
Check.assertTrue(backfill.contains("struct WalkPointBackfillDTO"), "backfill point DTO should exist")
Check.assertTrue(backfill.contains("enum WalkBackfillDTOConverter"), "walk converter should exist")
Check.assertTrue(backfill.contains("pointsJSONString"), "converter output must encode points JSON")
Check.assertTrue(mapViewModel.contains("WalkBackfillDTOConverter.makeSessionDTO"), "map flow should keep DTO converter usage")
Check.assertTrue(userDefault.contains("WalkBackfillDTOConverter.makeSessionDTO"), "guest upgrade should keep DTO converter usage")

print("All walk-repository backfill checks passed.")
