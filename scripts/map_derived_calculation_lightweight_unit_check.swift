import Foundation

/// Asserts that a condition is true and exits with a failure message otherwise.
/// - Parameters:
///   - condition: Boolean expression that must evaluate to `true`.
///   - message: Failure description printed when the assertion does not hold.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a UTF-8 text file from the repository root.
/// - Parameter relativePath: Repository-relative file path to read.
/// - Returns: Decoded UTF-8 file contents.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let umbrellaDoc = load("docs/map-derived-calculation-lightweight-v1.md")
let walkPointDoc = load("docs/map-walk-point-snapshot-cache-v1.md")
let heatmapDoc = load("docs/map-heatmap-trigger-gating-v1.md")
let hotspotDoc = load("docs/map-hotspot-cluster-trigger-gating-v1.md")
let motionDoc = load("docs/map-motion-ticker-layer-split-v1.md")
let invalidationDoc = load("docs/map-walking-invalidation-reduction-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(umbrellaDoc.contains("#477"), "umbrella doc should reference issue #477")
assertTrue(umbrellaDoc.contains("#476"), "umbrella doc should link the invalidation reduction sub-issue")
assertTrue(umbrellaDoc.contains("#501"), "umbrella doc should link the motion ticker split sub-issue")
assertTrue(umbrellaDoc.contains("#502"), "umbrella doc should link the walk point snapshot cache sub-issue")
assertTrue(umbrellaDoc.contains("#503"), "umbrella doc should link the heatmap trigger gating sub-issue")
assertTrue(umbrellaDoc.contains("#504"), "umbrella doc should link the hotspot trigger gating sub-issue")

assertTrue(umbrellaDoc.contains("최소 `3회`"), "umbrella doc should record the route/mark before call count")
assertTrue(umbrellaDoc.contains("snapshot 생성 `1회`"), "umbrella doc should record the route/mark after snapshot count")
assertTrue(umbrellaDoc.contains("전체 집계 `0회`"), "umbrella doc should record heatmap hidden-state aggregation elimination")
assertTrue(umbrellaDoc.contains("hotspot cluster 재계산 `0회`"), "umbrella doc should record hotspot cluster gating result")
assertTrue(umbrellaDoc.contains("TimelineView` 개수 `0`"), "umbrella doc should record motion ticker removal")
assertTrue(umbrellaDoc.contains("count = 0"), "umbrella doc should record the stabilized walking invalidation measurement")
assertTrue(umbrellaDoc.contains("mapSubViewBodyCount=2"), "umbrella doc should record the latest render budget measurement")

assertTrue(umbrellaDoc.contains("docs/map-walk-point-snapshot-cache-v1.md"), "umbrella doc should link the walk point doc")
assertTrue(umbrellaDoc.contains("docs/map-heatmap-trigger-gating-v1.md"), "umbrella doc should link the heatmap doc")
assertTrue(umbrellaDoc.contains("docs/map-hotspot-cluster-trigger-gating-v1.md"), "umbrella doc should link the hotspot doc")
assertTrue(umbrellaDoc.contains("docs/map-motion-ticker-layer-split-v1.md"), "umbrella doc should link the motion doc")
assertTrue(umbrellaDoc.contains("docs/map-walking-invalidation-reduction-v1.md"), "umbrella doc should link the invalidation doc")

assertTrue(walkPointDoc.contains("snapshot 생성 `1회`"), "walk point doc should preserve the snapshot reuse evidence")
assertTrue(heatmapDoc.contains("15분 bucket"), "heatmap doc should preserve the freshness bucket evidence")
assertTrue(hotspotDoc.contains("0.9초 heartbeat"), "hotspot doc should preserve the heartbeat baseline evidence")
assertTrue(motionDoc.contains("TimelineView` 개수: `0"), "motion doc should preserve the ticker split evidence")
assertTrue(invalidationDoc.contains("count = 0"), "invalidation doc should preserve the stabilized measurement evidence")

assertTrue(readme.contains("docs/map-derived-calculation-lightweight-v1.md"), "README should index the umbrella performance doc")
assertTrue(iosCheck.contains("swift scripts/map_derived_calculation_lightweight_unit_check.swift"), "ios_pr_check should run the umbrella performance unit check")

print("PASS: map derived calculation lightweight umbrella checks")
