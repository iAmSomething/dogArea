import Foundation

@MainActor
final class SettingsPrivacyCenterViewModel: ObservableObject {
    @Published private(set) var snapshot: SettingsPrivacyCenterSnapshot = .placeholder
    @Published var toastMessage: String? = nil

    let privacyCenterService: SettingsPrivacyCenterProviding
    let notificationAuthorizationService: SettingsNotificationAuthorizationProviding
    let appMetadataService: SettingsAppMetadataProviding
    let authSessionStore: AuthSessionStoreProtocol
    let nearbyService: NearbyPresenceServiceProtocol
    let privacyControlStateStore: PrivacyControlStateStoreProtocol

    /// 프라이버시 센터 뷰모델 의존성을 구성합니다.
    /// - Parameters:
    ///   - privacyCenterService: 프라이버시 센터 읽기 스냅샷을 조립하는 서비스입니다.
    ///   - notificationAuthorizationService: 시스템 알림 권한 상태를 읽는 서비스입니다.
    ///   - appMetadataService: 삭제 요청 메일/문서 링크 조합에 사용할 앱 메타데이터 서비스입니다.
    ///   - authSessionStore: 현재 인증 사용자 식별 정보를 읽는 저장소입니다.
    ///   - nearbyService: 공유 상태를 서버와 동기화하는 서비스입니다.
    ///   - privacyControlStateStore: 공유 기본값과 최근 상태 요약을 읽고 쓰는 저장소입니다.
    init(
        privacyCenterService: SettingsPrivacyCenterProviding = SettingsPrivacyCenterService(),
        notificationAuthorizationService: SettingsNotificationAuthorizationProviding = SettingsNotificationAuthorizationService(),
        appMetadataService: SettingsAppMetadataProviding = SettingsAppMetadataService(),
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        nearbyService: NearbyPresenceServiceProtocol = NearbyPresenceService(),
        privacyControlStateStore: PrivacyControlStateStoreProtocol = DefaultPrivacyControlStateStore.shared
    ) {
        self.privacyCenterService = privacyCenterService
        self.notificationAuthorizationService = notificationAuthorizationService
        self.appMetadataService = appMetadataService
        self.authSessionStore = authSessionStore
        self.nearbyService = nearbyService
        self.privacyControlStateStore = privacyControlStateStore
    }

    /// 프라이버시 센터 스냅샷을 최신 권한/세션 상태로 다시 읽습니다.
    func refresh() async {
        let notificationSummary = await notificationAuthorizationService.loadSummary()
        let currentIdentity = resolvedCurrentIdentity()
        let metadata = appMetadataService.loadMetadata(currentIdentity: currentIdentity)
        snapshot = privacyCenterService.loadSnapshot(
            currentIdentity: currentIdentity,
            notificationSummary: notificationSummary,
            metadata: metadata
        )
    }

    /// 현재 사용자 범위의 공유 기본값을 업데이트하고 서버 반영을 시도합니다.
    /// - Parameter enabled: 저장/반영할 공유 활성 상태입니다.
    func setSharingEnabled(_ enabled: Bool) async {
        guard let currentIdentity = resolvedCurrentIdentity() else {
            privacyControlStateStore.recordRecentStatus(
                kind: .guestLocked,
                detail: "로그인 후 공유 상태를 관리할 수 있어요.",
                for: nil,
                at: Date()
            )
            toastMessage = "로그인 후 공유 상태를 관리할 수 있어요."
            await refresh()
            return
        }

        privacyControlStateStore.persistSharingEnabled(enabled, for: currentIdentity.userId)
        privacyControlStateStore.recordRecentStatus(
            kind: enabled ? .sharingOn : .privateMode,
            detail: enabled
            ? "다시 공유를 시작했어요. 실제 반영은 산책 중일 때 이루어집니다."
            : "지금부터 비공개예요. 새 공유는 우선 중단됐어요.",
            for: currentIdentity.userId,
            at: Date()
        )
        await refresh()

        do {
            try await nearbyService.setVisibility(userId: currentIdentity.userId, enabled: enabled)
            toastMessage = enabled ? "다시 공유를 시작할 준비가 됐어요" : "지금부터 비공개예요"
            privacyControlStateStore.recordRecentStatus(
                kind: enabled ? .sharingOn : .privateMode,
                detail: enabled
                ? "서버 반영까지 확인했어요. 산책 중 익명 공유를 다시 사용할 수 있어요."
                : "서버 반영까지 확인했어요. 새 공유는 더 이상 반영되지 않아요.",
                for: currentIdentity.userId,
                at: Date()
            )
        } catch {
            let failure = failurePresentation(for: error, enabled: enabled)
            privacyControlStateStore.recordRecentStatus(
                kind: failure.kind,
                detail: failure.detail,
                for: currentIdentity.userId,
                at: Date()
            )
            toastMessage = failure.toastMessage
        }
        await refresh()
    }

    /// 토스트 메시지를 제거합니다.
    func clearToast() {
        toastMessage = nil
    }

    /// 현재 인증 토큰 세션이 유효한 사용자 식별 정보만 반환합니다.
    /// - Returns: 토큰 세션까지 확인된 현재 인증 사용자 식별 정보입니다. 없으면 `nil`입니다.
    private func resolvedCurrentIdentity() -> AuthenticatedUserIdentity? {
        guard authSessionStore.currentTokenSession() != nil else {
            return nil
        }
        return authSessionStore.currentIdentity()
    }

    /// 공유 상태 변경 실패를 사용자 문구/최근 상태 종류로 분류합니다.
    /// - Parameters:
    ///   - error: 서버 동기화 실패 원본 에러입니다.
    ///   - enabled: 사용자가 의도한 목표 공유 상태입니다.
    /// - Returns: 최근 상태 기록과 토스트에 사용할 분류 결과입니다.
    private func failurePresentation(
        for error: Error,
        enabled: Bool
    ) -> (kind: PrivacyControlRecentStatus.Kind, detail: String, toastMessage: String) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                let detail = enabled
                ? "연결이 없어 공유 시작 반영이 보류됐어요. 연결이 돌아오면 다시 확인해주세요."
                : "연결이 없어 비공개 반영이 늦을 수 있어요. 새 공유는 우선 멈췄어요."
                return (.offlinePending, detail, detail)
            default:
                break
            }
        }

        let detail = enabled
        ? "서버 반영이 조금 늦고 있어요. 잠시 후 다시 확인해주세요."
        : "비공개 요청의 서버 반영이 조금 늦고 있어요. 잠시 후 다시 확인해주세요."
        return (.serverDelayed, detail, detail)
    }
}
