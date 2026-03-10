import Foundation

extension SettingViewModel {
    /// 설정 탭에서 다시 열 첫 산책 가이드 프레젠테이션을 생성합니다.
    /// - Returns: 설정 재진입 맥락이 반영된 2단계 첫 산책 가이드 프레젠테이션입니다.
    func makeWalkGuidePresentation() -> WalkValueGuidePresentation {
        WalkValueGuidePresentationService().makePresentation(for: .settingsReentry)
    }

    /// 현재 저장된 포인트 기록 방식 라벨을 반환합니다.
    /// - Returns: 사용자에게 그대로 노출할 포인트 기록 방식 요약 문자열입니다.
    var walkGuideRecordModeTitle: String {
        let rawValue = WalkSessionMetadataStore.shared.walkPointRecordModeRawValue()
        return MapViewModel.WalkPointRecordMode(rawValue: rawValue)?.title ?? "포인트 수동 기록"
    }

    /// 현재 설정 탭에서 보여줄 공유 기본값 요약 문자열을 반환합니다.
    /// - Returns: 공유 기본값이 비공개/공개 중 어떤 상태로 시작하는지 설명하는 문자열입니다.
    var walkGuideSharingDefaultSummary: String {
        let userId = authSessionStore.currentIdentity()?.userId
        let isEnabled = DefaultPrivacyControlStateStore.shared.loadSharingEnabled(for: userId)
        return isEnabled ? "공유 기본값: 켜짐" : "공유 기본값: 비공개로 시작"
    }

    /// 첫 산책 가이드 Step2에서 선택한 설정값을 저장합니다.
    /// - Parameters:
    ///   - pointRecordModeRawValue: 저장할 포인트 기록 방식 원시 값입니다.
    ///   - sharingEnabled: 저장할 공유 기본값입니다.
    func applyWalkGuidePreferences(pointRecordModeRawValue: String, sharingEnabled: Bool) {
        WalkSessionMetadataStore.shared.setWalkPointRecordModeRawValue(pointRecordModeRawValue)
        let userId = authSessionStore.currentIdentity()?.userId
        DefaultPrivacyControlStateStore.shared.persistSharingEnabled(sharingEnabled, for: userId)
        refreshProductSurfaceSnapshot()
    }

    /// 첫 산책 가이드 Step2를 스킵할 때 안전 기본값을 저장합니다.
    func applyWalkGuideSafeDefaults() {
        applyWalkGuidePreferences(pointRecordModeRawValue: "manual", sharingEnabled: false)
    }

    /// 산책과 기록 카드에 필요한 즉시 반영 상태를 다시 읽습니다.
    /// - Returns: 없음. 현재 설정 카드와 프라이버시 요약에 필요한 published 상태를 갱신합니다.
    func refreshProductSurfaceSnapshot() {
        appMetadata = appMetadataService.loadMetadata(currentIdentity: authSessionStore.currentIdentity())
        privacyCenterEntrySummary = privacyCenterService.loadEntrySummary(
            currentIdentity: authSessionStore.currentTokenSession() == nil ? nil : authSessionStore.currentIdentity(),
            notificationSummary: notificationSettingsSummary
        )
    }
}
