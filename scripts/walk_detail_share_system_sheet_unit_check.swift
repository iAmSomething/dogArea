import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let utility = load("dogArea/Source/ViewUtility.swift")
let walkListDetail = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let walkDetail = load("dogArea/Views/MapView/WalkDetailView.swift")
let walkDetailViewModel = load("dogArea/Views/MapView/WalkDetailViewModel.swift")
let featureRegressionTests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let featureRegressionScript = load("scripts/run_feature_regression_ui_tests.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let readme = load("README.md")
let doc = load("docs/walk-detail-share-system-sheet-v1.md")

assertTrue(utility.contains("enum ActivitySharePresentationResult"), "share bridge should define canonical presentation results")
assertTrue(utility.contains("struct ActivityShareSheet"), "share bridge should exist")
assertTrue(utility.contains("@Binding var isPresented: Bool"), "share bridge should drive presentation with binding state")
assertTrue(utility.contains("host.present(controller, animated: true)"), "share bridge should present directly from host view controller")
assertTrue(utility.contains("controller.popoverPresentationController?.sourceView = host.view"), "share bridge should configure popover anchor")

assertTrue(walkListDetail.contains("ActivityShareSheet(isPresented: $showShareSheet, items: shareItems)"), "walk list detail should use direct share presenter")
assertTrue(walkListDetail.contains("walklist.detail.share.presenter.active"), "walk list detail should expose presenter marker for regression testing")
assertTrue(walkListDetail.contains("공유를 취소했어요."), "walk list detail should distinguish share cancellation")
assertTrue(walkListDetail.contains("공유 시트를 열지 못했어요. 다시 시도해주세요."), "walk list detail should distinguish share failure")

assertTrue(walkDetail.contains("ActivityShareSheet(isPresented: $detailViewModel.showShareSheet, items: shareItems)"), "walk detail should use direct share presenter")
assertTrue(walkDetailViewModel.contains("func handleSharePresentationResult"), "walk detail view model should handle share result taxonomy")
assertTrue(walkDetailViewModel.contains("공유를 완료했습니다"), "walk detail should retain success feedback")
assertTrue(walkDetailViewModel.contains("공유를 취소했습니다"), "walk detail should distinguish share cancellation")
assertTrue(walkDetailViewModel.contains("공유 시트를 열지 못했습니다. 다시 시도해주세요."), "walk detail should distinguish share failure")

assertTrue(featureRegressionTests.contains("testFeatureRegression_WalkListShareActionPresentsSystemSharePresenter"), "feature regression tests should cover system share presenter path")
assertTrue(featureRegressionScript.contains("testFeatureRegression_WalkListShareActionPresentsSystemSharePresenter"), "feature regression script should run share presenter regression")
assertTrue(iosPRCheck.contains("walk_detail_share_system_sheet_unit_check.swift"), "ios_pr_check should run share system sheet regression check")
assertTrue(readme.contains("docs/walk-detail-share-system-sheet-v1.md"), "README should index the share system sheet doc")
assertTrue(doc.contains("빈 모달"), "share system sheet doc should document blank modal prevention")

print("PASS: walk detail share system sheet unit checks")
