import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let scriptURL = root.appendingPathComponent("scripts/ios_pr_check.sh")
let source = try String(contentsOf: scriptURL, encoding: .utf8)

assertTrue(
    source.contains("RUN_STAMP=\"$(date +%s)\""),
    "ios_pr_check should generate a per-run stamp for isolated derived data paths"
)
assertTrue(
    source.contains("DERIVED_DATA_PATH=\"${DOGAREA_DERIVED_DATA_PATH:-$ROOT_DIR/.build/ios_pr_check_derived_data_${RUN_STAMP}_$$}\""),
    "ios_pr_check should allow derived data path override and use a unique default path"
)
assertTrue(
    source.contains("mkdir -p \"$DERIVED_DATA_PATH\""),
    "ios_pr_check should create derived data directory before xcodebuild"
)
assertTrue(
    source.contains("-derivedDataPath \"$DERIVED_DATA_PATH\""),
    "ios_pr_check should pass the isolated derived data path to xcodebuild"
)

print("PASS: ios_pr_check derived data path unit checks")
