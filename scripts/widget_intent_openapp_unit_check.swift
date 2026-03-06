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

let intents = load("dogAreaWidgetExtension/WalkControlIntents.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")

assertTrue(intents.contains("func perform() async throws -> some IntentResult & OpensIntent"), "widget intents should return OpensIntent to guarantee app launch route")
assertTrue(intents.contains("OpenURLIntent"), "widget intents should open app via OpenURLIntent")
assertTrue(intents.contains("route.asRoute().makeURL()"), "widget intents should serialize action route into deep link URL")
assertTrue(rootView.contains("[WidgetAction] onOpenURL received:"), "RootView should log incoming widget deep links in debug")
assertTrue(rootView.contains("consumePendingWidgetActionIfNeeded"), "RootView should keep pending widget action consumption path")

print("PASS: widget intent open-app unit checks")
