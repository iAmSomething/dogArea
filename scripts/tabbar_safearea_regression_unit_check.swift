import Foundation

/// 조건이 거짓이면 표준 에러에 메시지를 출력하고 즉시 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 오류 메시지입니다.
/// - Returns: 없음. 실패 조건이면 프로세스를 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 로드합니다.
/// - Parameter relativePath: 저장소 루트에서 시작하는 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")

assertTrue(
    rootView.contains(".safeAreaInset(edge: .bottom, spacing: 0)"),
    "RootView should reserve bottom safe area for CustomTabBar"
)
assertTrue(
    rootView.contains("CustomTabBar(selectedTab: $selectedTab)"),
    "RootView should render CustomTabBar inside bottom safe area inset"
)
assertTrue(
    !rootView.contains("ZStack(alignment: .bottom)"),
    "RootView should avoid bottom overlay ZStack that can cover content"
)
assertTrue(
    !rootView.contains(".padding(.bottom, 2)"),
    "RootView should avoid manual bottom offset that reintroduces overlap risk"
)

print("PASS: tabbar safe area regression unit checks")
