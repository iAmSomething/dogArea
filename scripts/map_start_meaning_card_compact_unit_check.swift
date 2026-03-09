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

let startButtonView = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let meaningCardView = load("dogArea/Views/MapView/MapSubViews/MapWalkStartMeaningCardView.swift")
let models = load("dogArea/Views/MapView/MapViewModelSupport/MapWalkStartPresentationModels.swift")
let service = load("dogArea/Source/Domain/Map/Services/MapWalkStartPresentationService.swift")
let doc = load("docs/map-start-meaning-card-compact-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(
    startButtonView.contains("private var idleHintCard: some View {\n        MapWalkStartMeaningCardView("),
    "start button should render the meaning helper as the inline idle hint card"
)
assertTrue(
    startButtonView.contains("if !viewModel.isWalking {\n                MapWalkStartMeaningCardView(") == false,
    "start button should no longer render a standalone top meaning card above the start deck"
)
assertTrue(meaningCardView.contains("map.walk.startMeaning.card"), "compact meaning card should expose an accessibility identifier")
assertTrue(meaningCardView.contains("map.walk.guide.reopen"), "compact meaning card should preserve guide reopen affordance")
assertTrue(meaningCardView.contains(".mapChromePill(.accent)"), "compact meaning card should use the compact accent pill style")
assertTrue(models.contains("let meaningTitle: String"), "presentation model should still expose title copy")
assertTrue(models.contains("let pillars: [MapWalkStartPillarPresentation]") == false, "presentation model should remove unused pillar payload")
assertTrue(models.contains("let secondaryFlowText: String") == false, "presentation model should remove unused secondary flow payload")
assertTrue(service.contains("meaningTitle: \"이 산책이 바로 기록돼요\""), "presentation service should provide compact start meaning title copy")
assertTrue(doc.contains("상단의 독립 대형 설명 카드는 제거한다"), "doc should record top card removal")
assertTrue(readme.contains("docs/map-start-meaning-card-compact-v1.md"), "README should index the compact map start card doc")
assertTrue(prCheck.contains("swift scripts/map_start_meaning_card_compact_unit_check.swift"), "ios_pr_check should include the compact map start card unit check")

print("PASS: map start meaning card compact checks")
