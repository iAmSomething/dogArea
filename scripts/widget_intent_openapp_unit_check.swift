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

assertTrue(intents.contains("static var openAppWhenRun: Bool = true"), "widget intents should request app foreground continuation")
assertTrue(intents.contains("#if compiler(>=6.0)"), "widget intents should gate new SDK open-app APIs for CI compatibility")
assertTrue(intents.contains("OpenURLIntent"), "widget intents should still use OpenURLIntent on supported toolchains")
assertTrue(intents.contains("return .result()"), "widget intents should keep an older toolchain fallback result path")
assertTrue(intents.contains("route.asRoute().makeURL()"), "widget intents should serialize action route into deep link URL")
assertTrue(rootView.contains("[WidgetAction] onOpenURL received:"), "RootView should log incoming widget deep links in debug")
assertTrue(rootView.contains("consumePendingWidgetActionIfNeeded"), "RootView should keep pending widget action consumption path")

print("PASS: widget intent open-app unit checks")
