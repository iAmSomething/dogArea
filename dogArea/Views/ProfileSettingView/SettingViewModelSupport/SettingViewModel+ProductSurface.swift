import Foundation

extension SettingViewModel {
    /// 설정 화면의 앱 설정/법적 문서/지원/앱 정보 표면 데이터를 최신 상태로 갱신합니다.
    func refreshProductSurface() async {
        let identity = resolvedAuthenticatedIdentity()
        let metadata = appMetadataService.loadMetadata(currentIdentity: identity)
        let notificationSummary = await notificationAuthorizationService.loadSummary()
        let privacyEntrySummary = privacyCenterService.loadEntrySummary(
            currentIdentity: identity,
            notificationSummary: notificationSummary
        )
        await MainActor.run {
            self.appMetadata = metadata
            self.notificationSettingsSummary = notificationSummary
            self.privacyCenterEntrySummary = privacyEntrySummary
        }
    }

    /// 현재 토큰 세션까지 유효한 사용자 식별 정보만 반환합니다.
    /// - Returns: 인증 토큰이 살아 있는 현재 사용자 식별 정보입니다. 없으면 `nil`입니다.
    private func resolvedAuthenticatedIdentity() -> AuthenticatedUserIdentity? {
        guard authSessionStore.currentTokenSession() != nil else {
            return nil
        }
        return authSessionStore.currentIdentity()
    }

    var appSettingsActions: [SettingsSurfaceAction] {
        settingsSurfaceCatalogService.appSettingsActions(notificationSummary: notificationSettingsSummary)
    }

    var legalDocumentActions: [SettingsSurfaceAction] {
        settingsSurfaceCatalogService.legalDocumentActions()
    }

    var supportActions: [SettingsSurfaceAction] {
        settingsSurfaceCatalogService.supportActions(metadata: appMetadata)
    }

    var appInfoRows: [SettingsInfoRow] {
        settingsSurfaceCatalogService.appInfoRows(metadata: appMetadata)
    }
}
