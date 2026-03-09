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
let mapSetting = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let uiTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let readme = load("README.md")
let doc = load("docs/walk-record-tab-label-v1.md")

assertTrue(
    tabBar.contains("title: \"산책 기록\""),
    "CustomTabBar should expose the walk record tab label"
)
assertTrue(
    tabBar.contains(".accessibilityLabel(item.title)"),
    "CustomTabBar should derive accessibility label from the user-facing tab title"
)
assertTrue(
    mapSetting.contains("Text(\"산책 기록\")"),
    "Map setting sheet should use the walk record terminology for the history section"
)
assertTrue(
    uiTests.contains("walkListTab.label.contains(\"산책 기록\")"),
    "Feature regression UI tests should assert the walk record tab label"
)
assertTrue(
    featureRegressionScript.contains("testFeatureRegression_WalkListTabSelectedIconRemainsVisibleInBothStyles"),
    "Feature regression script should keep the walk record tab regression"
)
assertTrue(
    readme.contains("docs/walk-record-tab-label-v1.md"),
    "README should index the walk record tab label doc"
)
assertTrue(
    doc.contains("`산책 기록`"),
    "Walk record tab label doc should define the canonical user-facing label"
)

print("PASS: walk record tab label unit checks")
