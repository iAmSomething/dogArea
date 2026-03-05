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

let mapSource = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalSource = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")

assertTrue(
    mapSource.contains("guard snapshot.isEmpty == false else { return }"),
    "Map tracer should skip empty 1-second summary windows"
)
assertTrue(
    rivalSource.contains("guard snapshot.isEmpty == false else { return }"),
    "Rival tracer should skip empty 1-second summary windows"
)
assertTrue(
    mapSource.contains("[CoreLocationTrace][Map][1s] \\(summary)"),
    "Map tracer should still print non-empty 1-second summary logs"
)
assertTrue(
    rivalSource.contains("[CoreLocationTrace][Rival][1s] \\(summary)"),
    "Rival tracer should still print non-empty 1-second summary logs"
)
assertTrue(
    mapSource.contains("[CoreLocationTrace][Map][1s] idle") == false,
    "Map tracer should not emit idle spam logs"
)
assertTrue(
    rivalSource.contains("[CoreLocationTrace][Rival][1s] idle") == false,
    "Rival tracer should not emit idle spam logs"
)

print("PASS: corelocation trace idle log suppression unit checks")
