import Foundation
import UserNotifications
import UIKit

/// 설정 화면에 노출할 앱 메타데이터를 조립하는 계약입니다.
protocol SettingsAppMetadataProviding {
    /// 현재 앱 버전/빌드/지원 채널 메타데이터를 로드합니다.
    /// - Parameter currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    /// - Returns: 설정 화면 앱 정보/지원 섹션에 사용할 메타데이터입니다.
    func loadMetadata(currentIdentity: AuthenticatedUserIdentity?) -> SettingsAppMetadata
}

final class SettingsAppMetadataService: SettingsAppMetadataProviding {
    private let bundle: Bundle

    /// 앱 메타데이터 서비스 의존성을 구성합니다.
    /// - Parameter bundle: 버전/빌드/번들 식별자를 읽어올 번들입니다.
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// 현재 앱 버전/빌드/지원 채널 메타데이터를 로드합니다.
    /// - Parameter currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    /// - Returns: 설정 화면 앱 정보/지원 섹션에 사용할 메타데이터입니다.
    func loadMetadata(currentIdentity: AuthenticatedUserIdentity?) -> SettingsAppMetadata {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "-"
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.th.dogArea"
        return SettingsAppMetadata(
            version: version,
            build: build,
            bundleIdentifier: bundleIdentifier,
            supportEmail: "st939823@gmail.com",
            repositoryURL: URL(string: "https://github.com/iAmSomething/dogArea")!,
            bugReportURL: URL(string: "https://github.com/iAmSomething/dogArea/issues/new/choose")!,
            signedInEmail: currentIdentity?.email
        )
    }
}

/// 시스템 알림 권한 상태를 설정 화면용 요약으로 변환하는 계약입니다.
protocol SettingsNotificationAuthorizationProviding {
    /// 현재 시스템 알림 권한 상태를 로드합니다.
    /// - Returns: 설정 화면의 앱 설정 카드에서 사용할 알림 상태 요약입니다.
    func loadSummary() async -> SettingsNotificationSummary
}

final class SettingsNotificationAuthorizationService: SettingsNotificationAuthorizationProviding {
    private let notificationCenter: UNUserNotificationCenter

    /// 알림 권한 서비스 의존성을 구성합니다.
    /// - Parameter notificationCenter: 시스템 알림 권한 상태를 조회할 알림 센터입니다.
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    /// 현재 시스템 알림 권한 상태를 로드합니다.
    /// - Returns: 설정 화면의 앱 설정 카드에서 사용할 알림 상태 요약입니다.
    func loadSummary() async -> SettingsNotificationSummary {
        let settings = await loadNotificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return SettingsNotificationSummary(
                title: "알림 허용",
                subtitle: "퀘스트와 운영 안내를 정상적으로 받을 수 있어요.",
                badgeText: "허용됨",
                tone: .positive
            )
        case .denied:
            return SettingsNotificationSummary(
                title: "알림 꺼짐",
                subtitle: "iOS 설정 앱에서 다시 허용해야 알림을 받을 수 있어요.",
                badgeText: "꺼짐",
                tone: .warning
            )
        case .provisional:
            return SettingsNotificationSummary(
                title: "조용한 알림",
                subtitle: "알림이 조용히 전달되고 있어요. 설정 앱에서 노출 방식을 바꿀 수 있어요.",
                badgeText: "조용히 전달",
                tone: .positive
            )
        case .ephemeral:
            return SettingsNotificationSummary(
                title: "임시 허용",
                subtitle: "현재 세션 기준으로만 알림이 허용되어 있어요.",
                badgeText: "임시 허용",
                tone: .warning
            )
        case .notDetermined:
            return SettingsNotificationSummary(
                title: "알림 미설정",
                subtitle: "아직 알림 권한을 선택하지 않았어요. 설정 앱에서 다시 확인할 수 있어요.",
                badgeText: "미설정",
                tone: .warning
            )
        @unknown default:
            return .unknown
        }
    }

    /// `UNNotificationSettings`를 비동기로 읽어옵니다.
    /// - Returns: 시스템이 반환한 현재 알림 설정 스냅샷입니다.
    private func loadNotificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}

