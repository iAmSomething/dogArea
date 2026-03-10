import Foundation

/// 조건이 참인지 검증합니다.
/// - Parameters:
///   - condition: 평가할 조건식입니다.
///   - message: 실패 시 출력할 설명입니다.
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

let evidence = load("docs/issue-458-closure-evidence-v1.md")
let guidanceDoc = load("docs/home-weather-pet-guidance-sheet-v1.md")
let guidanceService = load("dogArea/Source/Domain/Home/Services/HomeWeatherWalkGuidanceService.swift")
let guidanceSheet = load("dogArea/Views/HomeView/HomeSubView/Presentation/HomeWeatherGuidanceSheetView.swift")
let guidanceModels = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeWeatherGuidancePresentationModels.swift")
let weatherCard = load("dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherSnapshotCardView.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let uiTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#458"), "evidence doc should reference issue #458")
assertTrue(evidence.contains("PR: `#593`") || evidence.contains("구현 PR: `#593`"), "evidence doc should reference implementation PR #593")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(guidanceDoc.contains("오늘 산책 시 주의"), "guidance doc should define the caution section")
assertTrue(guidanceDoc.contains("산책 권장 방식"), "guidance doc should define the recommended walking section")
assertTrue(guidanceDoc.contains("실내 대체 추천"), "guidance doc should define the indoor fallback section")
assertTrue(guidanceDoc.contains("fallback"), "guidance doc should define fallback policy")
assertTrue(guidanceService.contains("final class HomeWeatherWalkGuidanceService"), "guidance service implementation should exist")
assertTrue(guidanceService.contains("오늘 산책 시 주의"), "guidance service should produce caution-oriented copy")
assertTrue(guidanceService.contains("실내 대체 추천"), "guidance service should produce indoor replacement guidance")
assertTrue(guidanceSheet.contains("sheet.home.weatherGuidance"), "guidance sheet should expose a stable accessibility identifier")
assertTrue(guidanceSheet.contains("HomeWeatherGuidancePrimaryActionCardView"), "guidance sheet should compose the primary action summary card")
assertTrue(guidanceSheet.contains("HomeWeatherGuidanceDecisionFactorsCardView"), "guidance sheet should compose the decision factors card")
assertTrue(guidanceModels.contains("primaryActionTitle: \"오늘 추천\""), "guidance models should define the primary action title copy")
assertTrue(guidanceModels.contains("decisionFactorsTitle: \"이렇게 판단했어요\""), "guidance models should define the decision factors title copy")
assertTrue(homeView.contains("HomeWeatherGuidanceSheetView"), "home view should present the weather guidance sheet")
assertTrue(weatherCard.contains("home.weather.more"), "weather snapshot card should expose the weather more CTA identifier")
assertTrue(homeViewModel.contains("weatherWalkGuidanceService: HomeWeatherWalkGuidancePresenting = HomeWeatherWalkGuidanceService()"), "home view model should inject the weather guidance service")
assertTrue(uiTests.contains("testFeatureRegression_HomeWeatherGuidanceSheetShowsActionableFallbackAndSections"), "UI regression test for the weather guidance sheet should exist")
assertTrue(readme.contains("docs/issue-458-closure-evidence-v1.md"), "README should index the issue #458 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_458_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #458 closure evidence check")

print("PASS: issue #458 closure evidence unit checks")
