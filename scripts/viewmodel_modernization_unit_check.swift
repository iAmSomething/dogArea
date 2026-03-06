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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let mapVM = loadMany([
    "dogArea/Views/MapView/MapViewModel.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift"
])
let settingVM = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let walkListVM = load("dogArea/Views/WalkListView/WalkListViewModel.swift")

assertTrue(mapVM.contains("private func reloadPolygonState"), "MapViewModel should centralize polygon state updates")
assertTrue(mapVM.contains("enum WatchIncomingAction"), "MapViewModel should use typed watch action")
assertTrue(!mapVM.contains("@Environment(\\.managedObjectContext)"), "MapViewModel should not use @Environment managedObjectContext")
assertTrue(!settingVM.contains("@Environment(\\.managedObjectContext)"), "SettingViewModel should not use @Environment managedObjectContext")
assertTrue(!walkListVM.contains("@Environment(\\.managedObjectContext)"), "WalkListViewModel should not use @Environment managedObjectContext")

print("PASS: viewmodel modernization unit checks")
