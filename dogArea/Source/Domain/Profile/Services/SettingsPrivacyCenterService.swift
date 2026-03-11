import Foundation
import CoreLocation

/// 설정 탭 프라이버시 센터의 읽기 모델을 조립하는 계약입니다.
protocol SettingsPrivacyCenterProviding {
    /// 설정 메인에서 사용할 프라이버시 센터 진입 요약을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - notificationSummary: 현재 알림 권한 상태 요약입니다.
    /// - Returns: 설정 메인 진입 카드에 표시할 요약 정보입니다.
    func loadEntrySummary(
        currentIdentity: AuthenticatedUserIdentity?,
        notificationSummary: SettingsNotificationSummary
    ) -> SettingsPrivacyEntrySummary

    /// 프라이버시 센터 전체 화면에 필요한 읽기 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - notificationSummary: 현재 알림 권한 상태 요약입니다.
    ///   - metadata: 삭제 요청 메일/문서 링크를 구성할 앱 메타데이터입니다.
    /// - Returns: 프라이버시 센터 전체 UI를 그릴 스냅샷입니다.
    func loadSnapshot(
        currentIdentity: AuthenticatedUserIdentity?,
        notificationSummary: SettingsNotificationSummary,
        metadata: SettingsAppMetadata
    ) -> SettingsPrivacyCenterSnapshot
}

final class SettingsPrivacyCenterService: SettingsPrivacyCenterProviding {
    private let privacyControlStateStore: PrivacyControlStateStoreProtocol
    private let moderationStore: RivalModerationStoreProtocol

    /// 프라이버시 센터 서비스 의존성을 구성합니다.
    /// - Parameters:
    ///   - privacyControlStateStore: 공유 기본값과 최근 상태 요약을 읽는 저장소입니다.
    ///   - moderationStore: 숨김/차단 익명코드 스냅샷을 읽는 저장소입니다.
    init(
        privacyControlStateStore: PrivacyControlStateStoreProtocol = DefaultPrivacyControlStateStore.shared,
        moderationStore: RivalModerationStoreProtocol = RivalModerationStore(preferenceStore: DefaultMapPreferenceStore.shared)
    ) {
        self.privacyControlStateStore = privacyControlStateStore
        self.moderationStore = moderationStore
    }

    /// 설정 메인에서 사용할 프라이버시 센터 진입 요약을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - notificationSummary: 현재 알림 권한 상태 요약입니다.
    /// - Returns: 설정 메인 진입 카드에 표시할 요약 정보입니다.
    func loadEntrySummary(
        currentIdentity: AuthenticatedUserIdentity?,
        notificationSummary: SettingsNotificationSummary
    ) -> SettingsPrivacyEntrySummary {
        let snapshot = loadSnapshot(
            currentIdentity: currentIdentity,
            notificationSummary: notificationSummary,
            metadata: .placeholder
        )
        return snapshot.entrySummary
    }

    /// 프라이버시 센터 전체 화면에 필요한 읽기 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - notificationSummary: 현재 알림 권한 상태 요약입니다.
    ///   - metadata: 삭제 요청 메일/문서 링크를 구성할 앱 메타데이터입니다.
    /// - Returns: 프라이버시 센터 전체 UI를 그릴 스냅샷입니다.
    func loadSnapshot(
        currentIdentity: AuthenticatedUserIdentity?,
        notificationSummary: SettingsNotificationSummary,
        metadata: SettingsAppMetadata
    ) -> SettingsPrivacyCenterSnapshot {
        let isGuest = currentIdentity == nil
        let sharingEnabled = privacyControlStateStore.loadSharingEnabled(for: currentIdentity?.userId)
        let serverSyncSnapshot = privacyControlStateStore.loadServerSyncSnapshot(for: currentIdentity?.userId)
        let locationStatus = locationPermissionPresentation(isGuest: isGuest)
        let notificationStatus = notificationPermissionPresentation(from: notificationSummary)
        let currentStatus = currentSharingStatusPresentation(
            currentIdentity: currentIdentity,
            locationPermission: locationStatus,
            sharingEnabled: sharingEnabled,
            serverSyncSnapshot: serverSyncSnapshot
        )
        let recentStatus = recentStatusPresentation(
            for: currentIdentity,
            sharingEnabled: sharingEnabled,
            serverSyncSnapshot: serverSyncSnapshot
        )
        let moderationSummary = moderationSummaryPresentation()
        let actionKind = primaryActionKind(
            currentIdentity: currentIdentity,
            locationPermission: locationStatus,
            sharingEnabled: sharingEnabled
        )
        let entrySummary = SettingsPrivacyEntrySummary(
            title: "프라이버시 센터",
            subtitle: currentStatus.subtitle,
            badgeText: currentStatus.badgeText,
            tone: currentStatus.tone
        )

        return SettingsPrivacyCenterSnapshot(
            isGuest: isGuest,
            entrySummary: entrySummary,
            currentStatus: currentStatus,
            controlTitle: "공유 제어",
            controlSubtitle: controlSubtitle(for: actionKind),
            primaryActionTitle: primaryActionTitle(for: actionKind),
            primaryActionKind: actionKind,
            locationPermission: locationStatus,
            notificationPermission: notificationStatus,
            recentStatus: recentStatus,
            moderationSummary: moderationSummary,
            documentActions: documentActions(metadata: metadata, moderationSummary: moderationSummary)
        )
    }