/// 설정 화면의 앱 설정/법적 문서/지원/앱 정보 섹션을 조립하는 계약입니다.
protocol SettingsSurfaceCatalogProviding {
    /// 앱 설정 섹션 액션을 생성합니다.
    /// - Parameter notificationSummary: 현재 시스템 알림 권한 상태 요약입니다.
    /// - Returns: 앱 설정 카드에서 렌더링할 액션 목록입니다.
    func appSettingsActions(notificationSummary: SettingsNotificationSummary) -> [SettingsSurfaceAction]
    /// 법적 문서 섹션 액션을 생성합니다.
    /// - Returns: 개인정보처리방침/이용약관/관련 문서 액션 목록입니다.
    func legalDocumentActions() -> [SettingsSurfaceAction]
    /// 지원/문의 섹션 액션을 생성합니다.
    /// - Parameter metadata: 현재 앱 메타데이터입니다.
    /// - Returns: 문의 메일/버그 리포트/저장소 링크 액션 목록입니다.
    func supportActions(metadata: SettingsAppMetadata) -> [SettingsSurfaceAction]
    /// 앱 정보 카드의 표시 행을 생성합니다.
    /// - Parameter metadata: 현재 앱 메타데이터입니다.
    /// - Returns: 버전/빌드/계정 상태 등 정보 행 목록입니다.
    func appInfoRows(metadata: SettingsAppMetadata) -> [SettingsInfoRow]
}

final class SettingsSurfaceCatalogService: SettingsSurfaceCatalogProviding {
    /// 앱 설정 섹션 액션을 생성합니다.
    /// - Parameter notificationSummary: 현재 시스템 알림 권한 상태 요약입니다.
    /// - Returns: 앱 설정 카드에서 렌더링할 액션 목록입니다.
    func appSettingsActions(notificationSummary: SettingsNotificationSummary) -> [SettingsSurfaceAction] {
        let settingsURL = URL(string: UIApplication.openSettingsURLString) ?? SettingsAppMetadata.placeholder.repositoryURL
        return [
            SettingsSurfaceAction(
                id: "app.notifications",
                title: notificationSummary.title,
                subtitle: notificationSummary.subtitle,
                iconSystemName: "bell.badge",
                badgeText: notificationSummary.badgeText,
                badgeTone: notificationSummary.tone,
                accessibilityIdentifier: "settings.app.notifications",
                target: .external(settingsURL)
            ),
            SettingsSurfaceAction(
                id: "app.systemSettings",
                title: "시스템 설정 열기",
                subtitle: "알림, 사진, 카메라 같은 권한을 iOS 설정 앱에서 직접 조정합니다.",
                iconSystemName: "gearshape",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.app.systemSettings",
                target: .external(settingsURL)
            )
        ]
    }

    /// 법적 문서 섹션 액션을 생성합니다.
    /// - Returns: 개인정보처리방침/이용약관/관련 문서 액션 목록입니다.
    func legalDocumentActions() -> [SettingsSurfaceAction] {
        [
            SettingsSurfaceAction(
                id: "legal.privacy",
                title: "개인정보처리방침",
                subtitle: "수집 항목, 사용 목적, 삭제 시점을 앱 안에서 바로 확인합니다.",
                iconSystemName: "lock.shield",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.legal.privacy",
                target: .document(privacyPolicyDocument())
            ),
            SettingsSurfaceAction(
                id: "legal.terms",
                title: "이용약관",
                subtitle: "서비스 이용 조건, 계정 책임, 베타 운영 전제를 확인합니다.",
                iconSystemName: "doc.text",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.legal.terms",
                target: .document(termsOfServiceDocument())
            ),
            SettingsSurfaceAction(
                id: "legal.licenses",
                title: "오픈소스/SDK 안내",
                subtitle: "앱을 구성하는 주요 프레임워크와 외부 서비스 사용 범위를 봅니다.",
                iconSystemName: "shippingbox",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.legal.licenses",
                target: .document(openSourceDocument())
            )
        ]
    }

