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
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])

assertTrue(
    source.contains("private enum RefreshGateDecision"),
    "feature flag store should define refresh gate decision enum"
)
assertTrue(
    source.contains("private var isRefreshInFlight: Bool = false"),
    "feature flag store should track in-flight refresh state"
)
assertTrue(
    source.contains("switch evaluateRefreshGate(force: force, now: now)"),
    "refresh(force:) should evaluate single-flight gate before network call"
)
assertTrue(
    source.contains("print(\"[FeatureFlag] refresh skipped: in-flight\")"),
    "feature flag store should log in-flight dedupe in debug builds"
)
assertTrue(
    source.contains("defer { finishRefreshCycle() }"),
    "refresh(force:) should always clear in-flight marker after completion"
)
assertTrue(
    source.contains("private func evaluateRefreshGate(force: Bool, now: Date) -> RefreshGateDecision"),
    "feature flag store should provide gate evaluation helper"
)
assertTrue(
    source.contains("private func finishRefreshCycle()"),
    "feature flag store should provide explicit in-flight cleanup helper"
)

print("PASS: feature flag refresh single-flight unit checks")
