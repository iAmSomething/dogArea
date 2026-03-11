import Foundation
import UIKit

@MainActor
final class SettingsPrivacyDeletionRequestSheetViewModel: ObservableObject {
    @Published private(set) var summary: SettingsPrivacyDeletionRequestSummary = .placeholder
    @Published private(set) var latestRecord: PrivacyDeletionRequestRecord? = nil
    @Published var toastMessage: String? = nil

    let deletionRequestService: SettingsPrivacyDeletionRequestProviding
    let deletionRequestStore: PrivacyDeletionRequestStoreProtocol
    let appMetadataService: SettingsAppMetadataProviding
    let authSessionStore: AuthSessionStoreProtocol

    /// 삭제 요청 전용 시트 뷰모델 의존성을 구성합니다.
    /// - Parameters:
    ///   - deletionRequestService: 요청 ID, 메일 초안, 카드 요약을 조립하는 서비스입니다.
    ///   - deletionRequestStore: 삭제 요청 로컬 추적 상태를 읽고 쓰는 저장소입니다.
    ///   - appMetadataService: 버전/빌드/지원 메일 메타데이터를 읽는 서비스입니다.
    ///   - authSessionStore: 현재 인증 사용자 식별 정보를 읽는 저장소입니다.
    init(
        deletionRequestService: SettingsPrivacyDeletionRequestProviding = SettingsPrivacyDeletionRequestService(),
        deletionRequestStore: PrivacyDeletionRequestStoreProtocol = DefaultPrivacyDeletionRequestStore.shared,
        appMetadataService: SettingsAppMetadataProviding = SettingsAppMetadataService(),
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared
    ) {
        self.deletionRequestService = deletionRequestService
        self.deletionRequestStore = deletionRequestStore
        self.appMetadataService = appMetadataService
        self.authSessionStore = authSessionStore
    }

    /// 삭제 요청 시트의 최신 요약/로컬 추적 상태를 다시 읽습니다.
    func refresh() {
        let metadata = appMetadataService.loadMetadata(currentIdentity: currentIdentity())
        let record = deletionRequestStore.loadRecord(for: currentIdentity()?.userId)
        latestRecord = record
        summary = deletionRequestService.loadSummary(
            currentIdentity: currentIdentity(),
            metadata: metadata,
            record: record
        )
    }

    /// 현재 저장된 요청 ID를 우선 재사용하는 읽기 전용 초안을 생성합니다.
    /// - Returns: 화면 미리보기에 사용할 삭제 요청 메일 초안입니다.
    func previewDeletionRequestDraft() -> SettingsPrivacyDeletionRequestDraft {
        deletionRequestService.makeDeletionRequestDraft(
            currentIdentity: currentIdentity(),
            metadata: appMetadataService.loadMetadata(currentIdentity: currentIdentity()),
            existingRecord: deletionRequestStore.loadRecord(for: currentIdentity()?.userId)
        )
    }

    /// 새 삭제 요청 메일 초안을 준비하고 로컬 추적 상태를 초안 준비 단계로 기록합니다.
    /// - Returns: 요청 ID와 수집 항목이 포함된 삭제 요청 메일 초안입니다.
    func prepareDeletionRequestDraft() -> SettingsPrivacyDeletionRequestDraft {
        let identity = currentIdentity()
        let metadata = appMetadataService.loadMetadata(currentIdentity: identity)
        let existingRecord = deletionRequestStore.loadRecord(for: identity?.userId)
        let draft = deletionRequestService.makeDeletionRequestDraft(
            currentIdentity: identity,
            metadata: metadata,
            existingRecord: existingRecord
        )
        let record = PrivacyDeletionRequestRecord.draftPrepared(
            requestId: draft.requestId,
            channel: .inAppMailComposer,
            signedInEmail: identity?.email,
            date: Date(),
            summary: "요청 ID를 만들고 삭제 요청 초안을 준비했어요."
        )
        deletionRequestStore.persistRecord(record, for: identity?.userId)
        refresh()
        return draft
    }