    /// 지원/문의 섹션 액션을 생성합니다.
    /// - Parameter metadata: 현재 앱 메타데이터입니다.
    /// - Returns: 문의 메일/버그 리포트/저장소 링크 액션 목록입니다.
    func supportActions(metadata: SettingsAppMetadata) -> [SettingsSurfaceAction] {
        [
            SettingsSurfaceAction(
                id: "support.email",
                title: "개발자 문의 메일",
                subtitle: "기기 정보와 앱 버전을 포함한 문의 메일을 바로 작성합니다.",
                iconSystemName: "envelope",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.support.email",
                target: .external(makeSupportMailURL(metadata: metadata))
            ),
            SettingsSurfaceAction(
                id: "support.bug",
                title: "버그 리포트",
                subtitle: "GitHub 이슈 페이지로 이동해 재현 절차와 로그를 남깁니다.",
                iconSystemName: "ladybug",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.support.bug",
                target: .external(metadata.bugReportURL)
            ),
            SettingsSurfaceAction(
                id: "support.repository",
                title: "프로젝트 저장소",
                subtitle: "문서, 릴리즈 히스토리, 공개 이슈 현황을 확인합니다.",
                iconSystemName: "safari",
                badgeText: nil,
                badgeTone: nil,
                accessibilityIdentifier: "settings.support.repository",
                target: .external(metadata.repositoryURL)
            )
        ]
    }

    /// 앱 정보 카드의 표시 행을 생성합니다.
    /// - Parameter metadata: 현재 앱 메타데이터입니다.
    /// - Returns: 버전/빌드/계정 상태 등 정보 행 목록입니다.
    func appInfoRows(metadata: SettingsAppMetadata) -> [SettingsInfoRow] {
        [
            SettingsInfoRow(
                id: "appInfo.version",
                label: "앱 버전",
                value: metadata.version,
                accessibilityIdentifier: "settings.appInfo.version"
            ),
            SettingsInfoRow(
                id: "appInfo.build",
                label: "빌드",
                value: metadata.build,
                accessibilityIdentifier: "settings.appInfo.build"
            ),
            SettingsInfoRow(
                id: "appInfo.bundle",
                label: "번들 ID",
                value: metadata.bundleIdentifier,
                accessibilityIdentifier: "settings.appInfo.bundle"
            ),
            SettingsInfoRow(
                id: "appInfo.account",
                label: "현재 계정",
                value: metadata.signedInEmail ?? "게스트 모드",
                accessibilityIdentifier: "settings.appInfo.account"
            ),
            SettingsInfoRow(
                id: "appInfo.supportEmail",
                label: "지원 메일",
                value: metadata.supportEmail,
                accessibilityIdentifier: "settings.appInfo.supportEmail"
            )
        ]
    }

