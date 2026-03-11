import Foundation

/// 프라이버시 삭제 요청의 현재 로컬 추적 상태를 정의합니다.
enum PrivacyDeletionRequestStatus: String, Codable, Equatable {
    case draftPrepared
    case handedOffToMailApp
    case submittedAwaitingReply
    case inquiryPrepared
}

/// 프라이버시 삭제 요청 초안이 어떤 채널로 전달됐는지 정의합니다.
enum PrivacyDeletionRequestChannel: String, Codable, Equatable {
    case inAppMailComposer
    case externalMailApp
    case copiedTemplate
}

/// 프라이버시 삭제 요청 흐름에서 마지막으로 기록한 로컬 추적 스냅샷입니다.
struct PrivacyDeletionRequestRecord: Codable, Equatable {
    let requestId: String
    let status: PrivacyDeletionRequestStatus
    let channel: PrivacyDeletionRequestChannel
    let signedInEmail: String?
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
    let lastActionSummary: String

    /// 새 삭제 요청 초안을 로컬 추적 레코드로 생성합니다.
    /// - Parameters:
    ///   - requestId: 사용자와 운영팀이 함께 참조할 삭제 요청 식별자입니다.
    ///   - channel: 초안을 사용자에게 전달한 채널입니다.
    ///   - signedInEmail: 현재 로그인 이메일입니다. 게스트면 `nil`입니다.
    ///   - date: 초안을 준비한 시각입니다.
    ///   - summary: 현재 단계의 사용자 설명 문구입니다.
    /// - Returns: `draftPrepared` 상태의 로컬 삭제 요청 레코드입니다.
    static func draftPrepared(
        requestId: String,
        channel: PrivacyDeletionRequestChannel,
        signedInEmail: String?,
        date: Date,
        summary: String
    ) -> PrivacyDeletionRequestRecord {
        PrivacyDeletionRequestRecord(
            requestId: requestId,
            status: .draftPrepared,
            channel: channel,
            signedInEmail: signedInEmail,
            createdAt: date.timeIntervalSince1970,
            updatedAt: date.timeIntervalSince1970,
            lastActionSummary: summary
        )
    }

    /// 외부 메일 앱으로 handoff된 삭제 요청 레코드를 생성합니다.
    /// - Parameters:
    ///   - requestId: 사용자와 운영팀이 함께 참조할 삭제 요청 식별자입니다.
    ///   - signedInEmail: 현재 로그인 이메일입니다. 게스트면 `nil`입니다.
    ///   - createdAt: 최초 초안 준비 시각입니다.
    ///   - date: 외부 메일 앱으로 handoff한 시각입니다.
    ///   - summary: 현재 단계의 사용자 설명 문구입니다.
    /// - Returns: `handedOffToMailApp` 상태의 로컬 삭제 요청 레코드입니다.
    static func handedOffToMailApp(
        requestId: String,
        signedInEmail: String?,
        createdAt: TimeInterval,
        date: Date,
        summary: String
    ) -> PrivacyDeletionRequestRecord {
        PrivacyDeletionRequestRecord(
            requestId: requestId,
            status: .handedOffToMailApp,
            channel: .externalMailApp,
            signedInEmail: signedInEmail,
            createdAt: createdAt,
            updatedAt: date.timeIntervalSince1970,
            lastActionSummary: summary
        )
    }

    /// 메일 전송 완료가 확인된 삭제 요청 레코드를 생성합니다.
    /// - Parameters:
    ///   - requestId: 사용자와 운영팀이 함께 참조할 삭제 요청 식별자입니다.
    ///   - channel: 전송 확인이 이뤄진 채널입니다.
    ///   - signedInEmail: 현재 로그인 이메일입니다. 게스트면 `nil`입니다.
    ///   - createdAt: 최초 초안 준비 시각입니다.
    ///   - date: 전송 완료를 기록한 시각입니다.
    ///   - summary: 현재 단계의 사용자 설명 문구입니다.
    /// - Returns: `submittedAwaitingReply` 상태의 로컬 삭제 요청 레코드입니다.
    static func submittedAwaitingReply(
        requestId: String,
        channel: PrivacyDeletionRequestChannel,
        signedInEmail: String?,
        createdAt: TimeInterval,
        date: Date,
        summary: String
    ) -> PrivacyDeletionRequestRecord {
        PrivacyDeletionRequestRecord(
            requestId: requestId,
            status: .submittedAwaitingReply,
            channel: channel,
            signedInEmail: signedInEmail,
            createdAt: createdAt,
            updatedAt: date.timeIntervalSince1970,
            lastActionSummary: summary
        )
    }

    /// 상태 문의 초안을 다시 연 현재 삭제 요청 레코드를 생성합니다.
    /// - Parameters:
    ///   - requestId: 사용자와 운영팀이 함께 참조할 삭제 요청 식별자입니다.
    ///   - channel: 문의 초안을 전달한 채널입니다.
    ///   - signedInEmail: 현재 로그인 이메일입니다. 게스트면 `nil`입니다.
    ///   - createdAt: 최초 초안 준비 시각입니다.
    ///   - date: 상태 문의 초안을 다시 연 시각입니다.
    ///   - summary: 현재 단계의 사용자 설명 문구입니다.
    /// - Returns: `inquiryPrepared` 상태의 로컬 삭제 요청 레코드입니다.
    static func inquiryPrepared(
        requestId: String,
        channel: PrivacyDeletionRequestChannel,
        signedInEmail: String?,
        createdAt: TimeInterval,
        date: Date,
        summary: String
    ) -> PrivacyDeletionRequestRecord {
        PrivacyDeletionRequestRecord(
            requestId: requestId,
            status: .inquiryPrepared,
            channel: channel,
            signedInEmail: signedInEmail,
            createdAt: createdAt,
            updatedAt: date.timeIntervalSince1970,
            lastActionSummary: summary
        )
    }
}

/// 프라이버시 센터 메인 화면에 노출할 삭제 요청 요약 카드 모델입니다.
struct SettingsPrivacyDeletionRequestSummary: Equatable {
    let title: String
    let subtitle: String
    let badgeText: String
    let tone: SettingsPrivacyTone
    let requestId: String?
    let footer: String
    let buttonTitle: String
}

/// 삭제 요청 메일 작성에 필요한 정규화 초안 모델입니다.
struct SettingsPrivacyDeletionRequestDraft: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case deletionRequest
        case statusInquiry
    }

    let id: String
    let kind: Kind
    let requestId: String
    let recipientEmail: String
    let subject: String
    let body: String
    let collectionItems: [String]
    let nextStepChecklist: [String]
    let fallbackURL: URL
}
