import Foundation

/// 프라이버시 삭제 요청 흐름의 사용자 문구/메일 초안/요약 모델을 조립하는 계약입니다.
protocol SettingsPrivacyDeletionRequestProviding {
    /// 프라이버시 센터 메인 화면에 노출할 삭제 요청 요약 카드를 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - record: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 삭제 요청 카드에 사용할 요약 모델입니다.
    func loadSummary(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        record: PrivacyDeletionRequestRecord?
    ) -> SettingsPrivacyDeletionRequestSummary

    /// 새 삭제 요청 메일 초안을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - existingRecord: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 요청 ID와 수집 항목이 포함된 삭제 요청 메일 초안입니다.
    func makeDeletionRequestDraft(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        existingRecord: PrivacyDeletionRequestRecord?
    ) -> SettingsPrivacyDeletionRequestDraft

    /// 기존 요청 ID를 사용한 상태 문의 메일 초안을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - record: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 기존 요청 ID를 인용하는 상태 문의 메일 초안입니다.
    func makeStatusInquiryDraft(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        record: PrivacyDeletionRequestRecord
    ) -> SettingsPrivacyDeletionRequestDraft
}

final class SettingsPrivacyDeletionRequestService: SettingsPrivacyDeletionRequestProviding {
    private static let requestIdPrefix = "DEL"

    /// 프라이버시 센터 메인 화면에 노출할 삭제 요청 요약 카드를 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - record: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 삭제 요청 카드에 사용할 요약 모델입니다.
    func loadSummary(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        record: PrivacyDeletionRequestRecord?
    ) -> SettingsPrivacyDeletionRequestSummary {
        guard let record else {
            let guestNote = currentIdentity == nil
                ? "게스트 모드에서도 요청 ID를 만들 수 있지만, 로그인 상태에서 요청하면 계정 확인이 더 빨라져요."
                : "요청 ID를 먼저 만든 뒤, 어떤 정보가 함께 전송되는지 확인하고 접수를 시작할 수 있어요."
            return SettingsPrivacyDeletionRequestSummary(
                title: "삭제 요청을 아직 시작하지 않았어요",
                subtitle: "단순 메일 링크가 아니라 요청 ID와 다음 단계 설명이 붙은 접수 흐름으로 안내합니다.",
                badgeText: "접수 전",
                tone: .neutral,
                requestId: nil,
                footer: guestNote,
                buttonTitle: "삭제 요청 흐름 열기"
            )
        }

        switch record.status {
        case .draftPrepared:
            return SettingsPrivacyDeletionRequestSummary(
                title: "삭제 요청 ID를 만들었어요",
                subtitle: "아직 메일 전송 확인은 없어요. 요청 내용을 다시 확인한 뒤 메일 작성 단계로 이어가세요.",
                badgeText: "초안 준비됨",
                tone: .warning,
                requestId: record.requestId,
                footer: "현재 상태: \(record.lastActionSummary)",
                buttonTitle: "삭제 요청 이어서 보기"
            )
        case .handedOffToMailApp:
            return SettingsPrivacyDeletionRequestSummary(
                title: "메일 앱에서 전송만 마치면 돼요",
                subtitle: "앱은 요청 ID를 보관하고 있어요. 외부 메일 앱에서 보내기 후 다시 돌아와 상태를 확인하세요.",
                badgeText: "전송 확인 대기",
                tone: .warning,
                requestId: record.requestId,
                footer: "현재 상태: \(record.lastActionSummary)",
                buttonTitle: "전송 단계 다시 열기"
            )
        case .submittedAwaitingReply:
            return SettingsPrivacyDeletionRequestSummary(
                title: "삭제 요청 접수 회신을 기다리는 중이에요",
                subtitle: "운영팀은 같은 요청 ID로 회신합니다. 상태 문의는 같은 ID를 인용해서 다시 보낼 수 있어요.",
                badgeText: "회신 대기",
                tone: .positive,
                requestId: record.requestId,
                footer: "접수 후 24시간 안에 첫 회신을 기대할 수 있어요.",
                buttonTitle: "삭제 요청 상세 보기"
            )
        case .inquiryPrepared:
            return SettingsPrivacyDeletionRequestSummary(
                title: "상태 문의 초안을 다시 준비했어요",
                subtitle: "같은 요청 ID를 인용해서 현재 처리 상태를 다시 물을 수 있어요.",
                badgeText: "문의 준비됨",
                tone: .neutral,
                requestId: record.requestId,
                footer: "처리 완료 전까지는 같은 요청 ID를 계속 사용합니다.",
                buttonTitle: "삭제 요청 정보 보기"
            )
        }
    }

