import Foundation

struct Check {
    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() == false {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}

func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("FAIL: unable to read \(path)\n", stderr)
        exit(1)
    }
    return text
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let root = FileManager.default.currentDirectoryPath
let homeViewModel = loadMany([
    root + "/dogArea/Views/HomeView/HomeViewModel.swift",
    root + "/dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    root + "/dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    root + "/dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let homeView = load(root + "/dogArea/Views/HomeView/HomeView.swift")
let timeCheckable = load(root + "/dogArea/Source/TimeCheckable.swift")
let spec = load(root + "/docs/session-boundary-aggregation-v1.md")
let checklist = load(root + "/docs/release-regression-checklist-v1.md")

Check.assertTrue(homeViewModel.contains("DayBoundarySplitContribution"), "home view model should define boundary contribution DTO")
Check.assertTrue(homeViewModel.contains("boundarySplitContribution"), "home view model should expose boundary split state")
Check.assertTrue(homeViewModel.contains("NSSystemTimeZoneDidChange"), "home view model should observe timezone change notification")
Check.assertTrue(homeViewModel.contains("NSCalendarDayChanged"), "home view model should observe day boundary notification")
Check.assertTrue(homeViewModel.contains("weightedAreaContribution"), "home view model should split area contribution by overlap")
Check.assertTrue(homeViewModel.contains("walkedAreaforWeek(reference:"), "weekly area should use boundary-aware method")
Check.assertTrue(homeViewModel.contains("sessionOverlaps("), "weekly count should use overlap logic")
Check.assertTrue(timeCheckable.contains("roundedDate >= startOfWeek && roundedDate < endOfWeek"), "time checkable week filter should clamp to week interval")

Check.assertTrue(homeView.contains("dayBoundarySplitCard"), "home view should render boundary split card")
Check.assertTrue(homeView.contains("aggregationStatusMessage"), "home view should expose timezone aggregation notice")

Check.assertTrue(spec.contains("overlapSeconds / sessionDuration"), "spec should define proportional split formula")
Check.assertTrue(checklist.contains("자정 걸침 세션(예: 23:50~00:20)"), "release checklist should include midnight split regression scenario")

print("PASS: timezone boundary aggregation unit checks")
