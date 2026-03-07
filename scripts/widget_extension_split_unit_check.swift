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

let project = load("dogArea.xcodeproj/project.pbxproj")
let bundle = load("dogAreaWidgetExtension/WalkControlWidgetBundle.swift")

let expectedFiles = [
    "dogAreaWidgetExtension/Shared/WidgetPresentationSupport.swift",
    "dogAreaWidgetExtension/Widgets/WalkControlWidget.swift",
    "dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift",
    "dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift",
    "dogAreaWidgetExtension/Widgets/QuestRivalStatusWidget.swift",
    "dogAreaWidgetExtension/Widgets/WalkLiveActivityWidget.swift"
]

for path in expectedFiles {
    assertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), "\(path) should exist after widget split")
    assertTrue(project.contains(path), "project should reference \(path)")
}

assertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("dogAreaWidgetExtension/WalkControlWidget.swift").path) == false, "legacy monolithic widget file should be removed")
assertTrue(project.contains("dogAreaWidgetExtension */ ="), "project should still contain widget extension group")
assertTrue(project.contains("Widgets */ ="), "project should define Widgets group for widget extension")
assertTrue(project.contains("Shared */ ="), "project should define Shared group for widget extension")
assertTrue(bundle.contains("WalkControlWidget()"), "widget bundle should still register walk control widget")
assertTrue(bundle.contains("TerritoryStatusWidget()"), "widget bundle should still register territory widget")
assertTrue(bundle.contains("HotspotStatusWidget()"), "widget bundle should still register hotspot widget")
assertTrue(bundle.contains("QuestRivalStatusWidget()"), "widget bundle should still register quest/rival widget")
assertTrue(bundle.contains("WalkLiveActivityWidget()"), "widget bundle should still register live activity widget")

print("PASS: widget extension split unit checks")
