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

let walkListView = load("dogArea/Views/WalkListView/WalkListView.swift")
let walkListViewModel = load("dogArea/Views/WalkListView/WalkListViewModel.swift")
let headerView = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDashboardHeaderView.swift")
let calendarModels = load("dogArea/Views/WalkListView/WalkListCalendarPresentationModels.swift")
let calendarService = load("dogArea/Views/WalkListView/WalkListCalendarPresentationService.swift")
let calendarCard = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMonthlyCalendarCardView.swift")
let calendarDayCell = load("dogArea/Views/WalkListView/WalkListSubView/WalkListMonthlyCalendarDayCellView.swift")
let featureRegressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let uiMatrix = load("docs/ui-regression-matrix-v1.md")
let doc = load("docs/walklist-month-calendar-hub-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(walkListView.contains("calendar: viewModel.calendarModel"), "walk list view should wire calendar model into the dashboard header")
assertTrue(headerView.contains("WalkListMonthlyCalendarCardView"), "dashboard header should render the monthly calendar card")
assertTrue(walkListViewModel.contains("@Published private(set) var calendarModel"), "walk list view model should publish the calendar model")
assertTrue(walkListViewModel.contains("selectedCalendarDate"), "walk list view model should keep selected calendar date state")
assertTrue(walkListViewModel.contains("displayedCalendarMonth"), "walk list view model should keep displayed month state")
assertTrue(walkListViewModel.contains("bindTimeBoundaryRefresh()"), "walk list view model should bind time boundary refreshes")
assertTrue(walkListViewModel.contains("-UITest.WalkListCalendarPreview"), "walk list view model should support the calendar preview route")
assertTrue(calendarModels.contains("WalkListCalendarPresentationModel"), "calendar models file should define the presentation model")
assertTrue(calendarModels.contains("WalkListCalendarSnapshot"), "calendar models file should define the snapshot model")
assertTrue(calendarService.contains("WalkListCalendarPresentationServicing"), "calendar service should define a protocol contract")
assertTrue(calendarService.contains("dayStartsCovered(by: record.toPolygon()"), "calendar service should reuse day boundary aggregation logic")
assertTrue(calendarCard.contains("walklist.calendar.card"), "calendar card should expose its accessibility identifier")
assertTrue(calendarCard.contains("walklist.calendar.clear"), "calendar card should expose a clear action identifier")
assertTrue(calendarDayCell.contains("accessibilityIdentifier"), "calendar day cell should wire through its accessibility identifier")
assertTrue(calendarService.contains("walklist.calendar.day."), "calendar service should mint per-day accessibility identifiers")
assertTrue(featureRegressionTests.contains("testFeatureRegression_WalkListCalendarSelectionFiltersToChosenDate"), "feature regression tests should cover calendar date filtering")
assertTrue(featureRegressionScript.contains("testFeatureRegression_WalkListCalendarSelectionFiltersToChosenDate"), "feature regression script should run the calendar selection regression")
assertTrue(uiMatrix.contains("FR-WALK-004"), "ui regression matrix should include the walk list calendar regression")
assertTrue(doc.contains("즉시 필터"), "calendar hub doc should define the immediate filtering policy")
assertTrue(doc.contains("자정을 넘긴 산책은 걸친 모든 날짜"), "calendar hub doc should define the midnight spanning policy")
assertTrue(readme.contains("docs/walklist-month-calendar-hub-v1.md"), "README should index the walk list calendar hub doc")
assertTrue(prCheck.contains("swift scripts/walklist_month_calendar_hub_unit_check.swift"), "ios_pr_check should include the calendar hub unit check")

print("PASS: walk list month calendar hub unit checks")
