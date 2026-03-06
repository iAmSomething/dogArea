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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let mapMain = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSupport = loadMany([
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift"
])
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(
    mapMain.contains("func applyWidgetWalkAction(_ route: WalkWidgetActionRoute)") == false,
    "MapViewModel main file should not retain widget action handling implementation"
)
assertTrue(
    mapMain.contains("func setupWatchConnectivity()") == false,
    "MapViewModel main file should not retain watch connectivity setup implementation"
)
assertTrue(
    mapMain.contains("didReceiveMessage message: [String : Any],") == false,
    "MapViewModel main file should not retain watch delegate message handlers"
)
assertTrue(
    mapSupport.contains("func applyWidgetWalkAction(_ route: WalkWidgetActionRoute)"),
    "widget support file should own widget action handling"
)
assertTrue(
    mapSupport.contains("func syncWalkLiveActivity(force: Bool = false)"),
    "widget support file should own live activity synchronization"
)
assertTrue(
    mapSupport.contains("func setupWatchConnectivity()"),
    "watch support file should own watch connectivity setup"
)
assertTrue(
    mapSupport.contains("didReceiveMessage message: [String : Any],"),
    "watch support file should own watch delegate message handling"
)
assertTrue(
    project.contains("MapViewModelSupport"),
    "project should include MapViewModelSupport group"
)
assertTrue(
    project.contains("MapViewModel+WidgetRuntimeSupport.swift"),
    "project should include widget runtime support file"
)
assertTrue(
    project.contains("MapViewModel+WatchConnectivitySupport.swift"),
    "project should include watch connectivity support file"
)

print("PASS: map viewmodel widget/watch support split unit checks")
