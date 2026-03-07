import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let source = try String(contentsOf: sourceURL, encoding: .utf8)

assertTrue(
    source.contains("@preconcurrency\nfinal class RivalTabViewModel: NSObject, ObservableObject, CLLocationManagerDelegate"),
    "RivalTabViewModel should adopt CLLocationManagerDelegate with @preconcurrency to avoid Swift 6 concurrency warnings"
)
assertTrue(
    source.contains("@MainActor\n@preconcurrency\nfinal class RivalTabViewModel"),
    "RivalTabViewModel should remain main-actor isolated"
)

print("PASS: rival CLLocation delegate preconcurrency unit checks")
