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

let source = loadMany([
    "dogArea/Views/MapView/MapViewModel.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift"
])

assertTrue(
    source.contains("@discardableResult\n    func appendWalkPoint(from location: CLLocation, recordedAt: Date, source: PointAppendSource) -> Location"),
    "appendWalkPoint should be marked @discardableResult to avoid unused-result warnings"
)
assertTrue(
    source.contains("appendWalkPoint(from: location, recordedAt: now, source: .auto)"),
    "auto point recording path should still call appendWalkPoint"
)
assertTrue(
    source.contains("self.appendWalkPoint(from: location, recordedAt: Date(), source: .watch)"),
    "watch add-point path should still call appendWalkPoint"
)

print("PASS: map appendWalkPoint discardable-result unit checks")
