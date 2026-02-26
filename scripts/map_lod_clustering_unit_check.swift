import Foundation

struct Point: Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
}

struct Cluster: Equatable {
    var members: [Point]
    var centerLatitude: Double
    var centerLongitude: Double
}

struct LODConfig {
    let overlayMaxCameraDistance: Double
    let overlayClusterThreshold: Int
    let overlayPolygonCountThreshold: Int
    let singleClusterOverlayLimit: Int
    let clusterCellDistanceRatio: Double
    let clusterCellMinMeters: Double
    let clusterCellMaxMeters: Double
}

func clusterCellSizeMeters(cameraDistance: Double, config: LODConfig) -> Double {
    let raw = cameraDistance * config.clusterCellDistanceRatio
    return min(config.clusterCellMaxMeters, max(config.clusterCellMinMeters, raw))
}

func bucketClusters(points: [Point], cameraDistance: Double, config: LODConfig) -> [Cluster] {
    guard points.count > 1 else {
        return points.map {
            Cluster(
                members: [$0],
                centerLatitude: $0.latitude,
                centerLongitude: $0.longitude
            )
        }
    }

    let cellMeters = clusterCellSizeMeters(cameraDistance: cameraDistance, config: config)
    let metersPerDegreeLatitude = 111_320.0

    var bucket: [String: [Point]] = [:]
    for point in points {
        let latStep = cellMeters / metersPerDegreeLatitude
        let lonMeterBase = metersPerDegreeLatitude * max(0.2, cos(point.latitude * .pi / 180.0))
        let lonStep = cellMeters / lonMeterBase
        let latIndex = Int(floor(point.latitude / latStep))
        let lonIndex = Int(floor(point.longitude / lonStep))
        let key = "\(latIndex):\(lonIndex)"
        bucket[key, default: []].append(point)
    }

    return bucket.keys.sorted().compactMap { key in
        guard let members = bucket[key], members.isEmpty == false else { return nil }
        let lat = members.map(\.latitude).reduce(0.0, +) / Double(members.count)
        let lon = members.map(\.longitude).reduce(0.0, +) / Double(members.count)
        return Cluster(members: members, centerLatitude: lat, centerLongitude: lon)
    }
}

func shouldRenderFullPolygonOverlays(
    cameraDistance: Double,
    clusterCount: Int,
    polygonCount: Int,
    config: LODConfig
) -> Bool {
    guard cameraDistance <= config.overlayMaxCameraDistance else { return false }
    guard clusterCount <= config.overlayClusterThreshold else { return false }
    guard polygonCount <= config.overlayPolygonCountThreshold else { return false }
    return true
}

func renderablePolygonIds(
    fullOverlay: Bool,
    allIds: [UUID],
    clusters: [Cluster],
    config: LODConfig
) -> [UUID] {
    if fullOverlay {
        return allIds
    }
    let singleIds = clusters.compactMap { cluster -> UUID? in
        guard cluster.members.count == 1 else { return nil }
        return cluster.members.first?.id
    }
    return Array(singleIds.prefix(config.singleClusterOverlayLimit))
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@inline(__always)
func load(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fputs("FAIL: cannot load \(path)\n", stderr)
        exit(1)
    }
    return text
}

let config = LODConfig(
    overlayMaxCameraDistance: 4_500,
    overlayClusterThreshold: 24,
    overlayPolygonCountThreshold: 900,
    singleClusterOverlayLimit: 160,
    clusterCellDistanceRatio: 0.08,
    clusterCellMinMeters: 80,
    clusterCellMaxMeters: 500
)

let base = Point(id: UUID(), latitude: 37.5665, longitude: 126.9780)
let near = Point(id: UUID(), latitude: 37.5666, longitude: 126.9780)
let far = Point(id: UUID(), latitude: 37.5750, longitude: 126.9900)
let points = [base, near, far]

let clustersA = bucketClusters(points: points, cameraDistance: 2_000, config: config)
let clustersB = bucketClusters(points: points.shuffled(), cameraDistance: 2_000, config: config)
assertTrue(clustersA.count == clustersB.count, "bucket cluster count should be deterministic")
assertTrue(clustersA.count < points.count, "near points should merge into one bucket in zoomed-out context")

assertTrue(
    shouldRenderFullPolygonOverlays(cameraDistance: 1_200, clusterCount: 8, polygonCount: 120, config: config),
    "zoomed-in small dataset should render full overlays"
)
assertTrue(
    shouldRenderFullPolygonOverlays(cameraDistance: 6_000, clusterCount: 8, polygonCount: 120, config: config) == false,
    "zoomed-out distance should disable full overlays"
)
assertTrue(
    shouldRenderFullPolygonOverlays(cameraDistance: 1_200, clusterCount: 30, polygonCount: 120, config: config) == false,
    "high cluster count should disable full overlays"
)
assertTrue(
    shouldRenderFullPolygonOverlays(cameraDistance: 1_200, clusterCount: 8, polygonCount: 1_200, config: config) == false,
    "high polygon count should disable full overlays"
)

let ids = points.map(\.id)
let lodIds = renderablePolygonIds(fullOverlay: false, allIds: ids, clusters: clustersA, config: config)
assertTrue(lodIds.count <= config.singleClusterOverlayLimit, "single-cluster overlays should be capped")

let doc = load("docs/map-lod-clustering-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
assertTrue(doc.contains("버킷 집계(O(n))"), "doc should include bucket O(n) strategy")
assertTrue(doc.contains("overlayMaxCameraDistance"), "doc should include LOD threshold definitions")
assertTrue(checklist.contains("폴리곤 1000건+"), "release checklist should include polygon mass-data scenario")
assertTrue(checklist.contains("LOD 모드"), "release checklist should include LOD mode scenario")

print("PASS: map lod clustering unit checks")
