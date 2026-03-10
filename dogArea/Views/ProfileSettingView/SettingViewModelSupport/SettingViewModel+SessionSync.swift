import Foundation
import Combine

extension SettingViewModel {
    /// 선택 반려견 변경 알림을 구독해 설정 화면 상태를 최신 선택값과 동기화합니다.
    func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadUserInfo()
            }
            .store(in: &cancellables)
    }

    /// 인증 세션 변경 알림을 구독해 설정 화면 상태를 현재 세션과 즉시 동기화합니다.
    func bindAuthSessionSync() {
        NotificationCenter.default.publisher(for: .authSessionDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleAuthSessionDidChange()
            }
            .store(in: &cancellables)
    }

    /// 세션 유효성에 따라 설정 화면 캐시를 갱신하거나 초기화합니다.
    private func handleAuthSessionDidChange() {
        guard authSessionStore.currentTokenSession() != nil else {
            userInfo = nil
            selectedPet = nil
            selectedPetId = ""
            seasonProfileSummary = nil
            appMetadata = appMetadataService.loadMetadata(currentIdentity: authSessionStore.currentIdentity())
            privacyCenterEntrySummary = privacyCenterService.loadEntrySummary(
                currentIdentity: nil,
                notificationSummary: notificationSettingsSummary
            )
            return
        }
        reloadUserInfo()
        Task {
            await refreshProductSurface()
        }
    }

    /// 현재 저장된 시즌 진행 현황을 다시 읽어 설정 화면 상태에 반영합니다.
    func reloadSeasonProfileSummary() {
        seasonProfileSummary = seasonProfileSummaryService.loadSummary()
    }
}
