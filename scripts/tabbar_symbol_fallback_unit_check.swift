import Foundation

/// 조건이 거짓이면 에러를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let tabBar = load("dogArea/Views/GlobalViews/BaseView/CustomTabBar.swift")
let regressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let policy = load("docs/tabbar-sf-symbol-fallback-policy-v1.md")
let readme = load("README.md")

assertTrue(
    tabBar.contains("defaultSymbolName"),
    "CustomTabBar should define explicit default symbol names per tab"
)
assertTrue(
    tabBar.contains("selectedSymbolName"),
    "CustomTabBar should define explicit selected symbol names per tab"
)
assertTrue(
    tabBar.contains("list.bullet.circle.fill"),
    "Walk list tab should provide an explicit selected SF Symbol"
)
assertTrue(
    tabBar.contains("resolvedSymbolName(isSelected: isSelected)"),
    "CustomTabBar should resolve tab symbols through an explicit resolver"
)
assertTrue(
    !tabBar.contains("\\(item.icon).fill"),
    "CustomTabBar should not compose selected symbol names via string fill suffix"
)
assertTrue(
    tabBar.contains("UIImage(systemName: primary) == nil ? fallback : primary"),
    "CustomTabBar should guard selected symbols with a runtime fallback rule"
)
assertTrue(
    tabBar.contains(".accessibilityValue(isSelected ? \"selected:\\(resolvedSymbolName)\" : \"default:\\(resolvedSymbolName)\")"),
    "CustomTabBar should expose resolved selected symbol state for regression testing"
)
assertTrue(
    regressionTests.contains("testFeatureRegression_WalkListTabSelectedIconRemainsVisibleInBothStyles"),
    "Feature regression tests should cover the walk list tab selected icon state"
)
assertTrue(
    policy.contains("자동 생성하지 않습니다"),
    "Policy doc should forbid automatic selected symbol composition"
)
assertTrue(
    policy.contains(".fill") && policy.contains("문자열 결합은 금지합니다."),
    "Policy doc should forbid automatic .fill composition"
)
assertTrue(
    readme.contains("docs/tabbar-sf-symbol-fallback-policy-v1.md"),
    "README should index the tab bar SF Symbol fallback policy"
)

print("PASS: tabbar symbol fallback unit checks")