    /// 지원 문의에 사용할 `mailto:` URL을 생성합니다.
    /// - Parameter metadata: 현재 앱 버전/빌드/계정 정보를 포함한 메타데이터입니다.
    /// - Returns: 문의 메일 작성 화면으로 연결할 URL입니다.
    private func makeSupportMailURL(metadata: SettingsAppMetadata) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = metadata.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "DogArea 문의"),
            URLQueryItem(
                name: "body",
                value: "문의 내용을 작성해주세요.\n\n앱 버전: \(metadata.version)\n빌드: \(metadata.build)\n현재 계정: \(metadata.signedInEmail ?? "guest")\n번들 ID: \(metadata.bundleIdentifier)"
            )
        ]
        return components.url ?? metadata.repositoryURL
    }

    /// 개인정보처리방침 문서를 구성합니다.
    /// - Returns: 설정 화면 내부 시트에 표시할 개인정보처리방침 문서입니다.
    private func privacyPolicyDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "privacy",
            title: "개인정보처리방침",
            subtitle: "앱이 어떤 정보를 저장하고 어디에 사용하는지 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "privacy.scope",
                    title: "수집하는 정보",
                    body: "이 앱은 계정 식별 정보, 반려견 프로필, 산책 기록, 선택적으로 업로드한 프로필 이미지를 저장할 수 있습니다. 게스트 모드에서는 일부 정보가 기기 로컬 저장소에만 남을 수 있습니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.usage",
                    title: "사용 목적",
                    body: "수집 정보는 산책 기록 표시, 반려견 컨텍스트 유지, 클라우드 동기화, 위젯/시즌/라이벌 기능 제공, 고객 문의 대응을 위해 사용됩니다."
                ),
                SettingsDocumentSection(
                    id: "privacy.retention",
                    title: "보관과 삭제",
                    body: "회원 상태에서는 서버 동기화 데이터가 유지될 수 있으며, 설정 화면의 회원탈퇴를 실행하면 계정 데이터 삭제 절차가 시작됩니다. 게스트 데이터는 로그인 전까지 로컬 또는 임시 전송 경로에 머무를 수 있습니다."
                )
            ],
            footer: "보다 구체적인 운영/보안 세부사항은 프로젝트 저장소 문서와 향후 배포 채널 공지를 따릅니다."
        )
    }

    /// 이용약관 문서를 구성합니다.
    /// - Returns: 설정 화면 내부 시트에 표시할 이용약관 문서입니다.
    private func termsOfServiceDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "terms",
            title: "이용약관",
            subtitle: "베타 서비스 전제와 계정/콘텐츠 책임 범위를 요약합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "terms.beta",
                    title: "서비스 성격",
                    body: "DogArea는 기능 개선이 계속 진행되는 서비스입니다. 일부 기능, 점수, 표현 방식은 업데이트에 따라 바뀔 수 있습니다."
                ),
                SettingsDocumentSection(
                    id: "terms.account",
                    title: "계정 책임",
                    body: "사용자는 자신의 계정과 반려견 정보를 정확하게 유지해야 하며, 제3자 가장, 자동화 남용, 부정 사용은 제한될 수 있습니다."
                ),
                SettingsDocumentSection(
                    id: "terms.operations",
                    title: "운영 정책",
                    body: "운영 안정화, 보안, 모더레이션 사유로 특정 기능이 일시 중단되거나 접근 정책이 조정될 수 있습니다."
                )
            ],
            footer: "문의가 필요하면 설정 화면의 개발자 문의 메일 또는 버그 리포트 진입점을 사용해주세요."
        )
    }

    /// 오픈소스 및 외부 SDK 안내 문서를 구성합니다.
    /// - Returns: 설정 화면 내부 시트에 표시할 오픈소스/SDK 안내 문서입니다.
    private func openSourceDocument() -> SettingsDocumentContent {
        SettingsDocumentContent(
            id: "licenses",
            title: "오픈소스/SDK 안내",
            subtitle: "앱 구현에 사용되는 주요 프레임워크와 외부 서비스 범위를 안내합니다.",
            sections: [
                SettingsDocumentSection(
                    id: "licenses.apple",
                    title: "Apple Frameworks",
                    body: "SwiftUI, MapKit, WidgetKit, UserNotifications, WatchConnectivity 등 Apple 시스템 프레임워크를 사용합니다."
                ),
                SettingsDocumentSection(
                    id: "licenses.backend",
                    title: "Backend / Storage",
                    body: "Supabase 기반 인증, 데이터, Edge Function, Storage 경로를 사용합니다. 일부 과거 기능이나 보조 경로에는 Firebase 또는 기타 외부 서비스가 남아 있을 수 있습니다."
                ),
                SettingsDocumentSection(
                    id: "licenses.ai",
                    title: "선택 기능",
                    body: "캐리커처/이미지 생성, 날씨/추천 관련 일부 기능은 외부 API 또는 공급자 라우팅 정책의 영향을 받을 수 있습니다."
                )
            ],
            footer: "저장소와 배포 채널에 공개된 문서를 통해 보다 상세한 기술 스택과 운영 정책을 확인할 수 있습니다."
        )
    }
}
