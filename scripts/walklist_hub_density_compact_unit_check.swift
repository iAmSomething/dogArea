import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: UTF-8 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let headerView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let primaryLoopView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListPrimaryLoopSummaryCardView.swift")
let contextView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListContextSummaryCardView.swift")
let presentationModels = load("dogArea/Views/WalkListView/WalkListPresentationModels.swift")
let presentationService = load("dogArea/Views/WalkListView/WalkListPresentationService.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureScript = load("scripts/run_feature_regression_ui_tests.sh")
let regressionMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walklist-hub-density-compact-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(headerView.contains("WalkListContextSummaryCardView("), "dashboard header should use a dedicated compact context summary card")
assertTrue(primaryLoopView.contains("size: 18"), "primary loop title should use compact 18pt scale")
assertTrue(primaryLoopView.contains("size: 12"), "primary loop message should use compact 12pt body copy")
assertTrue(primaryLoopView.contains("size: 11"), "primary loop secondary message should use compact 11pt caption copy")
assertTrue(primaryLoopView.contains("spacing: 8"), "primary loop card should reduce vertical spacing")
assertTrue(primaryLoopView.contains("lineLimit(2)"), "primary loop message should stay within two lines")
assertTrue(primaryLoopView.contains("lineLimit(1)"), "primary loop secondary copy should stay within one line")

assertTrue(contextView.contains("spacing: 10"), "context card should use compact 10pt vertical rhythm")
assertTrue(contextView.contains("size: 12"), "context message should use compact 12pt body copy")
assertTrue(contextView.contains("size: 11"), "context helper should use compact 11pt caption copy")
assertTrue(contextView.contains("lineLimit(2)"), "context message should stay within two lines")
assertTrue(contextView.contains("lineLimit(1)"), "context helper should stay within one line")
assertTrue(contextView.contains("walklist.context.helper"), "context helper should expose an accessibility identifier")

assertTrue(presentationModels.contains("산책 기록을 빠르게 훑고 다시 찾는 화면이에요."), "overview placeholder should use compact subtitle copy")
assertTrue(presentationService.contains("산책이 기록을 만듭니다"), "presentation service should use compact primary loop title")
assertTrue(presentationService.contains("기록 기준을 바로 바꿀 수 있어요"), "presentation service should use compact context title")
assertTrue(presentationService.contains("기록 범위를 빠르게 바꾸고 최근 산책을 다시 읽는 화면이에요."), "all-records subtitle should be shortened")
assertTrue(presentationService.contains("반려견 칩을 바꾸면 같은 화면에서 바로 비교됩니다."), "all-records helper should be shortened")
assertTrue(presentationService.contains("필요하면 전체 기록 보기로 다시 넓혀 비교할 수 있어요."), "default helper should stay compact")
assertTrue(presentationService.contains("홈 목표와 시즌 흐름을 다시 읽는 기준") == false, "old verbose onboarding copy should be removed")
assertTrue(presentationService.contains("이후 목표와 미션, 시즌 해석의 기준") == false, "selected-pet verbose onboarding copy should be removed")
assertTrue(presentationService.contains("세션 성격을 한눈에 파악할 수 있게 구성했습니다.") == false, "old helper copy should be removed")

assertTrue(featureTests.contains("testFeatureRegression_WalkListHeaderCardsStayCompactWithoutVerboseOnboardingCopy"), "feature regression should cover walk list compact hub copy")
assertTrue(featureScript.contains("testFeatureRegression_WalkListHeaderCardsStayCompactWithoutVerboseOnboardingCopy"), "feature regression script should run the walk list compact hub test")
assertTrue(regressionMatrix.contains("FR-WALK-002B"), "ui regression matrix should include walk list compact hub regression")
assertTrue(doc.contains("helper 문구는 항상 1줄로 제한"), "doc should describe one-line helper contract")
assertTrue(doc.contains("기본 행동 카드"), "doc should describe compact hub structure")
assertTrue(readme.contains("docs/walklist-hub-density-compact-v1.md"), "README should index the compact hub doc")
assertTrue(prCheck.contains("walklist_hub_density_compact_unit_check.swift"), "ios_pr_check should run the compact hub check")

print("PASS: walk list hub density compact unit checks")
