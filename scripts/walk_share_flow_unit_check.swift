import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let utility = load("dogArea/Source/ViewUtility.swift")
let walkDetail = load("dogArea/Views/MapView/WalkDetailView.swift")
let walkListDetail = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let walkListDetailActions = load("dogArea/Views/WalkListView/WalkListSubView/WalkListDetailActionSectionView.swift")
let shareDoc = load("docs/walk-share-flow-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(utility.contains("struct ActivityShareSheet"), "utility should expose share sheet wrapper")
assertTrue(utility.contains("enum WalkShareSummaryBuilder"), "utility should include share summary builder")
assertTrue(utility.contains("DogArea 산책 기록"), "share summary should include title")

assertTrue(walkDetail.contains("prepareShareItems"), "walk detail should prepare share payload")
assertTrue(walkDetail.contains("ActivityShareSheet(items: shareItems)"), "walk detail should open activity share sheet")
assertTrue(walkDetail.contains("공유 시트 열기"), "walk detail should expose share button")

assertTrue(walkListDetail.contains("prepareShareItems"), "walk list detail should prepare share payload")
assertTrue(walkListDetail.contains("ActivityShareSheet(items: shareItems)"), "walk list detail should open activity share sheet")
assertTrue(walkListDetailActions.contains("Text(\"공유하기\")"), "walk list detail action section should expose share button")

assertTrue(shareDoc.contains("카카오톡"), "share doc should include Kakao compatibility guidance")
assertTrue(shareDoc.contains("인스타그램"), "share doc should include Instagram compatibility guidance")

assertTrue(checklist.contains("산책 종료 직후 공유하기 동작"), "release checklist should include share flow regression check")
assertTrue(checklist.contains("지도 이미지 없음 상태에서도 텍스트 공유 가능"), "release checklist should include text-only share fallback")

print("PASS: walk share flow unit checks")
