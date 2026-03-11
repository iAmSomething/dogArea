import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트를 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let canonicalDoc = load("docs/privacy-control-server-canonical-status-v1.md")
let privacyStore = load("dogArea/Source/UserDefaultsSupport/PrivacyControlStateStore.swift")
let privacyCenterViewModel = load("dogArea/Views/ProfileSettingView/SettingsPrivacyCenterViewModel.swift")
let privacyCenterService = load("dogArea/Source/Domain/Profile/Services/SettingsPrivacyCenterService.swift")
let nearbyPresenceService = load("dogArea/Source/Infrastructure/Supabase/Services/SupabasePresenceAndQuestServices.swift")
let nearbyPresenceProtocol = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let nearbyPresenceActionDispatcher = load("supabase/functions/nearby-presence/handlers/action_dispatcher.ts")
let nearbyPresenceVisibility = load("supabase/functions/nearby-presence/support/visibility.ts")
let nearbyPresenceTypes = load("supabase/functions/nearby-presence/support/types.ts")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalViewModel = load("dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let backendPRCheck = load("scripts/backend_pr_check.sh")
let readme = load("README.md")

assertTrue(canonicalDoc.contains("server-first"), "doc should freeze server-first priority")
assertTrue(canonicalDoc.contains("PrivacyControlServerSyncSnapshot"), "doc should define canonical snapshot model")
assertTrue(canonicalDoc.contains("serverConfirmed"), "doc should define serverConfirmed state")
assertTrue(canonicalDoc.contains("localPending"), "doc should define localPending state")
assertTrue(canonicalDoc.contains("serverFailed"), "doc should define serverFailed state")
assertTrue(canonicalDoc.contains("오프라인 보류"), "doc should define offline pending copy")

assertTrue(privacyStore.contains("struct PrivacyControlServerSyncSnapshot"), "privacy store should define server sync snapshot")
assertTrue(privacyStore.contains("func loadServerSyncSnapshot"), "privacy store should expose server snapshot load API")
assertTrue(privacyStore.contains("func persistServerSyncSnapshot"), "privacy store should expose server snapshot persist API")
assertTrue(privacyStore.contains("struct PrivacyControlVisibilityFailureDescriptor"), "privacy store should define shared failure descriptor")
assertTrue(privacyStore.contains("case authRefreshRequired"), "privacy store should support auth refresh required recent status")

assertTrue(nearbyPresenceProtocol.contains("func getVisibility(userId: String) async throws -> PrivacyVisibilitySyncResultDTO"), "nearby presence protocol should expose getVisibility")
assertTrue(nearbyPresenceProtocol.contains("func setVisibility(userId: String, enabled: Bool) async throws -> PrivacyVisibilitySyncResultDTO"), "nearby presence protocol should return canonical visibility result")
assertTrue(nearbyPresenceService.contains("\"action\": \"get_visibility\""), "nearby presence service should request get_visibility action")
assertTrue(nearbyPresenceService.contains("decodeVisibilityResult"), "nearby presence service should decode visibility envelope")
assertTrue(nearbyPresenceActionDispatcher.contains("get_visibility"), "nearby presence edge should dispatch get_visibility")
assertTrue(nearbyPresenceTypes.contains("\"get_visibility\""), "nearby presence edge action type should include get_visibility")
assertTrue(nearbyPresenceTypes.contains("user_id?: string"), "nearby presence edge request type should keep user_id alias for visibility compat")
assertTrue(nearbyPresenceVisibility.contains("handleGetVisibility"), "nearby presence edge should implement handleGetVisibility")
assertTrue(nearbyPresenceVisibility.contains("asUUIDOrNull(body.userId) ?? asUUIDOrNull(body.user_id)"), "nearby presence edge visibility path should accept both userId and user_id aliases")
assertTrue(nearbyPresenceVisibility.contains("visibility: visibility.visibility"), "nearby presence edge should return canonical visibility payload")

assertTrue(privacyCenterViewModel.contains("refreshCanonicalVisibilitySnapshot"), "privacy center view model should refresh canonical visibility snapshot")
assertTrue(privacyCenterViewModel.contains("PrivacyControlServerSyncSnapshot.localPending"), "privacy center view model should persist pending snapshot before server response")
assertTrue(privacyCenterService.contains("serverGroundedRecentStatusPresentation"), "privacy center service should prefer server-grounded recent status")
assertTrue(privacyCenterService.contains("badgeText: \"서버 반영 완료\""), "privacy center service should use user-facing server-confirmed copy")
assertTrue(privacyCenterService.contains("badgeText: \"기기 기준\""), "privacy center service should keep explicit local fallback copy")

assertTrue(mapViewModel.contains("persistPrivacyServerSyncPending"), "map view model should persist pending privacy snapshot")
assertTrue(mapViewModel.contains("persistPrivacyServerSyncConfirmed"), "map view model should persist confirmed privacy snapshot")
assertTrue(rivalViewModel.contains("persistPrivacyServerSyncPending"), "rival view model should persist pending privacy snapshot")
assertTrue(rivalViewModel.contains("persistPrivacyServerSyncConfirmed"), "rival view model should persist confirmed privacy snapshot")

assertTrue(iosPRCheck.contains("swift scripts/privacy_control_server_canonical_status_unit_check.swift"), "ios_pr_check should include canonical privacy server state check")
assertTrue(backendPRCheck.contains("swift scripts/privacy_control_server_canonical_status_unit_check.swift"), "backend_pr_check should include canonical privacy server state check")
assertTrue(readme.contains("docs/privacy-control-server-canonical-status-v1.md"), "README should index canonical privacy status doc")

print("PASS: privacy control server canonical status unit checks")
