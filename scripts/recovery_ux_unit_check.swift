import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@inline(__always)
func load(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fputs("FAIL: cannot load \(path)\n", stderr)
        exit(1)
    }
    return text
}

let doc = load("docs/recovery-ux-standard-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let presenter = load("dogArea/Views/GlobalViews/Recovery/RecoveryActionBanner.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let petProfile = load("dogArea/Views/SigningView/PetProfileSettingView.swift")
let authFlow = load("dogArea/Source/UserdefaultSetting.swift")

assertTrue(doc.contains("RecoveryActionBanner"), "recovery doc must define common presenter")
assertTrue(doc.contains("권한 거부"), "recovery doc must include permission scenario")
assertTrue(doc.contains("오프라인"), "recovery doc must include offline scenario")
assertTrue(doc.contains("인증 만료"), "recovery doc must include auth-expired scenario")

assertTrue(checklist.contains("설정 열기"), "release checklist must include settings action scenario")
assertTrue(checklist.contains("오프라인 모드"), "release checklist must include offline badge scenario")
assertTrue(checklist.contains("다시 로그인"), "release checklist must include re-login scenario")

assertTrue(presenter.contains("enum RecoveryIssueKind"), "presenter must define issue kind enum")
assertTrue(presenter.contains("snapshot-permission-denied"), "presenter should include permission snapshot preview")
assertTrue(presenter.contains("snapshot-network-offline"), "presenter should include offline snapshot preview")
assertTrue(presenter.contains("snapshot-auth-expired"), "presenter should include auth snapshot preview")

assertTrue(mapView.contains("RecoveryActionBanner"), "map view should present recovery banner")
assertTrue(mapView.contains("offlineModeBadge"), "map view should include offline mode badge")
assertTrue(mapView.contains("authFlow.startReauthenticationFlow"), "map view should route auth-expired action to re-login flow")
assertTrue(mapViewModel.contains("syncRecoveryToastMessage"), "map view model should expose online-recovery toast message")
assertTrue(mapViewModel.contains("retrySyncNow"), "map view model should provide one-tap retry action")
assertTrue(petProfile.contains("RecoveryActionBanner"), "pet profile flow should use common recovery banner")
assertTrue(authFlow.contains("func startReauthenticationFlow"), "auth flow should support explicit re-login action")

print("PASS: recovery ux unit checks")
