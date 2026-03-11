import Foundation

/// 프라이버시 센터의 상태 배지/강조 톤을 정의합니다.
enum SettingsPrivacyTone: Equatable {
    case neutral
    case positive
    case warning
    case critical
}

/// 설정 메인에서 프라이버시 센터 진입 카드에 노출할 요약 정보입니다.
struct SettingsPrivacyEntrySummary: Equatable {
    let title: String
    let subtitle: String
    let badgeText: String
    let tone: SettingsPrivacyTone

    static let placeholder = SettingsPrivacyEntrySummary(
        title: "프라이버시 센터",
        subtitle: "공유 상태, 권한, 보존/삭제 요청을 한 곳에서 관리해요.",
        badgeText: "확인",
        tone: .neutral
    )
}

/// 프라이버시 센터의 카드형 상태 표현에 사용할 텍스트/배지 모델입니다.
struct SettingsPrivacyStatusContent: Equatable {
    let title: String
    let subtitle: String
    let badgeText: String
    let tone: SettingsPrivacyTone
}

/// 프라이버시 센터 권한 카드의 단일 행을 표현합니다.
struct SettingsPrivacyPermissionRowContent: Equatable {
    let title: String
    let subtitle: String
    let badgeText: String
    let tone: SettingsPrivacyTone
}

/// 숨김/차단 관계 요약 카드의 본문 모델입니다.
struct SettingsPrivacyModerationContent: Equatable {
    let title: String
    let subtitle: String
}

/// 프라이버시 센터의 주행동 버튼 의미를 정의합니다.
enum SettingsPrivacyPrimaryActionKind: Equatable {
    case openSignIn
    case openSystemSettings
    case enableSharing
    case disableSharing
}

/// 프라이버시 센터 전체 화면을 구성하는 읽기 전용 스냅샷입니다.
struct SettingsPrivacyCenterSnapshot: Equatable {
    let isGuest: Bool
    let entrySummary: SettingsPrivacyEntrySummary
    let currentStatus: SettingsPrivacyStatusContent
    let controlTitle: String
    let controlSubtitle: String
    let primaryActionTitle: String
    let primaryActionKind: SettingsPrivacyPrimaryActionKind
    let locationPermission: SettingsPrivacyPermissionRowContent
    let notificationPermission: SettingsPrivacyPermissionRowContent
    let recentStatus: SettingsPrivacyStatusContent
    let moderationSummary: SettingsPrivacyModerationContent
    let deletionRequestSummary: SettingsPrivacyDeletionRequestSummary
    let documentActions: [SettingsSurfaceAction]

    static let placeholder = SettingsPrivacyCenterSnapshot(
        isGuest: true,
        entrySummary: .placeholder,
        currentStatus: SettingsPrivacyStatusContent(
            title: "로그인 후 공유 상태를 관리할 수 있어요",
            subtitle: "공유 상태, 권한, 보존/삭제 요청을 한 곳에서 확인합니다.",
            badgeText: "로그인 필요",
            tone: .neutral
        ),
        controlTitle: "공유 제어",
        controlSubtitle: "로그인 후 공유 상태를 직접 관리할 수 있어요.",
        primaryActionTitle: "로그인/회원가입 열기",
        primaryActionKind: .openSignIn,
        locationPermission: SettingsPrivacyPermissionRowContent(
            title: "위치 권한 상태를 불러오는 중이에요",
            subtitle: "설정 앱에서 권한을 다시 조정할 수 있어요.",
            badgeText: "확인 중",
            tone: .neutral
        ),
        notificationPermission: SettingsPrivacyPermissionRowContent(
            title: "알림 권한 상태를 불러오는 중이에요",
            subtitle: "상태 변경 알림을 놓치지 않도록 권한을 확인해주세요.",
            badgeText: "확인 중",
            tone: .neutral
        ),
        recentStatus: SettingsPrivacyStatusContent(
            title: "최근 공유 상태를 준비하는 중이에요",
            subtitle: "잠시 후 마지막 공유 상태와 오류 여부를 보여드려요.",
            badgeText: "로딩 중",
            tone: .neutral
        ),
        moderationSummary: SettingsPrivacyModerationContent(
            title: "숨김/차단 현황을 준비하는 중이에요",
            subtitle: "잠시 후 요약 정보를 불러옵니다."
        ),
        deletionRequestSummary: SettingsPrivacyDeletionRequestSummary(
            title: "삭제 요청 흐름을 준비하는 중이에요",
            subtitle: "잠시 후 요청 ID, 접수 안내, 상태 문의 경로를 보여드려요.",
            badgeText: "로딩 중",
            tone: .neutral,
            requestId: nil,
            footer: "삭제 요청은 일반 문의와 분리된 전용 흐름으로 다룹니다.",
            buttonTitle: "삭제 요청 흐름 열기"
        ),
        documentActions: []
    )
}
