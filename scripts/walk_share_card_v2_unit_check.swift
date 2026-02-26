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
let specDoc = load("docs/walk-share-card-v2.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(utility.contains("enum WalkShareCardTemplateBuilder"), "share card template builder should exist")
assertTrue(utility.contains("canvasSize = CGSize(width: 1080, height: 1080)"), "share card template should render 1080x1080 canvas")
assertTrue(utility.contains("#dogarea  #산책기록"), "share card should include hashtag footer")

assertTrue(walkDetail.contains("WalkShareCardTemplateBuilder.build"), "walk detail should attach rendered share card")
assertTrue(walkListDetail.contains("WalkShareCardTemplateBuilder.build"), "walk list detail should attach rendered share card")

assertTrue(specDoc.contains("1080 x 1080"), "share card spec should define square resolution")
assertTrue(specDoc.contains("시스템 공유"), "share card spec should keep system share strategy")

assertTrue(checklist.contains("1080x1080"), "release checklist should include share card size check")

print("PASS: walk share card v2 unit checks")
