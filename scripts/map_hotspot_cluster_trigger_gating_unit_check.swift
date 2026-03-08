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
let model = load("dogArea/Source/Domain/Map/Models/MapHotspotClusterSnapshot.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapHotspotClusterRenderingService.swift")
let doc = load("docs/map-hotspot-cluster-trigger-gating-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(model.contains("struct MapHotspotClusterDatasetFingerprint"), "hotspot dataset fingerprint model should exist")
assertTrue(model.contains("struct MapHotspotClusterViewportFingerprint"), "hotspot viewport fingerprint model should exist")
assertTrue(model.contains("struct MapHotspotClusterTuningFingerprint"), "hotspot tuning fingerprint model should exist")
assertTrue(model.contains("struct MapHotspotClusterSnapshot"), "hotspot cluster snapshot model should exist")

assertTrue(service.contains("protocol MapHotspotClusterRenderingServicing"), "hotspot rendering service should be protocol-first")
assertTrue(service.contains("final class MapHotspotClusterRenderingService"), "hotspot rendering service concrete type should exist")
assertTrue(service.contains("func makeDatasetFingerprint"), "service should fingerprint hotspot inputs")
assertTrue(service.contains("func makeViewportFingerprint"), "service should fingerprint the viewport")
assertTrue(service.contains("func makeTuningFingerprint"), "service should fingerprint tuning values")
assertTrue(service.contains("func canReuseSnapshot"), "service should expose snapshot reuse gating")
assertTrue(service.contains("distanceBucketMeters = Int((normalizedDistance / 80.0).rounded() * 80.0)"), "viewport fingerprint should quantize camera distance into 80m buckets")

assertTrue(mapViewModel.contains("private let hotspotClusterRenderingService: MapHotspotClusterRenderingServicing"), "MapViewModel should inject the hotspot rendering service")
assertTrue(mapViewModel.contains("private var hotspotClusterSnapshot: MapHotspotClusterSnapshot?"), "MapViewModel should retain the latest hotspot snapshot")
assertTrue(mapViewModel.contains("hotspotClusterRenderingService: MapHotspotClusterRenderingServicing? = nil"), "MapViewModel init should allow overriding the hotspot rendering service")
assertTrue(mapViewModel.contains("hotspotClusterRenderingService.canReuseSnapshot"), "MapViewModel should reuse hotspot snapshots when fingerprints match")
assertTrue(mapViewModel.contains("applyRenderableNearbyHotspotSnapshot(snapshot)"), "MapViewModel should apply hotspot results through a snapshot helper")
assertTrue(!mapViewModel.contains("let nodes = clusterAnnotationService.renderHotspots("), "MapViewModel should not call renderHotspots directly anymore")

assertTrue(doc.contains("#504"), "doc should reference issue #504")
assertTrue(doc.contains("0.9초 heartbeat"), "doc should explain the previous heartbeat recompute path")
assertTrue(doc.contains("hotspot cluster 재계산 `0회`"), "doc should explain the after recompute reduction")
assertTrue(doc.contains("renderableNearbyHotspotNodes"), "doc should explain publish suppression and stability")

assertTrue(readme.contains("docs/map-hotspot-cluster-trigger-gating-v1.md"), "README should index the hotspot trigger gating doc")
assertTrue(iosCheck.contains("swift scripts/map_hotspot_cluster_trigger_gating_unit_check.swift"), "ios_pr_check should run the hotspot trigger gating check")

print("PASS: map hotspot cluster trigger gating checks")
