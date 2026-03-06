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

let homeView = load("dogArea/Views/HomeView/HomeView.swift")

assertTrue(
    homeView.contains(".accessibilityIdentifier(\"home.guestUpgrade.retry\")"),
    "home guest data upgrade card should expose retry CTA accessibility identifier"
)
assertTrue(
    homeView.contains("authFlow.startGuestDataUpgrade(forceRetry: true)"),
    "home retry CTA should trigger forced guest data upgrade"
)
assertTrue(
    homeView.contains(".onChange(of: authFlow.guestDataUpgradeResult?.executedAt)"),
    "home view should refresh report when auth flow publishes upgrade result"
)
assertTrue(
    homeView.contains("private func triggerGuestDataUpgradeRetry()"),
    "home view should isolate retry CTA action handler"
)

print("PASS: home guest upgrade retry CTA unit checks")
