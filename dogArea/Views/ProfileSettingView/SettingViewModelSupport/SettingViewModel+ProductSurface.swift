import Foundation

extension SettingViewModel {
    /// 설정 화면의 앱 설정/법적 문서/지원/앱 정보 표면 데이터를 최신 상태로 갱신합니다.
    func refreshProductSurface() async {
        let identity = authSessionStore.currentIdentity()
        let metadata = appMetadataService.loadMetadata(currentIdentity: identity)
        let notificationSummary = await notificationAuthorizationService.loadSummary()
        await MainActor.run {
            self.appMetadata = metadata
            self.notificationSettingsSummary = notificationSummary
        }
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
