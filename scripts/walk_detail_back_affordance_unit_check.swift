import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let detailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let actionSection = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailActionSectionView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walk-detail-back-affordance-v1.md")
let readme = load("README.md")
let iosCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    detailView.contains(".navigationTitle(\"산책 기록\")"),
    "walk detail should declare a navigation title so the default back affordance is visible"
)
assertTrue(
    detailView.contains(".navigationBarTitleDisplayMode(.inline)"),
    "walk detail should use inline title display mode"
)
assertTrue(
    !detailView.contains(".navigationBarBackButtonHidden()"),
    "walk detail should not hide the default back affordance"
)
assertTrue(
    actionSection.contains("walklist.detail.action.dismiss"),
    "walk detail should keep the bottom dismiss action as a secondary path"
)
assertTrue(
    featureTests.contains("testFeatureRegression_WalkListDetailRestoresTopBackAffordance"),
    "feature regression tests should cover walk detail back affordance restoration"
)
assertTrue(
    featureScript.contains("testFeatureRegression_WalkListDetailRestoresTopBackAffordance"),
    "feature regression script should run the walk detail back affordance test"
)
assertTrue(
    regressionMatrix.contains("FR-WALK-003B"),
    "UI regression matrix should include the walk detail back affordance case"
)
assertTrue(
    doc.contains("기본 navigation back button") && doc.contains("swipe back"),
    "doc should explain default back button restoration and swipe back preservation"
)
assertTrue(
    readme.contains("docs/walk-detail-back-affordance-v1.md"),
    "README should index the walk detail back affordance doc"
)
assertTrue(
    iosCheck.contains("swift scripts/walk_detail_back_affordance_unit_check.swift"),
    "ios_pr_check should include the walk detail back affordance unit check"
)

print("PASS: walk detail back affordance checks")
