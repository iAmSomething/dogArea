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

let evidence = load("docs/issue-532-closure-evidence-v1.md")
let fixDoc = load("docs/watch-appicon-asset-fix-v1.md")
let contents = load("dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

let iconPath = root.appendingPathComponent("dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/watchAppIcon1024.png").path
let iconExists = FileManager.default.fileExists(atPath: iconPath)

assertTrue(evidence.contains("#532"), "evidence doc should reference issue #532")
assertTrue(evidence.contains("PR: `#559`") || evidence.contains("PR `#559`"), "evidence doc should reference implementation PR #559")
assertTrue(evidence.contains("watchAppIcon1024.png"), "evidence doc should reference the actual icon asset file")
assertTrue(evidence.contains("watchOS Simulator"), "evidence doc should mention the watch simulator verification path")
assertTrue(evidence.contains("종료 가능"), "evidence doc should conclude that the issue can close")
assertTrue(fixDoc.contains("watchAppIcon1024.png"), "watch app icon fix doc should describe the concrete asset")
assertTrue(contents.contains("\"filename\" : \"watchAppIcon1024.png\""), "contents json should reference watchAppIcon1024.png")
assertTrue(iconExists, "watch app icon png should exist in the asset catalog")
assertTrue(readme.contains("docs/issue-532-closure-evidence-v1.md"), "README should index the issue #532 closure evidence doc")
assertTrue(prCheck.contains("swift scripts/issue_532_closure_evidence_unit_check.swift"), "ios_pr_check should include the issue #532 closure evidence check")

print("PASS: issue #532 closure evidence unit checks")