    /// 기존 요청 ID를 인용하는 상태 문의 메일 초안을 준비합니다.
    /// - Returns: 상태 문의 메일 초안이 있으면 반환하고, 없으면 `nil`입니다.
    func prepareStatusInquiryDraft() -> SettingsPrivacyDeletionRequestDraft? {
        let identity = currentIdentity()
        guard let record = deletionRequestStore.loadRecord(for: identity?.userId) else {
            toastMessage = "먼저 삭제 요청 ID를 만든 뒤 상태 문의를 열 수 있어요."
            refresh()
            return nil
        }
        let metadata = appMetadataService.loadMetadata(currentIdentity: identity)
        let draft = deletionRequestService.makeStatusInquiryDraft(
            currentIdentity: identity,
            metadata: metadata,
            record: record
        )
        let nextRecord = PrivacyDeletionRequestRecord.inquiryPrepared(
            requestId: draft.requestId,
            channel: .inAppMailComposer,
            signedInEmail: identity?.email ?? record.signedInEmail,
            createdAt: record.createdAt,
            date: Date(),
            summary: "같은 요청 ID로 상태 문의 초안을 다시 준비했어요."
        )
        deletionRequestStore.persistRecord(nextRecord, for: identity?.userId)
        refresh()
        return draft
    }

    /// 외부 메일 앱 fallback으로 handoff된 사실을 로컬 추적 상태에 기록합니다.
    /// - Parameter draft: 외부 메일 앱으로 넘긴 삭제 요청 또는 상태 문의 초안입니다.
    func recordExternalMailHandoff(for draft: SettingsPrivacyDeletionRequestDraft) {
        let identity = currentIdentity()
        let existingCreatedAt = deletionRequestStore.loadRecord(for: identity?.userId)?.createdAt
            ?? Date().timeIntervalSince1970
        let record = PrivacyDeletionRequestRecord.handedOffToMailApp(
            requestId: draft.requestId,
            signedInEmail: identity?.email,
            createdAt: existingCreatedAt,
            date: Date(),
            summary: "메일 앱에서 보내기만 마치면 요청 ID 기준 추적을 이어갈 수 있어요."
        )
        deletionRequestStore.persistRecord(record, for: identity?.userId)
        toastMessage = "메일 앱으로 넘어갔어요. 전송 후 다시 돌아와 상태를 확인하세요."
        refresh()
    }

    /// in-app 메일 작성기 종료 결과를 로컬 추적 상태로 반영합니다.
    /// - Parameters:
    ///   - result: 메일 작성기에서 돌아온 종료 결과입니다.
    ///   - draft: 방금 사용한 삭제 요청 또는 상태 문의 초안입니다.
    func handleMailComposeResult(
        _ result: SettingsMailComposeResult,
        draft: SettingsPrivacyDeletionRequestDraft
    ) {
        let identity = currentIdentity()
        let existingCreatedAt = deletionRequestStore.loadRecord(for: identity?.userId)?.createdAt
            ?? Date().timeIntervalSince1970
        switch result {
        case .sent:
            let summary = draft.kind == .deletionRequest
                ? "메일 전송을 확인했어요. 이제 운영팀의 접수 회신을 기다리면 됩니다."
                : "상태 문의 메일 전송을 확인했어요. 같은 요청 ID로 회신을 기다리면 됩니다."
            let record = PrivacyDeletionRequestRecord.submittedAwaitingReply(
                requestId: draft.requestId,
                channel: .inAppMailComposer,
                signedInEmail: identity?.email,
                createdAt: existingCreatedAt,
                date: Date(),
                summary: summary
            )
            deletionRequestStore.persistRecord(record, for: identity?.userId)
            toastMessage = "메일 전송을 확인했어요."
        case .saved:
            toastMessage = "초안을 저장했어요. 전송 전까지는 접수 대기로 바뀌지 않아요."
        case .cancelled:
            toastMessage = "전송을 취소했어요. 요청 ID는 그대로 유지됩니다."
        case .failed(let message):
            toastMessage = message
        }
        refresh()
    }

