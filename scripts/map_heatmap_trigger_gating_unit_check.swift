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
let mapView = load("dogArea/Views/MapView/MapView.swift")
let model = load("dogArea/Source/Domain/Map/Models/MapHeatmapSnapshot.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapHeatmapAggregationService.swift")
let doc = load("docs/map-heatmap-trigger-gating-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(model.contains("struct MapHeatmapDatasetFingerprint"), "heatmap dataset fingerprint model should exist")
assertTrue(model.contains("struct MapHeatmapAggregationSnapshot"), "heatmap aggregation snapshot model should exist")
assertTrue(service.contains("protocol MapHeatmapAggregationServicing"), "heatmap service should be protocol-first")
assertTrue(service.contains("final class MapHeatmapAggregationService"), "heatmap service concrete type should exist")
assertTrue(service.contains("Task.detached(priority: .utility)"), "heatmap aggregation should run off the main thread")
assertTrue(service.contains("refreshBucketInterval: TimeInterval = 900"), "heatmap snapshot reuse should default to a 15 minute bucket")
assertTrue(service.contains("func canReuseSnapshot"), "heatmap service should expose snapshot reuse gating")

assertTrue(mapViewModel.contains("private let heatmapAggregationService: MapHeatmapAggregationServicing"), "MapViewModel should inject the heatmap aggregation service")
assertTrue(mapViewModel.contains("private var heatmapAggregationSnapshot: MapHeatmapAggregationSnapshot?"), "MapViewModel should retain the latest heatmap snapshot")
assertTrue(mapViewModel.contains("private var heatmapRefreshTask: Task<Void, Never>?"), "MapViewModel should track an async heatmap task")
assertTrue(mapViewModel.contains("var isHeatmapVisibleInMapUI: Bool"), "MapViewModel should expose a single effective heatmap visibility rule")
assertTrue(mapViewModel.contains("clearHeatmapPresentation(preserveSnapshot: true)"), "MapViewModel should clear only the presentation when heatmap is hidden")
assertTrue(!mapViewModel.contains("self.heatmapCells = HeatmapEngine.aggregate"), "MapViewModel should no longer aggregate heatmap cells directly")

assertTrue(mapSubView.contains("if viewModel.isHeatmapVisibleInMapUI"), "MapSubView should reuse the shared heatmap visibility rule")
assertTrue(mapView.contains("heatmapSummaryText: viewModel.isHeatmapVisibleInMapUI"), "MapView top chrome should reuse the shared heatmap visibility rule")

assertTrue(doc.contains("#503"), "performance report should reference issue #503")
assertTrue(doc.contains("최소 `2회`"), "performance report should explain the before call frequency")
assertTrue(doc.contains("전체 집계 `0회`"), "performance report should explain the hidden-state call reduction")
assertTrue(doc.contains("15분 bucket"), "performance report should document the snapshot reuse bucket")

assertTrue(readme.contains("docs/map-heatmap-trigger-gating-v1.md"), "README should index the heatmap trigger gating document")
assertTrue(iosCheck.contains("swift scripts/map_heatmap_trigger_gating_unit_check.swift"), "ios_pr_check should run the heatmap trigger gating check")

print("PASS: map heatmap trigger gating checks")
