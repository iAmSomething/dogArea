import Foundation

struct SettingsDocumentSection: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct SettingsDocumentContent: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let sections: [SettingsDocumentSection]
    let footer: String
}

enum SettingsSurfaceActionTarget: Equatable {
    case external(URL)
    case document(SettingsDocumentContent)
}

struct SettingsSurfaceAction: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let iconSystemName: String
    let badgeText: String?
    let badgeTone: SettingsPrivacyTone?
    let accessibilityIdentifier: String
    let target: SettingsSurfaceActionTarget
}

struct SettingsInfoRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let accessibilityIdentifier: String
}

struct SettingsNotificationSummary: Equatable {
    let title: String
    let subtitle: String
    let badgeText: String
    let tone: SettingsPrivacyTone

    static let unknown = SettingsNotificationSummary(
        title: "알림 설정 확인",
        subtitle: "iOS 설정 앱에서 퀘스트와 운영 알림을 조정할 수 있어요.",
        badgeText: "확인 필요",
        tone: .warning
    )
}

struct SettingsAppMetadata: Equatable {
    let version: String
    let build: String
    let bundleIdentifier: String
    let supportEmail: String
    let repositoryURL: URL
    let bugReportURL: URL
    let signedInEmail: String?

    static let placeholder = SettingsAppMetadata(
        version: "-",
        build: "-",
        bundleIdentifier: "com.th.dogArea",
        supportEmail: "st939823@gmail.com",
        repositoryURL: URL(string: "https://github.com/iAmSomething/dogArea")!,
        bugReportURL: URL(string: "https://github.com/iAmSomething/dogArea/issues/new/choose")!,
        signedInEmail: nil
    )
}
