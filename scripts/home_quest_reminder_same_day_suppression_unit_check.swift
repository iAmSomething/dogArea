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
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let support = load("dogArea/Source/Domain/Home/Services/HomeQuestReminderSupport.swift")
let sessionLifecycle = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let doc = load("docs/home-quest-reminder-same-day-suppression-v1.md")

assertTrue(
    support.contains("struct QuestReminderSchedulingContext"),
    "quest reminder support should define a scheduling context"
)
assertTrue(
    support.contains("hasSavedWalkOnCurrentDay"),
    "quest reminder context should model whether a saved walk already exists on the local day"
)
assertTrue(
    support.contains("makeNextReminderDate(from context: QuestReminderSchedulingContext)"),
    "quest reminder scheduler should compute the next one-shot reminder date"
)
assertTrue(
    support.contains("repeats: false"),
    "quest reminder scheduler should use a one-shot notification trigger"
)
assertTrue(
    sessionLifecycle.contains("func makeQuestReminderSchedulingContext(reference: Date = Date()) -> QuestReminderSchedulingContext"),
    "home session lifecycle should build quest reminder scheduling context"
)
assertTrue(
    sessionLifecycle.contains("walkRepository.fetchPolygons()"),
    "quest reminder scheduling should evaluate the latest saved polygons from the repository"
)
assertTrue(
    sessionLifecycle.contains("calendar.isDate(Date(timeIntervalSince1970: polygon.createdAt), inSameDayAs: reference)"),
    "quest reminder suppression should use local calendar day boundaries against saved walk timestamps"
)
assertTrue(
    sessionLifecycle.contains("func scheduleQuestReminderResyncIfNeeded(trigger: HomeRefreshTrigger, now: Date = Date())"),
    "home refresh lifecycle should reschedule quest reminders when launch or time boundary triggers occur"
)
assertTrue(
    homeViewModel.contains("var questReminderSyncTask: Task<Void, Never>? = nil"),
    "home view model should retain a cancellable quest reminder resync task"
)
assertTrue(
    doc.contains("user-wide") && doc.contains("one-shot") && doc.contains("toggle on/off"),
    "quest reminder suppression doc should capture user-wide one-shot scheduling policy"
)

print("PASS: home quest reminder same-day suppression unit checks")