    /// 외부 메일 앱에서 전송을 마쳤다고 사용자가 직접 확인한 사실을 기록합니다.
    func confirmExternalMailSent() {
        let identity = currentIdentity()
        guard let record = deletionRequestStore.loadRecord(for: identity?.userId) else {
            toastMessage = "먼저 삭제 요청 초안을 준비해주세요."
            refresh()
            return
        }
        let nextRecord = PrivacyDeletionRequestRecord.submittedAwaitingReply(
            requestId: record.requestId,
            channel: .externalMailApp,
            signedInEmail: identity?.email ?? record.signedInEmail,
            createdAt: record.createdAt,
            date: Date(),
            summary: "외부 메일 앱에서 전송 완료로 기록했어요. 이제 접수 회신을 기다리면 됩니다."
        )
        deletionRequestStore.persistRecord(nextRecord, for: identity?.userId)
        toastMessage = "전송 완료로 기록했어요."
        refresh()
    }

    /// 현재 요청 ID를 클립보드에 복사합니다.
    func copyRequestID() {
        guard let requestId = latestRecord?.requestId else {
            toastMessage = "아직 복사할 요청 ID가 없어요."
            return
        }
        UIPasteboard.general.string = requestId
        toastMessage = "요청 ID를 복사했어요."
    }

    /// 현재 메일 초안 본문을 클립보드에 복사합니다.
    /// - Parameter draft: 복사할 삭제 요청 또는 상태 문의 초안입니다.
    func copyDraftBody(_ draft: SettingsPrivacyDeletionRequestDraft) {
        UIPasteboard.general.string = draft.body
        let identity = currentIdentity()
        let existingCreatedAt = deletionRequestStore.loadRecord(for: identity?.userId)?.createdAt
            ?? Date().timeIntervalSince1970
        let record = PrivacyDeletionRequestRecord.draftPrepared(
            requestId: draft.requestId,
            channel: .copiedTemplate,
            signedInEmail: identity?.email,
            date: Date(),
            summary: "메일 본문을 복사했어요. 메일 앱이 없더라도 같은 요청 ID로 접수를 이어갈 수 있어요."
        )
        deletionRequestStore.persistRecord(
            PrivacyDeletionRequestRecord(
                requestId: record.requestId,
                status: record.status,
                channel: record.channel,
                signedInEmail: record.signedInEmail,
                createdAt: existingCreatedAt,
                updatedAt: record.updatedAt,
                lastActionSummary: record.lastActionSummary
            ),
            for: identity?.userId
        )
        toastMessage = "메일 본문을 복사했어요."
        refresh()
    }

    /// 토스트 메시지를 제거합니다.
    func clearToast() {
        toastMessage = nil
    }

    /// 현재 로그인 토큰 세션이 유효한 사용자 식별 정보만 반환합니다.
    /// - Returns: 현재 인증 사용자 식별 정보입니다. 게스트면 `nil`입니다.
    private func currentIdentity() -> AuthenticatedUserIdentity? {
        guard authSessionStore.currentTokenSession() != nil else {
            return nil
        }
        return authSessionStore.currentIdentity()
    }
}

private extension SettingsPrivacyDeletionRequestSummary {
    static let placeholder = SettingsPrivacyDeletionRequestSummary(
        title: "삭제 요청 흐름을 준비하는 중이에요",
        subtitle: "잠시 후 요청 ID와 접수 흐름을 보여드려요.",
        badgeText: "로딩 중",
        tone: .neutral,
        requestId: nil,
        footer: "삭제 요청과 일반 문의는 다른 경로로 다룹니다.",
        buttonTitle: "삭제 요청 흐름 열기"
    )
}
