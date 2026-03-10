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

let doc = load("docs/privacy-control-recovery-retention-flow-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let privacyPolicyDoc = load("docs/rival-privacy-policy-stage1-v1.md")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalViewModelSharing = load("dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift")
let notificationView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")

assertTrue(doc.contains("- Issue: #704"), "privacy flow doc must reference issue #704")
assertTrue(doc.contains("세션 단위 즉시 비공개"), "privacy flow doc must define immediate private flow")
assertTrue(doc.contains("전역 공유 OFF/ON"), "privacy flow doc must define global sharing flow")
assertTrue(doc.contains("위치/알림 권한 상태 확인 및 복구"), "privacy flow doc must define permission recovery flow")
assertTrue(doc.contains("최근 공유 이력"), "privacy flow doc must define recent sharing history flow")
assertTrue(doc.contains("보존기간 안내 / 삭제 요청 / 관련 문서"), "privacy flow doc must define retention and delete flow")
assertTrue(doc.contains("지금부터 비공개예요"), "privacy flow doc must define immediate feedback copy")
assertTrue(doc.contains("오프라인"), "privacy flow doc must define offline fallback")
assertTrue(doc.contains("서버 지연"), "privacy flow doc must define server delay fallback")
assertTrue(doc.contains("회원 / 비회원 차이"), "privacy flow doc must distinguish member and guest states")
assertTrue(privacyPolicyDoc.contains("즉시 철회"), "existing privacy policy should preserve immediate revocation principle")
assertTrue(mapViewModel.contains("self.locationSharingEnabled.toggle()"), "map view model should still toggle location sharing directly")
assertTrue(mapViewModel.contains("preferenceStore.set(self.locationSharingEnabled, forKey: locationSharingKey)"), "map view model should persist sharing preference")
assertTrue(rivalViewModelSharing.contains("locationSharingEnabled = true"), "rival sharing flow should still support enabling sharing")
assertTrue(rivalViewModelSharing.contains("locationSharingEnabled = false"), "rival sharing flow should still support disabling sharing")
assertTrue(notificationView.contains("회원탈퇴"), "settings screen should already expose account deletion entry")
assertTrue(readme.contains("docs/privacy-control-recovery-retention-flow-v1.md"), "README must index privacy flow doc")
assertTrue(prCheck.contains("swift scripts/privacy_control_recovery_retention_unit_check.swift"), "ios_pr_check must run privacy control flow check")

print("PASS: privacy control recovery retention unit checks")
