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

let coreDataProtocol = load("dogArea/Source/CoreDataProtocol.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")

assertTrue(coreDataProtocol.contains("request.sortDescriptors = [NSSortDescriptor(key: \"createdAt\", ascending: true)]"), "fetchRequest should have createdAt sort descriptor")
assertTrue(coreDataProtocol.contains("func savePolygon (polygon : Polygon) -> [Polygon]"), "savePolygon signature should return polygon array")
assertTrue(coreDataProtocol.contains("return fetchPolygons()"), "save/delete should return latest fetch result")
assertTrue(coreDataProtocol.contains("let request = fetchRequest"), "deletePolygon should use isolated fetch request with predicate")

assertTrue(mapViewModel.contains("private func applyPolygonList"), "MapViewModel should apply returned polygon list directly")
assertTrue(mapViewModel.contains("let updated = savePolygon(polygon: self.polygon)"), "save call site should use returned list")
assertTrue(mapViewModel.contains("let updated = deletePolygon(id: id)"), "delete call site should use returned list")

print("PASS: coredata return contract unit checks")