    /// 현재 위치 권한 상태를 사용자 문구로 변환합니다.
    /// - Parameter isGuest: 현재 화면이 게스트 상태인지 여부입니다.
    /// - Returns: 위치 권한 카드 행에 표시할 요약 정보입니다.
    private func locationPermissionPresentation(isGuest: Bool) -> SettingsPrivacyPermissionRowContent {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return SettingsPrivacyPermissionRowContent(
                title: "위치 권한이 허용되어 있어요",
                subtitle: "익명 공유를 다시 시작해도 현재 기기에서 위치 갱신을 이어갈 수 있어요.",
                badgeText: "허용됨",
                tone: .positive
            )
        case .notDetermined:
            return SettingsPrivacyPermissionRowContent(
                title: isGuest ? "위치 권한을 아직 선택하지 않았어요" : "위치 권한을 아직 선택하지 않았어요",
                subtitle: "공유를 다시 시작할 때 iOS 권한 요청이 나타날 수 있어요.",
                badgeText: "미설정",
                tone: .warning
            )
        case .denied, .restricted:
            return SettingsPrivacyPermissionRowContent(
                title: "위치 권한이 꺼져 있어요",
                subtitle: "iOS 설정 앱에서 권한을 다시 허용해야 공유를 다시 시작할 수 있어요.",
                badgeText: "권한 필요",
                tone: .warning
            )
        @unknown default:
            return SettingsPrivacyPermissionRowContent(
                title: "위치 권한 상태를 다시 확인해주세요",
                subtitle: "상태가 불분명해 공유를 바로 시작하지 않는 편이 안전해요.",
                badgeText: "확인 필요",
                tone: .warning
            )
        }
    }

    /// 시스템 알림 권한 상태를 프라이버시 센터 권한 카드 형식으로 변환합니다.
    /// - Parameter notificationSummary: 설정 화면용 알림 권한 요약입니다.
    /// - Returns: 알림 권한 카드 행에 표시할 요약 정보입니다.
    private func notificationPermissionPresentation(
        from notificationSummary: SettingsNotificationSummary
    ) -> SettingsPrivacyPermissionRowContent {
        return SettingsPrivacyPermissionRowContent(
            title: notificationSummary.title,
            subtitle: notificationSummary.subtitle,
            badgeText: notificationSummary.badgeText,
            tone: notificationSummary.tone
        )
    }

    /// 현재 인증/권한/공유 기본값을 바탕으로 현재 공유 상태 카드를 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - locationPermission: 위치 권한 상태 요약입니다.
    /// - Returns: 현재 공유 상태 카드에 표시할 요약 정보입니다.
    private func currentSharingStatusPresentation(
        currentIdentity: AuthenticatedUserIdentity?,
        locationPermission: SettingsPrivacyPermissionRowContent,
        sharingEnabled: Bool,
        serverSyncSnapshot: PrivacyControlServerSyncSnapshot?
    ) -> SettingsPrivacyStatusContent {
        guard currentIdentity != nil else {
            return SettingsPrivacyStatusContent(
                title: "로그인 후 공유 상태를 관리할 수 있어요",
                subtitle: "게스트 모드에서는 문서와 정책만 확인할 수 있고, 공유 제어는 로그인 후 사용할 수 있어요.",
                badgeText: "로그인 필요",
                tone: .neutral
            )
        }

        if let serverSyncSnapshot {
            switch serverSyncSnapshot.state {
            case .serverConfirmed:
                if serverSyncSnapshot.canonicalEnabled == true {
                    return SettingsPrivacyStatusContent(
                        title: "현재 서버 기준으로 공유 허용 상태예요",
                        subtitle: serverConfirmedSubtitle(
                            canonicalEnabled: true,
                            serverSyncSnapshot: serverSyncSnapshot,
                            sharingEnabled: sharingEnabled
                        ),
                        badgeText: "서버 반영 완료",
                        tone: .positive
                    )
                }

                return SettingsPrivacyStatusContent(
                    title: "현재 서버 기준으로 비공개예요",
                    subtitle: serverConfirmedSubtitle(
                        canonicalEnabled: false,
                        serverSyncSnapshot: serverSyncSnapshot,
                        sharingEnabled: sharingEnabled
                    ),
                    badgeText: "서버 반영 완료",
                    tone: .neutral
                )
            case .localPending:
                return SettingsPrivacyStatusContent(
                    title: serverSyncSnapshot.desiredEnabled
                        ? "이 기기에서는 공유 시작을 요청했어요"
                        : "이 기기에서는 비공개 전환을 요청했어요",
                    subtitle: localPendingSubtitle(for: serverSyncSnapshot),
                    badgeText: "서버 확인 대기",
                    tone: .warning
                )
            case .serverFailed:
                return SettingsPrivacyStatusContent(
                    title: currentStatusFailureTitle(for: serverSyncSnapshot),
                    subtitle: serverFailureSubtitle(for: serverSyncSnapshot),
                    badgeText: currentStatusFailureBadgeText(for: serverSyncSnapshot),
                    tone: currentStatusFailureTone(for: serverSyncSnapshot)
                )
            }
        }

        if locationPermission.badgeText == "권한 필요" && sharingEnabled {
            return SettingsPrivacyStatusContent(
                title: "현재 공유를 다시 시작하려면 위치 권한이 필요해요",
                subtitle: "이 기기 기본값은 공유 허용으로 저장되어 있지만, 서버 기준 상태를 새로 확인하려면 위치 권한부터 복구해야 해요.",
                badgeText: "권한 필요",
                tone: .warning
            )
        }

        if sharingEnabled {
            return SettingsPrivacyStatusContent(
                title: "이 기기에 저장된 기본값은 공유 허용이에요",
                subtitle: "아직 서버 기준 확인 기록이 없어 기기 기본값을 먼저 보여드리고 있어요.",
                badgeText: "기기 기준",
                tone: .positive
            )
        }

        return SettingsPrivacyStatusContent(
            title: "이 기기에 저장된 기본값은 비공개예요",
            subtitle: "아직 서버 기준 확인 기록이 없어 기기 기본값을 먼저 보여드리고 있어요.",
            badgeText: "기기 기준",
            tone: .neutral
        )
    }

    /// 최근 공유 상태 스냅샷을 사용자 문구로 변환합니다.
    /// - Parameter currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    /// - Returns: 최근 공유 상태 카드에 표시할 요약 정보입니다.
    private func recentStatusPresentation(
        for currentIdentity: AuthenticatedUserIdentity?,
        sharingEnabled: Bool,
        serverSyncSnapshot: PrivacyControlServerSyncSnapshot?
    ) -> SettingsPrivacyStatusContent {
        guard let currentIdentity else {
            return SettingsPrivacyStatusContent(
                title: "로그인 후 최근 공유 상태를 확인할 수 있어요",
                subtitle: "게스트 모드에서는 마지막 공유 상태와 오류 기록을 남기지 않아요.",
                badgeText: "로그인 필요",
                tone: .neutral
            )
        }

        if let serverSyncSnapshot {
            return serverGroundedRecentStatusPresentation(
                serverSyncSnapshot: serverSyncSnapshot,
                sharingEnabled: sharingEnabled
            )
        }

        guard let recentStatus = privacyControlStateStore.loadRecentStatus(for: currentIdentity.userId) else {
            return SettingsPrivacyStatusContent(
                title: "아직 서버 확인 기록이 없어요",
                subtitle: "처음 공유를 켜거나 끈 뒤에는 서버 반영 완료/지연/오프라인 보류 기록을 여기서 다시 확인할 수 있어요.",
                badgeText: "서버 기록 없음",
                tone: .neutral
            )
        }

        let relativeTime = relativeTimestampString(from: recentStatus.updatedAt)
        switch recentStatus.kind {
        case .guestLocked:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 로그인 필요",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "로그인 필요",
                tone: .neutral
            )
        case .privateMode:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 비공개 전환 완료",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "비공개",
                tone: .neutral
            )
        case .sharingOn:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 정상 반영",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "정상 반영",
                tone: .positive
            )
        case .permissionRequired:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 권한 복구 필요",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "권한 필요",
                tone: .warning
            )
        case .authRefreshRequired:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 서버 인증 확인 필요",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "확인 필요",
                tone: .warning
            )
        case .offlinePending:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 서버 확인 보류",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "오프라인 보류",
                tone: .warning
            )
        case .serverDelayed:
            return SettingsPrivacyStatusContent(
                title: "최근 상태: 서버 반영 지연",
                subtitle: "\(recentStatus.detail) · \(relativeTime)",
                badgeText: "서버 지연",
                tone: .critical
            )
        }
    }

    /// 숨김/차단 익명코드 스냅샷을 요약 카드 문구로 변환합니다.
    /// - Returns: 숨김/차단 요약 카드에 표시할 정보입니다.
    private func moderationSummaryPresentation() -> SettingsPrivacyModerationContent {
        let snapshot = moderationStore.loadSnapshot()
        let hiddenCount = snapshot.hiddenAliases.count
        let blockedCount = snapshot.blockedAliases.count
        let title = "숨김 \(hiddenCount)건 · 차단 \(blockedCount)건"
        let subtitle: String
        if hiddenCount == 0 && blockedCount == 0 {
            subtitle = "아직 숨김/차단한 익명코드가 없어요. 라이벌 탭에서 필요할 때만 관리하면 됩니다."
        } else {
            subtitle = "현재 저장된 숨김/차단 현황이에요. 자세한 관리와 신고는 라이벌 탭에서 이어서 진행할 수 있어요."
        }
        return SettingsPrivacyModerationContent(title: title, subtitle: subtitle)
    }

    /// 현재 상태에 맞는 주행동 버튼 종류를 결정합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - locationPermission: 위치 권한 상태 요약입니다.
    ///   - sharingEnabled: 현재 공유 기본값입니다.
    /// - Returns: 프라이버시 센터 주행동이 수행해야 할 액션 종류입니다.
    private func primaryActionKind(
        currentIdentity: AuthenticatedUserIdentity?,
        locationPermission: SettingsPrivacyPermissionRowContent,
        sharingEnabled: Bool
    ) -> SettingsPrivacyPrimaryActionKind {
        guard currentIdentity != nil else { return .openSignIn }
        if locationPermission.badgeText == "권한 필요" {
            return .openSystemSettings
        }
        return sharingEnabled ? .disableSharing : .enableSharing
    }

    /// 주행동 종류에 맞는 설명 문구를 생성합니다.
    /// - Parameter actionKind: 현재 프라이버시 센터가 노출해야 할 주행동 종류입니다.
    /// - Returns: 주행동 카드의 보조 설명 텍스트입니다.
    private func controlSubtitle(for actionKind: SettingsPrivacyPrimaryActionKind) -> String {
        switch actionKind {
        case .openSignIn:
            return "로그인 후 공유 상태를 관리하고 최근 반영 기록을 확인할 수 있어요."
        case .openSystemSettings:
            return "위치 권한을 복구한 뒤 다시 돌아오면 공유를 이어서 켤 수 있어요."
        case .enableSharing:
            return "공유는 기본 OFF로 유지되고, 다시 켜더라도 산책 중일 때만 반영돼요."
        case .disableSharing:
            return "지금 바로 비공개로 바꾸면 새 공유는 중단되고, 이미 집계된 일부 익명 신호만 잠시 남을 수 있어요."
        }
    }

    /// 주행동 종류에 맞는 버튼 라벨을 생성합니다.
    /// - Parameter actionKind: 현재 프라이버시 센터가 노출해야 할 주행동 종류입니다.
    /// - Returns: 버튼 라벨 텍스트입니다.
    private func primaryActionTitle(for actionKind: SettingsPrivacyPrimaryActionKind) -> String {
        switch actionKind {
        case .openSignIn:
            return "로그인/회원가입 열기"
        case .openSystemSettings:
            return "설정 열기"
        case .enableSharing:
            return "다시 공유 시작"
        case .disableSharing:
            return "지금 바로 비공개"
        }
    }

    /// 서버 기준 최근 상태 카드를 canonical snapshot으로부터 생성합니다.
    /// - Parameters:
    ///   - serverSyncSnapshot: 현재 사용자 범위에 저장된 canonical server snapshot입니다.
    ///   - sharingEnabled: 현재 기기에 저장된 공유 기본값입니다.
    /// - Returns: 최근 상태 카드에 바로 사용할 사용자 문구 모델입니다.
    private func serverGroundedRecentStatusPresentation(
        serverSyncSnapshot: PrivacyControlServerSyncSnapshot,
        sharingEnabled: Bool
    ) -> SettingsPrivacyStatusContent {
        switch serverSyncSnapshot.state {
        case .serverConfirmed:
            let requestText = requestTimestampPhrase(from: serverSyncSnapshot.requestedAt)
            let serverText = serverTimestampPhrase(from: serverSyncSnapshot.serverUpdatedAt ?? serverSyncSnapshot.resultRecordedAt)
            let title = serverSyncSnapshot.requestedAt == nil
                ? "현재 서버 기준 상태를 확인했어요"
                : "마지막 요청이 서버에 반영됐어요"
            let subtitle = [
                requestText,
                "서버 기준은 \(canonicalVisibilityLabel(for: serverSyncSnapshot.canonicalEnabled ?? sharingEnabled))",
                serverText
            ]
                .compactMap { $0 }
                .joined(separator: " · ")
            return SettingsPrivacyStatusContent(
                title: title,
                subtitle: subtitle,
                badgeText: "서버 반영 완료",
                tone: .positive
            )
        case .localPending:
            let requestText = requestTimestampPhrase(from: serverSyncSnapshot.requestedAt) ?? "방금 요청했어요"
            let canonicalText = canonicalVisibilityLabel(for: serverSyncSnapshot.canonicalEnabled)
            return SettingsPrivacyStatusContent(
                title: "마지막 요청은 서버 확인 대기 중이에요",
                subtitle: "\(requestText) · 현재 확인된 서버 기준은 \(canonicalText)이며, 이 기기 요청은 아직 확인 전이에요.",
                badgeText: "서버 확인 대기",
                tone: .warning
            )
        case .serverFailed:
            let requestText = requestTimestampPhrase(from: serverSyncSnapshot.requestedAt) ?? "최근 요청 시각을 기록하지 못했어요"
            let failureText = serverFailureSummary(for: serverSyncSnapshot)
            let canonicalText = canonicalVisibilityLabel(for: serverSyncSnapshot.canonicalEnabled)
            return SettingsPrivacyStatusContent(
                title: "마지막 요청이 서버에서 확인되지 않았어요",
                subtitle: "\(requestText) · \(failureText) · 마지막 서버 기준은 \(canonicalText)예요.",
                badgeText: currentStatusFailureBadgeText(for: serverSyncSnapshot),
                tone: currentStatusFailureTone(for: serverSyncSnapshot)
            )
        }
    }

    /// 서버 반영 완료 상태 카드의 보조 문구를 생성합니다.
    /// - Parameters:
    ///   - canonicalEnabled: 서버가 보유한 현재 canonical visibility 상태입니다.
    ///   - serverSyncSnapshot: 현재 사용자 범위의 canonical server snapshot입니다.
    ///   - sharingEnabled: 현재 기기에 저장된 공유 기본값입니다.
    /// - Returns: 현재 상태 카드에 표시할 보조 설명 문자열입니다.
    private func serverConfirmedSubtitle(
        canonicalEnabled: Bool,
        serverSyncSnapshot: PrivacyControlServerSyncSnapshot,
        sharingEnabled: Bool
    ) -> String {
        let serverText = serverTimestampPhrase(from: serverSyncSnapshot.serverUpdatedAt ?? serverSyncSnapshot.resultRecordedAt)
            ?? "서버 시각을 아직 받지 못했어요."
        if serverSyncSnapshot.desiredEnabled != canonicalEnabled || sharingEnabled != canonicalEnabled {
            return "\(serverText) 이 기기 기본값과 서버 기준이 잠시 달랐지만, 지금은 서버 기준을 우선 보여드리고 있어요."
        }
        return "\(serverText) 프라이버시 센터는 이 값을 현재 서버 기준 상태로 사용합니다."
    }

    /// 로컬 요청 대기 상태 카드의 보조 문구를 생성합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 pending canonical snapshot입니다.
    /// - Returns: 현재 상태 카드에 표시할 보조 설명 문자열입니다.
    private func localPendingSubtitle(for serverSyncSnapshot: PrivacyControlServerSyncSnapshot) -> String {
        let requestText = requestTimestampPhrase(from: serverSyncSnapshot.requestedAt) ?? "방금 요청했어요."
        let canonicalText = canonicalVisibilityLabel(for: serverSyncSnapshot.canonicalEnabled)
        return "\(requestText) 현재 확인된 서버 기준은 \(canonicalText)이며, 이 기기 요청은 아직 확인 전이에요."
    }

    /// 서버 확인 실패 상태 카드 제목을 생성합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 failure canonical snapshot입니다.
    /// - Returns: 현재 상태 카드 제목입니다.
    private func currentStatusFailureTitle(
        for serverSyncSnapshot: PrivacyControlServerSyncSnapshot
    ) -> String {
        switch serverSyncSnapshot.failureCategory {
        case .authRequired:
            return "서버 인증 상태를 다시 확인해야 해요"
        case .offline:
            return "이 기기 요청은 저장했지만 서버 확인이 보류 중이에요"
        case .serverDelayed, .unknown, .none:
            return "서버 확인이 지연되고 있어요"
        }
    }

    /// 서버 확인 실패 상태 카드 배지 문구를 생성합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 failure canonical snapshot입니다.
    /// - Returns: 현재 상태 카드 배지 문자열입니다.
    private func currentStatusFailureBadgeText(
        for serverSyncSnapshot: PrivacyControlServerSyncSnapshot
    ) -> String {
        switch serverSyncSnapshot.failureCategory {
        case .authRequired:
            return "확인 필요"
        case .offline:
            return "오프라인 보류"
        case .serverDelayed, .unknown, .none:
            return "서버 지연"
        }
    }

    /// 서버 확인 실패 상태 카드 강조 톤을 생성합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 failure canonical snapshot입니다.
    /// - Returns: 현재 상태 카드 강조 톤입니다.
    private func currentStatusFailureTone(
        for serverSyncSnapshot: PrivacyControlServerSyncSnapshot
    ) -> SettingsPrivacyTone {
        switch serverSyncSnapshot.failureCategory {
        case .authRequired, .offline:
            return .warning
        case .serverDelayed, .unknown, .none:
            return .critical
        }
    }

    /// 서버 확인 실패 상태 카드의 보조 문구를 생성합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 failure canonical snapshot입니다.
    /// - Returns: 현재 상태 카드에 표시할 보조 설명 문자열입니다.
    private func serverFailureSubtitle(
        for serverSyncSnapshot: PrivacyControlServerSyncSnapshot
    ) -> String {
        let requestText = requestTimestampPhrase(from: serverSyncSnapshot.requestedAt) ?? "최근 요청 시각을 기록하지 못했어요."
        let failureText = serverFailureSummary(for: serverSyncSnapshot)
        let canonicalText = canonicalVisibilityLabel(for: serverSyncSnapshot.canonicalEnabled)
        return "\(requestText) \(failureText) 마지막 서버 기준은 \(canonicalText)예요."
    }

    /// canonical visibility 상태를 사용자용 짧은 문구로 변환합니다.
    /// - Parameter enabled: 서버가 보유한 현재 공유 상태입니다. 없으면 `nil`입니다.
    /// - Returns: 프라이버시 센터에 표시할 상태 라벨 문자열입니다.
    private func canonicalVisibilityLabel(for enabled: Bool?) -> String {
        switch enabled {
        case true:
            return "공유 허용"
        case false:
            return "비공개"
        case nil:
            return "아직 모름"
        }
    }

    /// 마지막 요청 시각을 짧은 설명 문구로 변환합니다.
    /// - Parameter timestamp: epoch seconds 기준 요청 시각입니다. 없으면 `nil`입니다.
    /// - Returns: 최근 요청 시각을 설명하는 사용자 문구입니다.
    private func requestTimestampPhrase(from timestamp: TimeInterval?) -> String? {
        guard let timestamp else { return nil }
        return "마지막 요청은 \(relativeTimestampString(from: timestamp))에 기록됐어요."
    }

    /// 서버 반영 시각을 짧은 설명 문구로 변환합니다.
    /// - Parameter timestamp: epoch seconds 기준 서버 반영 시각입니다.
    /// - Returns: 서버 반영 시각을 설명하는 사용자 문구입니다.
    private func serverTimestampPhrase(from timestamp: TimeInterval?) -> String? {
        guard let timestamp else { return nil }
        return "서버 확인은 \(relativeTimestampString(from: timestamp))에 끝났어요."
    }

    /// failure snapshot을 사용자용 짧은 실패 설명으로 변환합니다.
    /// - Parameter serverSyncSnapshot: 현재 사용자 범위의 failure canonical snapshot입니다.
    /// - Returns: 오프라인/인증/지연 상태를 설명하는 짧은 사용자 문구입니다.
    private func serverFailureSummary(
        for serverSyncSnapshot: PrivacyControlServerSyncSnapshot
    ) -> String {
        let suffix = serverSyncSnapshot.failureCode.map { "(\($0))" } ?? nil
        let body: String
        switch serverSyncSnapshot.failureCategory {
        case .offline:
            body = "오프라인이라 서버 확인이 미뤄졌어요"
        case .authRequired:
            body = "서버 인증 상태를 다시 확인해야 해요"
        case .serverDelayed:
            body = "서버 반영 응답이 늦고 있어요"
        case .unknown, .none:
            body = "서버 확인 결과를 아직 확정하지 못했어요"
        }
        if let suffix {
            return "\(body) \(suffix)"
        }
        return body
    }

    /// 프라이버시 센터 하단 문서/요청 액션 목록을 구성합니다.
    /// - Parameters:
    ///   - metadata: 앱 메타데이터입니다.
    ///   - moderationSummary: 숨김/차단 요약 정보입니다.
    /// - Returns: 보존/삭제/문서 카드에서 사용할 액션 목록입니다.
    private func documentActions(
        metadata: SettingsAppMetadata,
        moderationSummary: SettingsPrivacyModerationContent
    ) -> [SettingsSurfaceAction] {
        [
            SettingsSurfaceAction(
                id: "privacy.retentionGuide",
                title: "보존 기간 안내",
                subtitle: "공유 데이터가 어떤 주기로 정리되는지 사용자 기준으로 다시 확인합니다.",
                iconSystemName: "clock.arrow.circlepath",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.privacyCenter.retention",
                target: .document(retentionDocument())
            ),
            SettingsSurfaceAction(
                id: "privacy.deleteRequest",
                title: "삭제 요청 메일 보내기",
                subtitle: "개인정보 삭제 요청 또는 처리 상태 문의를 메일로 바로 접수합니다.",
                iconSystemName: "trash",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.privacyCenter.deleteRequest",
                target: .external(deleteRequestMailURL(metadata: metadata))
            ),
            SettingsSurfaceAction(
                id: "privacy.moderationSummary",
                title: "숨김/차단 현황",
                subtitle: moderationSummary.subtitle,
                iconSystemName: "hand.raised",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.privacyCenter.moderation",
                target: .document(moderationSummaryDocument(summary: moderationSummary))
            ),
            SettingsSurfaceAction(
                id: "privacy.policy",
                title: "개인정보처리방침",
                subtitle: "수집 항목과 사용 목적, 삭제 흐름을 요약해서 다시 확인합니다.",
                iconSystemName: "lock.shield",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.privacyCenter.privacyPolicy",
                target: .document(privacyPolicyDocument())
            ),
            SettingsSurfaceAction(
                id: "privacy.terms",
                title: "이용약관",
                subtitle: "공유 기능과 계정 사용 책임 범위를 약관 요약으로 다시 확인합니다.",
                iconSystemName: "doc.text",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.privacyCenter.terms",
                target: .document(termsDocument())
            )
        ]
    }

    /// 보존 기간 요약 문서를 구성합니다.
    /// - Returns: 프라이버시 센터 시트에서 표시할 보존 기간 안내 문서입니다.
    private func retentionDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "privacy.retentionGuide",
            title: "보존 기간 안내",
            subtitle: "공유 데이터가 언제까지 남고 어떻게 정리되는지 사용자 기준으로 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "privacy.retention.live",
                    title: "실시간 공유 상태",
                    body: "실시간 공유 상태는 오래 남겨두지 않고 정책에 따라 정리됩니다. 즉시 비공개로 바꿔도 이미 집계된 일부 익명 신호는 잠시 남을 수 있지만, 새 공유는 바로 중단됩니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.retention.history",
                    title: "최근 상태 요약",
                    body: "앱은 최근 공유 성공/보류/지연 상태를 기기 기준으로 짧게 보여줍니다. 이 기록은 사용자가 마지막 상태를 이해하도록 돕기 위한 요약입니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.retention.delete",
                    title: "삭제 요청",
                    body: "정책/문의가 필요하면 삭제 요청 메일을 통해 접수할 수 있습니다. 즉시 삭제가 아니라 접수 후 처리 상태를 확인하는 흐름으로 이해하면 됩니다."
                )
            ],
            footer: "보다 구체적인 운영 보존 기준은 앱의 개인정보처리방침과 운영 문서를 따릅니다."
        )
    }

    /// 숨김/차단 현황 안내 문서를 구성합니다.
    /// - Parameter summary: 현재 숨김/차단 요약 정보입니다.
    /// - Returns: 프라이버시 센터 시트에서 표시할 현황 요약 문서입니다.
    private func moderationSummaryDocument(
        summary: SettingsPrivacyModerationContent
    ) -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "privacy.moderationSummary",
            title: "숨김/차단 현황",
            subtitle: "현재 기기에 저장된 익명코드 숨김/차단 상태를 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "privacy.moderation.counts",
                    title: summary.title,
                    body: summary.subtitle
                ),
                SettingsDocumentSection(
                    id: "privacy.moderation.route",
                    title: "관리 위치",
                    body: "자세한 숨김/차단/신고 동작은 라이벌 탭에서 계속 관리합니다. 프라이버시 센터는 현재 관계를 다시 확인하는 canonical summary 역할을 합니다."
                )
            ],
            footer: "익명코드 기준 숨김/차단만 로컬에 저장되며, 정밀 좌표는 이 문서에 포함되지 않습니다."
        )
    }

    /// 개인정보처리방침 요약 문서를 구성합니다.
    /// - Returns: 프라이버시 센터 시트에서 표시할 개인정보처리방침 문서입니다.
    private func privacyPolicyDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "privacy.policy",
            title: "개인정보처리방침",
            subtitle: "공유 기능 기준으로 어떤 정보가 어떻게 처리되는지 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "privacy.policy.collection",
                    title: "수집과 표시",
                    body: "익명 공유 기능은 정밀 좌표 대신 정책에 맞게 축약된 상태와 집계를 사용합니다. 닉네임이나 강아지 이름을 그대로 노출하지 않는 방향을 기본으로 합니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.policy.control",
                    title: "사용자 제어",
                    body: "공유 상태는 설정 탭의 프라이버시 센터, 지도 설정, 라이벌 탭 shortcut에서 바꿀 수 있으며, detailed control은 프라이버시 센터를 canonical route로 봅니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.policy.delete",
                    title: "삭제와 문의",
                    body: "정책 문의나 삭제 요청은 설정 탭의 관련 문서/문의 경로를 통해 접수할 수 있습니다."
                )
            ],
            footer: "정식 배포 전 운영 정책은 업데이트될 수 있으며, 최신 기준은 앱/저장소 공지를 따릅니다."
        )
    }

    /// 이용약관 요약 문서를 구성합니다.
    /// - Returns: 프라이버시 센터 시트에서 표시할 이용약관 문서입니다.
    private func termsDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "privacy.terms",
            title: "이용약관",
            subtitle: "공유 기능과 계정 사용 책임 범위를 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "privacy.terms.scope",
                    title: "기능 범위",
                    body: "근처 공유/라이벌/핫스팟 기능은 베타 운영 중이며, 정책과 표현 방식은 서비스 안정화에 따라 조정될 수 있습니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.terms.abuse",
                    title: "남용 방지",
                    body: "기록 조작, 자동화 남용, 우회 시도는 제한될 수 있으며, 일부 상태는 보호 정책으로 축약되거나 제외될 수 있습니다."
                )
            ],
            footer: "약관/정책 문의는 개발자 문의 메일 또는 삭제 요청 메일 경로를 사용해주세요."
        )
    }

    /// 삭제 요청 메일 URL을 구성합니다.
    /// - Parameter metadata: 앱 버전/빌드/계정 정보를 포함한 메타데이터입니다.
    /// - Returns: 개인정보 삭제 요청 메일 작성 화면으로 연결할 URL입니다.
    private func deleteRequestMailURL(metadata: SettingsAppMetadata) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = metadata.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "DogArea 개인정보 삭제 요청"),
            URLQueryItem(
                name: "body",
                value: "삭제 요청 또는 처리 상태 문의 내용을 작성해주세요.\n\n앱 버전: \(metadata.version)\n빌드: \(metadata.build)\n현재 계정: \(metadata.signedInEmail ?? "guest")"
            )
        ]
        return components.url ?? metadata.repositoryURL
    }

    /// 최근 상태 시각을 `n분 전` 형식의 짧은 문구로 변환합니다.
    /// - Parameter timestamp: 기준이 되는 epoch seconds 시각입니다.
    /// - Returns: 사용자에게 표시할 상대 시각 문자열입니다.
    private func relativeTimestampString(from timestamp: TimeInterval) -> String {
        let delta = max(0, Int(Date().timeIntervalSince1970 - timestamp))
        if delta < 60 {
            return "방금 전"
        }
        if delta < 3_600 {
            return "\(max(1, delta / 60))분 전"
        }
        if delta < 86_400 {
            return "\(max(1, delta / 3_600))시간 전"
        }
        return "\(max(1, delta / 86_400))일 전"
    }
}
