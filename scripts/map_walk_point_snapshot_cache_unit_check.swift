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

let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSubView = load("dogArea/Views/MapView/MapSubViews/MapSubView.swift")
let model = load("dogArea/Source/Domain/Map/Models/MapWalkPointSnapshot.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapWalkPointSnapshotService.swift")
let doc = load("docs/map-walk-point-snapshot-cache-v1.md")
let readme = load("README.md")

assertTrue(model.contains("struct MapWalkPointSnapshot"), "snapshot model should exist")
assertTrue(model.contains("let routeCoordinates"), "snapshot model should store route coordinates")
assertTrue(model.contains("let markLocations"), "snapshot model should store mark locations")
assertTrue(model.contains("var hasRenderableRoute"), "snapshot model should expose reusable route render state")

assertTrue(service.contains("protocol MapWalkPointSnapshotServicing"), "service file should define a protocol-first contract")
assertTrue(service.contains("final class MapWalkPointSnapshotService"), "service file should define the concrete snapshot service")
assertTrue(service.contains("appendedSnapshotIfPossible"), "service should support append-only updates for active walks")
assertTrue(service.contains("pointIDs.starts(with: cached.pointIDs)"), "service should detect append-only active walk updates")
assertTrue(service.contains("buildSnapshot("), "service should rebuild snapshots from a single pass when cache reuse is not possible")

assertTrue(mapViewModel.contains("private let walkPointSnapshotService: MapWalkPointSnapshotServicing"), "map view model should inject the walk point snapshot service")
assertTrue(mapViewModel.contains("walkPointSnapshotService: MapWalkPointSnapshotServicing = MapWalkPointSnapshotService()"), "map view model init should default the walk point snapshot service")
assertTrue(mapViewModel.contains("var activeWalkPointSnapshot: MapWalkPointSnapshot"), "map view model should expose the active walk snapshot")
assertTrue(mapViewModel.contains("func walkPointSnapshot(for polygon: Polygon) -> MapWalkPointSnapshot"), "map view model should expose polygon snapshot access")

assertTrue(mapSubView.contains("let activeWalkSnapshot = viewModel.activeWalkPointSnapshot"), "MapSubView should reuse a single active walk snapshot per render")
assertTrue(mapSubView.contains("let selectedPolygonSnapshot = viewModel.walkPointSnapshot(for: viewModel.polygon)"), "MapSubView should reuse a single selected polygon snapshot per render")
assertTrue(!mapSubView.contains("routeCoordinates(for: viewModel.polygon).count"), "MapSubView should not duplicate route coordinate extraction for count checks")

assertTrue(doc.contains("#502"), "doc should reference issue #502")
assertTrue(doc.contains("최소 `3회`"), "doc should record the before call count")
assertTrue(doc.contains("snapshot 생성 `1회`"), "doc should record the after snapshot reuse count")
assertTrue(readme.contains("docs/map-walk-point-snapshot-cache-v1.md"), "README should index the map walk point snapshot cache doc")

print("PASS: map walk point snapshot cache unit checks")
