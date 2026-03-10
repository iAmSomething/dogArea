import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트를 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/settings-privacy-center-ia-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let step2Doc = load("docs/first-walk-onboarding-step2-recording-sharing-v1.md")
let rivalDoc = load("docs/rival-tab-ux-usecase-spec-v1.md")
let mapSettingView = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let settingsSurfaceService = load("dogArea/Source/Domain/Profile/Services/SettingsProductSurfaceService.swift")

assertTrue(doc.contains("- Issue: #700"), "privacy center IA doc must reference issue #700")
assertTrue(doc.contains("프라이버시 센터"), "privacy center IA doc must define the hub title")
assertTrue(doc.contains("현재 공유 상태 카드"), "privacy center IA doc must include current status card")
assertTrue(doc.contains("즉시 비공개/재개 카드"), "privacy center IA doc must include immediate control card")
assertTrue(doc.contains("권한 상태 카드"), "privacy center IA doc must include permission card")
assertTrue(doc.contains("최근 공유 상태 카드"), "privacy center IA doc must include recent status card")
assertTrue(doc.contains("보존/삭제/문서 카드"), "privacy center IA doc must include retention/delete/documents card")
assertTrue(doc.contains("shortcut"), "privacy center IA doc must distinguish shortcut surfaces")
assertTrue(doc.contains("canonical route"), "privacy center IA doc must distinguish the canonical route")
assertTrue(doc.contains("공유 중"), "privacy center IA doc must define user-facing status vocabulary")
assertTrue(doc.contains("비공개"), "privacy center IA doc must define private status vocabulary")
assertTrue(doc.contains("권한 필요"), "privacy center IA doc must define permission-needed vocabulary")
assertTrue(step2Doc.contains("프라이버시 센터"), "onboarding step2 doc should route users into the privacy center")
assertTrue(rivalDoc.contains("설정에서 상세 관리"), "rival doc should preserve settings deep link intent")
assertTrue(mapSettingView.contains("title: \"위치 공유\""), "map settings should still expose a location sharing shortcut")
assertTrue(settingsSurfaceService.contains("legal.privacy"), "settings surface service should already expose privacy legal docs")
assertTrue(readme.contains("docs/settings-privacy-center-ia-v1.md"), "README must index privacy center IA doc")
assertTrue(prCheck.contains("swift scripts/settings_privacy_center_ia_unit_check.swift"), "ios_pr_check must run privacy center IA check")

print("PASS: settings privacy center IA unit checks")
