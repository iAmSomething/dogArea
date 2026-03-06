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

/// 여러 상대 경로 파일을 하나의 문자열로 이어 붙여 읽습니다.
/// - Parameter relativePaths: 저장소 루트 기준 파일 경로 목록입니다.
/// - Returns: 각 파일 내용을 줄바꿈으로 연결한 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/Cards/HomeGuestDataUpgradeCardView.swift"
])

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