    /// 새 삭제 요청 메일 초안을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - existingRecord: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 요청 ID와 수집 항목이 포함된 삭제 요청 메일 초안입니다.
    func makeDeletionRequestDraft(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        existingRecord: PrivacyDeletionRequestRecord?
    ) -> SettingsPrivacyDeletionRequestDraft {
        let requestId = existingRecord?.requestId ?? makeRequestID()
        let collectionItems = collectionItems(currentIdentity: currentIdentity, metadata: metadata, requestId: requestId)
        let body = [
            "[DogArea 삭제 요청]",
            "요청 ID: \(requestId)",
            "현재 계정: \(currentIdentity?.email ?? "guest")",
            "앱 버전: \(metadata.version)",
            "빌드: \(metadata.build)",
            "번들 ID: \(metadata.bundleIdentifier)",
            "",
            "삭제 요청 범위:",
            "- 계정/프로필 관련 데이터 확인 요청",
            "- 산책 기록/익명 공유 데이터 삭제 가능 범위 확인 요청",
            "",
            "추가 설명:",
            "- 어떤 데이터를 우선 확인해야 하는지 적어주세요.",
            "- 회신은 같은 메일 스레드에서 부탁드립니다."
        ].joined(separator: "\n")

        return SettingsPrivacyDeletionRequestDraft(
            id: "deletion.\(requestId)",
            kind: .deletionRequest,
            requestId: requestId,
            recipientEmail: metadata.supportEmail,
            subject: "[DogArea 삭제요청][\(requestId)] 개인정보 삭제 요청",
            body: body,
            collectionItems: collectionItems,
            nextStepChecklist: [
                "메일 전송 후 앱은 요청 ID와 접수 대기 상태를 보관합니다.",
                "운영팀은 같은 요청 ID로 24시간 안에 첫 회신을 보냅니다.",
                "추가 확인이 필요하면 같은 요청 ID로 상태 문의를 다시 보낼 수 있습니다."
            ],
            fallbackURL: makeMailURL(
                recipientEmail: metadata.supportEmail,
                subject: "[DogArea 삭제요청][\(requestId)] 개인정보 삭제 요청",
                body: body,
                fallback: metadata.repositoryURL
            )
        )
    }

    /// 기존 요청 ID를 사용한 상태 문의 메일 초안을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - record: 현재 사용자 범위에 저장된 삭제 요청 추적 레코드입니다.
    /// - Returns: 기존 요청 ID를 인용하는 상태 문의 메일 초안입니다.
    func makeStatusInquiryDraft(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        record: PrivacyDeletionRequestRecord
    ) -> SettingsPrivacyDeletionRequestDraft {
        let body = [
            "[DogArea 삭제 요청 상태 문의]",
            "요청 ID: \(record.requestId)",
            "현재 계정: \(currentIdentity?.email ?? record.signedInEmail ?? "guest")",
            "첫 초안 시각: \(absoluteTimestampString(from: record.createdAt))",
            "최근 로컬 상태: \(record.lastActionSummary)",
            "",
            "문의 내용:",
            "- 현재 처리 상태를 알려주세요.",
            "- 추가 확인이 필요한 항목이 있으면 같은 스레드에서 안내 부탁드립니다."
        ].joined(separator: "\n")

        return SettingsPrivacyDeletionRequestDraft(
            id: "inquiry.\(record.requestId)",
            kind: .statusInquiry,
            requestId: record.requestId,
            recipientEmail: metadata.supportEmail,
            subject: "[DogArea 삭제요청][\(record.requestId)] 처리 상태 문의",
            body: body,
            collectionItems: collectionItems(currentIdentity: currentIdentity, metadata: metadata, requestId: record.requestId),
            nextStepChecklist: [
                "같은 요청 ID를 유지하면 운영팀이 이전 삭제 요청과 연결해서 확인합니다.",
                "문의 후에도 처리 완료 전까지 회신은 같은 스레드에서 이어집니다."
            ],
            fallbackURL: makeMailURL(
                recipientEmail: metadata.supportEmail,
                subject: "[DogArea 삭제요청][\(record.requestId)] 처리 상태 문의",
                body: body,
                fallback: metadata.repositoryURL
            )
        )
    }

    /// 삭제 요청 본문에 포함할 수집 항목 목록을 생성합니다.
    /// - Parameters:
    ///   - currentIdentity: 현재 인증된 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    ///   - metadata: 앱 버전/빌드/지원 채널 메타데이터입니다.
    ///   - requestId: 현재 삭제 요청 식별자입니다.
    /// - Returns: 시트에서 사용자에게 안내할 수집 항목 목록입니다.
    private func collectionItems(
        currentIdentity: AuthenticatedUserIdentity?,
        metadata: SettingsAppMetadata,
        requestId: String
    ) -> [String] {
        [
            "요청 ID: \(requestId)",
            "현재 계정: \(currentIdentity?.email ?? "guest")",
            "앱 버전: \(metadata.version) (\(metadata.build))",
            "번들 ID: \(metadata.bundleIdentifier)"
        ]
    }

    /// 삭제 요청용 canonical request ID를 생성합니다.
    /// - Returns: 운영팀과 사용자가 함께 참조할 삭제 요청 ID입니다.
    private func makeRequestID() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let prefix = formatter.string(from: Date())
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).uppercased()
        return "\(Self.requestIdPrefix)-\(prefix)-\(suffix)"
    }

    /// 메일 앱 fallback에 사용할 `mailto:` URL을 생성합니다.
    /// - Parameters:
    ///   - recipientEmail: 수신 메일 주소입니다.
    ///   - subject: 메일 제목입니다.
    ///   - body: 메일 본문입니다.
    ///   - fallback: `mailto:` 생성에 실패했을 때 대신 열 URL입니다.
    /// - Returns: 메일 앱 또는 대체 외부 경로 URL입니다.
    private func makeMailURL(
        recipientEmail: String,
        subject: String,
        body: String,
        fallback: URL
    ) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url ?? fallback
    }

    /// epoch seconds 시각을 절대 시각 문자열로 변환합니다.
    /// - Parameter timestamp: 변환할 epoch seconds 시각입니다.
    /// - Returns: 사용자/운영 문맥에서 읽기 쉬운 절대 시각 문자열입니다.
    private func absoluteTimestampString(from timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
