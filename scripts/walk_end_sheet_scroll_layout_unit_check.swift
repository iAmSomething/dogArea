import Foundation

/// 조건이 거짓이면 즉시 실패 메시지를 출력하고 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 실패 시 출력할 메시지입니다.
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

let walkDetailView = load("dogArea/Views/MapView/WalkDetailView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let featureTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRunner = load("scripts/run_feature_regression_ui_tests.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(walkDetailView.contains("ScrollView"), "walk detail sheet should use a scroll container for smaller screens")
assertTrue(walkDetailView.contains(".safeAreaInset(edge: .bottom, spacing: 0)"), "walk detail sheet should pin bottom actions through a safe area inset layout")
assertTrue(walkDetailView.contains("screen.walkDetail.sheet"), "walk detail sheet should expose a root accessibility identifier")
assertTrue(walkDetailView.contains("walk.detail.shareSection"), "walk detail sheet should expose the share section identifier")
assertTrue(walkDetailView.contains("walk.detail.bottomActions"), "walk detail sheet should expose the bottom action container identifier")
assertTrue(walkDetailView.contains("walk.detail.openShareSheet"), "walk detail sheet should expose the share CTA identifier")
assertTrue(walkDetailView.contains("walk.detail.saveToPhotos"), "walk detail sheet should keep the photo save CTA identifier")
assertTrue(walkDetailView.contains("walk.detail.confirm"), "walk detail sheet should keep the confirm CTA identifier")
assertTrue(walkDetailView.contains(".frame(maxHeight: 300)"), "walk detail preview image should cap its height instead of expanding infinitely")
assertTrue(walkDetailView.contains(".safeAreaPadding(.bottom, 8)"), "walk detail bottom action inset should respect bottom safe area spacing")
assertTrue(walkDetailView.contains("Color.appTabScaffoldBackground.opacity(0.96)"), "walk detail bottom action surface should use an opaque scaffold background")
assertTrue(walkDetailView.contains(".presentationDetents([.large])") == false, "presentation detents should not be defined inside the walk detail view")
assertTrue(mapView.contains(".fullScreenCover(isPresented: $endWalkingViewPresented)"), "map should present the walk detail as a full-screen modal to prevent clipped bottom content on smaller screens")
assertTrue(mapView.contains("-UITest.MapWalkDetailPreviewRoute"), "map should expose a dedicated UI test preview route for the walk detail sheet")

assertTrue(featureTests.contains("testFeatureRegression_MapWalkDetailSheetScrollsAndKeepsBottomActionsVisible"), "feature regression tests should cover walk detail sheet scrolling and clipped bottom actions")
assertTrue(featureRunner.contains("testFeatureRegression_MapWalkDetailSheetScrollsAndKeepsBottomActionsVisible"), "feature regression runner should execute the walk detail sheet scrolling regression")
assertTrue(iosPRCheck.contains("swift scripts/walk_end_sheet_scroll_layout_unit_check.swift"), "ios_pr_check should run the walk detail sheet scroll layout unit check")

print("PASS: walk end sheet scroll layout unit checks")
