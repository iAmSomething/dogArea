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

let calendarModels = load("dogArea/Views/WalkListView/WalkListCalendarPresentationModels.swift")
let calendarService = load("dogArea/Views/WalkListView/WalkListCalendarPresentationService.swift")
let calendarCard = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMonthlyCalendarCardView.swift")
let calendarDayCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMonthlyCalendarDayCellView.swift")
let featureRegressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let readme = load("README.md")
let doc = load("docs/walklist-calendar-weekend-holiday-semantic-v1.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(calendarModels.contains("enum WalkListCalendarSemanticTone"), "calendar models should define a semantic tone enum")
assertTrue(calendarModels.contains("WalkListCalendarWeekdayHeaderModel"), "calendar models should define a weekday header model")
assertTrue(calendarModels.contains("semanticTone"), "calendar day cells should publish semantic tone information")
assertTrue(calendarModels.contains("holidayName"), "calendar day cells should preserve an optional holiday name source")
assertTrue(calendarService.contains("WalkListCalendarHolidayProviding"), "calendar service should expose a holiday provider seam")
assertTrue(calendarService.contains("WalkListCalendarEmptyHolidayProvider"), "calendar service should define the empty holiday provider fallback")
assertTrue(calendarService.contains("orderedWeekdayHeaders"), "calendar service should build weekday headers through the semantic pipeline")
assertTrue(calendarService.contains("holidayName(for: dayStart, calendar: calendar)"), "calendar service should ask the holiday provider per day cell")
assertTrue(calendarService.contains("if holidayName != nil"), "holiday tone should take priority over weekend tone when data exists")
assertTrue(calendarCard.contains("weekdayHeaderColor"), "calendar card should color weekday headers from semantic tone")
assertTrue(calendarModels.contains("walklist.calendar.weekday.") || calendarService.contains("walklist.calendar.weekday."), "calendar weekday headers should expose accessibility identifiers")
assertTrue(calendarDayCell.contains("switch model.semanticTone"), "calendar day cell should resolve text color from semantic tone")
assertTrue(featureRegressionTests.contains("testFeatureRegression_WalkListCalendarWeekendSemanticLabelsStayConsistent"), "feature regression tests should cover weekend semantic labels")
assertTrue(featureRegressionScript.contains("testFeatureRegression_WalkListCalendarWeekendSemanticLabelsStayConsistent"), "feature regression script should run the weekend semantic regression")
assertTrue(uiMatrix.contains("FR-WALK-004A"), "ui regression matrix should register the weekend semantic regression")
assertTrue(doc.contains("공휴일 데이터가 없는 런타임에서는"), "doc should define the no-holiday fallback rule")
assertTrue(doc.contains("selected/today는 배경·보더"), "doc should define the priority rule between selected/today and semantic color")
assertTrue(readme.contains("docs/walklist-calendar-weekend-holiday-semantic-v1.md"), "README should index the weekend/holiday semantic doc")
assertTrue(prCheck.contains("swift scripts/walklist_calendar_weekend_holiday_semantic_unit_check.swift"), "ios_pr_check should include the weekend/holiday semantic check")

print("PASS: walk list calendar weekend/holiday semantic unit checks")
