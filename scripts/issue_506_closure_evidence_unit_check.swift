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

let evidence = load("docs/issue-506-closure-evidence-v1.md")
let designDoc = load("docs/home-mission-pet-context-snapshot-v1.md")
let service = load("dogArea/Source/Domain/Home/Services/HomeIndoorMissionPetContextSnapshotService.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let areaProgress = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift")
let indoorMissionFlow = load("dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(evidence.contains("#506"), "evidence doc should reference issue #506")
assertTrue(evidence.contains("PR: `#534`") || evidence.contains("PR `#534`"), "evidence doc should reference implementation PR #534")
assertTrue(evidence.contains("PASS"), "evidence doc should record PASS DoD results")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(
    designDoc.contains("`filter/reduce` 0회") || designDoc.contains("filter/reduce"),
    "design doc should record cache-hit savings"
)
assertTrue(service.contains("protocol HomeIndoorMissionPetContextSnapshotServicing"), "snapshot service protocol should exist")
assertTrue(service.contains("func canReuseSnapshot("), "snapshot service should expose cache-hit decision logic")
assertTrue(service.contains("func makeAggregationSnapshot("), "snapshot service should expose snapshot construction")
assertTrue(service.contains("let validThrough: TimeInterval?"), "snapshot model should retain the next invalidation boundary")
assertTrue(homeViewModel.contains("indoorMissionPetContextSnapshotService: HomeIndoorMissionPetContextSnapshotServicing"), "home view model should inject the snapshot service")
assertTrue(areaProgress.contains("updateIndoorMissionPetContextPolygonFingerprint(for: polygonList)"), "selected pet statistics should refresh the polygon fingerprint")
assertTrue(areaProgress.contains("indoorMissionPetContextAggregationSnapshot = nil"), "fingerprint change should invalidate the cached snapshot")
assertTrue(indoorMissionFlow.contains("if indoorMissionPetContextSnapshotService.canReuseSnapshot("), "indoor mission flow should reuse the snapshot when inputs match")
assertTrue(indoorMissionFlow.contains("indoorMissionPetContextAggregationSnapshot = snapshot"), "indoor mission flow should persist the computed snapshot")
assertTrue(indoorMissionFlow.contains("petName: selectedPet?.petName ?? \"강아지\""), "final pet context should still compose display data from the current selected pet")
assertTrue(readme.contains("docs/issue-506-closure-evidence-v1.md"), "README should index the issue #506 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_506_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #506 closure evidence check")

print("PASS: issue #506 closure evidence unit checks")
