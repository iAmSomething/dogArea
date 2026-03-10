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

let doc = load("docs/first-walk-onboarding-step2-recording-sharing-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let metadataStore = load("dogArea/Source/WalkSessionMetadataStore.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSetting = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")

assertTrue(doc.contains("- Issue: #706"), "step2 doc must reference issue #706")
assertTrue(doc.contains("기록 방식"), "step2 doc must include record mode axis")
assertTrue(doc.contains("공유 기본값"), "step2 doc must include sharing default axis")
assertTrue(doc.contains("기본값: `수동 포인트 기록`"), "step2 doc must freeze manual as the safe default")
assertTrue(doc.contains("기본값: `OFF`"), "step2 doc must freeze sharing OFF as the safe default")
assertTrue(doc.contains("스킵 시 적용값"), "step2 doc must define skip behavior")
assertTrue(doc.contains("권한 요청과 설정 선택의 분리"), "step2 doc must separate permission timing from preference choice")
assertTrue(doc.contains("설정 탭 > 산책과 기록 > 포인트 기록 방식"), "step2 doc must define the record mode re-entry path")
assertTrue(doc.contains("설정 탭 > 프라이버시 센터 > 공유 기본값"), "step2 doc must define the sharing re-entry path")
assertTrue(doc.contains("#700/#704"), "step2 doc must connect the sharing route to the privacy center follow-up")
assertTrue(metadataStore.contains("defaults.string(forKey: Key.walkPointRecordMode) ?? \"manual\""), "code default for point record mode should remain manual")
assertTrue(mapViewModel.contains("let sharingPreference = preferenceStore.bool(forKey: locationSharingKey, default: false)"), "code default for sharing should remain false")
assertTrue(mapSetting.contains("viewModel.walkPointRecordMode.title"), "map settings should expose the point record mode toggle")
assertTrue(mapSetting.contains("title: \"위치 공유\""), "map settings should expose the location sharing toggle")
assertTrue(readme.contains("docs/first-walk-onboarding-step2-recording-sharing-v1.md"), "README must index step2 doc")
assertTrue(prCheck.contains("swift scripts/onboarding_step2_recording_sharing_unit_check.swift"), "ios_pr_check must run step2 onboarding check")

print("PASS: onboarding step2 recording/sharing unit checks")
