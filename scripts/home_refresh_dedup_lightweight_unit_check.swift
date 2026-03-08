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

let umbrellaDoc = load("docs/home-refresh-dedup-lightweight-v1.md")
let refreshDoc = load("docs/home-refresh-entrypoint-v1.md")
let petContextDoc = load("docs/home-mission-pet-context-snapshot-v1.md")
let weatherDoc = load("docs/weather-snapshot-provider-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(umbrellaDoc.contains("#478"), "umbrella doc should reference issue #478")
assertTrue(umbrellaDoc.contains("#453"), "umbrella doc should reference the mission lifecycle related issue")
assertTrue(umbrellaDoc.contains("#456"), "umbrella doc should reference the home weather card related issue")
assertTrue(umbrellaDoc.contains("#457"), "umbrella doc should reference the shared weather snapshot related issue")
assertTrue(umbrellaDoc.contains("#505"), "umbrella doc should reference the refresh entrypoint dedup related issue")
assertTrue(umbrellaDoc.contains("#506"), "umbrella doc should reference the pet context snapshot related issue")
assertTrue(umbrellaDoc.contains("#464"), "umbrella doc should mention the non-blocking follow-up product issue")

assertTrue(umbrellaDoc.contains("각 `4회`"), "umbrella doc should preserve the initial refresh before-call count")
assertTrue(umbrellaDoc.contains("각 `2회`"), "umbrella doc should preserve the repeated refresh before-call count")
assertTrue(umbrellaDoc.contains("각 `1회`"), "umbrella doc should preserve the deduplicated after-call count")
assertTrue(umbrellaDoc.contains("filter` `2회` + `reduce` `1회") || umbrellaDoc.contains("`polygonList.filter` `2회` + `reduce` `1회`"), "umbrella doc should preserve the pet context before-cost evidence")
assertTrue(umbrellaDoc.contains("filter/reduce` `0회`") || umbrellaDoc.contains("`filter/reduce` `0회`"), "umbrella doc should preserve the pet context cache-hit evidence")
assertTrue(umbrellaDoc.contains("WeatherSnapshotStore"), "umbrella doc should preserve the shared weather snapshot contract")

assertTrue(umbrellaDoc.contains("docs/home-refresh-entrypoint-v1.md"), "umbrella doc should link the refresh entrypoint document")
assertTrue(umbrellaDoc.contains("docs/home-mission-pet-context-snapshot-v1.md"), "umbrella doc should link the pet context snapshot document")
assertTrue(umbrellaDoc.contains("docs/weather-snapshot-provider-v1.md"), "umbrella doc should link the weather snapshot document")

assertTrue(refreshDoc.contains("홈 최초 진입"), "refresh doc should preserve the initial entrypoint matrix")
assertTrue(petContextDoc.contains("`canReuseSnapshot` O(1)"), "pet context doc should preserve the cache-hit complexity evidence")
assertTrue(weatherDoc.contains("WeatherSnapshotStore"), "weather doc should preserve the shared store contract")

assertTrue(readme.contains("docs/home-refresh-dedup-lightweight-v1.md"), "README should index the umbrella home performance doc")
assertTrue(iosCheck.contains("swift scripts/home_refresh_dedup_lightweight_unit_check.swift"), "ios_pr_check should run the umbrella home performance unit check")

print("PASS: home refresh dedup lightweight umbrella checks")
