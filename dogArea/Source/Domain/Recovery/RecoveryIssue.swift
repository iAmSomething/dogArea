import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum RecoveryIssueKind: Equatable {
    case locationPermissionDenied
    case networkOffline
    case authExpired
}

struct RecoveryIssue: Identifiable, Equatable {
    let kind: RecoveryIssueKind
    let detail: String?

    var id: String {
        "\(kind)-\(detail ?? "")"
    }

    var title: String {
        switch kind {
        case .locationPermissionDenied:
            return "위치 권한이 필요해요"
        case .networkOffline:
            return "오프라인 모드"
        case .authExpired:
            return "인증이 만료됐어요"
        }
    }

    var message: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정에서 위치 권한을 허용하면 산책 기록을 계속할 수 있어요."
        case .networkOffline:
            return "지금 기록은 기기에 저장되고, 온라인 복귀 시 자동 동기화돼요."
        case .authExpired:
            return "다시 로그인하면 현재 화면으로 돌아와서 이어서 진행할 수 있어요."
        }
    }

    var primaryButtonTitle: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정 열기"
        case .networkOffline:
            return "다시 시도"
        case .authExpired:
            return "다시 로그인"
        }
    }
}

enum RecoveryIssueClassifier {
    /// 동기화 에러 코드를 바탕으로 복구 배너 이슈를 분류합니다.
    /// - Parameter rawValue: 동기화 아웃박스에서 전달된 원본 에러 코드 문자열입니다.
    /// - Returns: 매핑 가능한 경우 복구 이슈, 불가능하면 `nil`입니다.
    static func fromSyncErrorCode(_ rawValue: String?) -> RecoveryIssue? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }
        switch rawValue {
        case SyncOutboxErrorCode.offline.rawValue:
            return RecoveryIssue(kind: .networkOffline, detail: rawValue)
        case SyncOutboxErrorCode.tokenExpired.rawValue, SyncOutboxErrorCode.unauthorized.rawValue:
            return RecoveryIssue(kind: .authExpired, detail: rawValue)
        default:
            return nil
        }
    }

    /// 일반 에러 메시지 문자열에서 복구 이슈를 추론합니다.
    /// - Parameter raw: 네트워크/인증 키워드를 포함할 수 있는 원본 에러 메시지입니다.
    /// - Returns: 추론 가능한 복구 이슈, 추론 불가하면 `nil`입니다.
    static func fromErrorMessage(_ raw: String?) -> RecoveryIssue? {
        guard let raw else { return nil }
        let normalized = raw.lowercased()
        if normalized.contains("network"),
           normalized.contains("offline") || normalized.contains("internet") {
            return RecoveryIssue(kind: .networkOffline, detail: raw)
        }
        if normalized.contains("token") || normalized.contains("unauthorized") || normalized.contains("auth") {
            return RecoveryIssue(kind: .authExpired, detail: raw)
        }
        return nil
    }
}

enum RecoverySystemAction {
    /// 앱 설정 화면을 열어 사용자가 권한 문제를 직접 복구할 수 있게 합니다.
    static func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

enum SyncOutboxPermanentFailureDisposition: String, Equatable {
    case rebuildable
    case archiveOnly
    case supportRequired
}

struct SyncOutboxPermanentFailureOverview: Equatable {
    let totalSessionCount: Int
    let rebuildableSessionIds: [String]
    let archiveableSessionIds: [String]
    let supportRequiredSessionIds: [String]
    let title: String
    let message: String
    let detailLines: [String]
    let representativeErrorCode: SyncOutboxErrorCode

    var hasRebuildableSessions: Bool { rebuildableSessionIds.isEmpty == false }
    var hasArchiveableSessions: Bool { archiveableSessionIds.isEmpty == false }
    var hasSupportRequiredSessions: Bool { supportRequiredSessionIds.isEmpty == false }
}

protocol SyncOutboxPermanentFailurePresenting {
    /// 영구 실패 세션과 로컬 기록을 대조해 복구/정리/문의 흐름용 요약을 생성합니다.
    /// - Parameters:
    ///   - sessionSnapshots: outbox에 남아 있는 영구 실패 세션 스냅샷 목록입니다.
    ///   - localPolygons: 현재 기기에 남아 있는 산책 기록 목록입니다.
    /// - Returns: 사용자에게 보여줄 영구 실패 복구 요약이며, 대상이 없으면 `nil`입니다.
    func makeOverview(
        sessionSnapshots: [SyncOutboxPermanentFailureSessionSnapshot],
        localPolygons: [Polygon]
    ) -> SyncOutboxPermanentFailureOverview?

    /// 영구 실패 세션 문의 메일로 연결할 `mailto:` URL을 생성합니다.
    /// - Parameters:
    ///   - overview: 현재 영구 실패 요약입니다.
    ///   - currentUserId: 문의 본문에 함께 남길 현재 사용자 ID입니다.
    ///   - supportEmail: 문의 수신 메일 주소입니다.
    /// - Returns: 문의 메일 작성 화면으로 연결할 URL입니다.
    func makeSupportMailURL(
        overview: SyncOutboxPermanentFailureOverview,
        currentUserId: String?,
        supportEmail: String
    ) -> URL?
}

struct SyncOutboxPermanentFailurePresentationService: SyncOutboxPermanentFailurePresenting {
    private struct SessionDiagnosis {
        let sessionId: String
        let disposition: SyncOutboxPermanentFailureDisposition
        let reasonCode: SyncOutboxErrorCode
        let detailLine: String
    }

    /// 영구 실패 세션과 로컬 기록을 대조해 복구/정리/문의 흐름용 요약을 생성합니다.
    /// - Parameters:
    ///   - sessionSnapshots: outbox에 남아 있는 영구 실패 세션 스냅샷 목록입니다.
    ///   - localPolygons: 현재 기기에 남아 있는 산책 기록 목록입니다.
    /// - Returns: 사용자에게 보여줄 영구 실패 복구 요약이며, 대상이 없으면 `nil`입니다.
    func makeOverview(
        sessionSnapshots: [SyncOutboxPermanentFailureSessionSnapshot],
        localPolygons: [Polygon]
    ) -> SyncOutboxPermanentFailureOverview? {
        guard sessionSnapshots.isEmpty == false else { return nil }

        let polygonsBySessionId = Dictionary(uniqueKeysWithValues: localPolygons.map { ($0.id.uuidString.lowercased(), $0) })
        let diagnoses = sessionSnapshots.map { diagnose(session: $0, polygonsBySessionId: polygonsBySessionId) }
        let rebuildableSessionIds = diagnoses
            .filter { $0.disposition == .rebuildable }
            .map(\.sessionId)
        let archiveableSessionIds = diagnoses
            .filter { $0.disposition == .archiveOnly }
            .map(\.sessionId)
        let supportRequiredSessionIds = diagnoses
            .filter { $0.disposition == .supportRequired }
            .map(\.sessionId)

        var messageSegments: [String] = []
        if rebuildableSessionIds.isEmpty == false {
            messageSegments.append("\(rebuildableSessionIds.count)건은 현재 기록 기준으로 다시 만들어 복구할 수 있어요.")
        }
        if archiveableSessionIds.isEmpty == false {
            messageSegments.append("\(archiveableSessionIds.count)건은 기기 기록은 남기고 동기화 목록에서만 정리할 수 있어요.")
        }
        if supportRequiredSessionIds.isEmpty == false {
            messageSegments.append("\(supportRequiredSessionIds.count)건은 계정 또는 소유권 확인이 필요해 문의로 넘기는 편이 안전해요.")
        }

        var detailLines: [String] = []
        for detailLine in diagnoses.map(\.detailLine) where detailLines.contains(detailLine) == false {
            detailLines.append(detailLine)
            if detailLines.count == 3 { break }
        }

        return SyncOutboxPermanentFailureOverview(
            totalSessionCount: sessionSnapshots.count,
            rebuildableSessionIds: rebuildableSessionIds,
            archiveableSessionIds: archiveableSessionIds,
            supportRequiredSessionIds: supportRequiredSessionIds,
            title: "동기화 정리가 필요한 기록 \(sessionSnapshots.count)건",
            message: messageSegments.joined(separator: " "),
            detailLines: detailLines,
            representativeErrorCode: diagnoses.first?.reasonCode ?? .unknown
        )
    }

    /// 영구 실패 세션 문의 메일로 연결할 `mailto:` URL을 생성합니다.
    /// - Parameters:
    ///   - overview: 현재 영구 실패 요약입니다.
    ///   - currentUserId: 문의 본문에 함께 남길 현재 사용자 ID입니다.
    ///   - supportEmail: 문의 수신 메일 주소입니다.
    /// - Returns: 문의 메일 작성 화면으로 연결할 URL입니다.
    func makeSupportMailURL(
        overview: SyncOutboxPermanentFailureOverview,
        currentUserId: String?,
        supportEmail: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "DogArea 산책 동기화 영구 실패 문의"),
            URLQueryItem(
                name: "body",
                value: """
                사용자 ID: \(currentUserId ?? "guest")
                전체 세션 수: \(overview.totalSessionCount)
                복구 가능 세션: \(overview.rebuildableSessionIds.joined(separator: ", "))
                정리 가능 세션: \(overview.archiveableSessionIds.joined(separator: ", "))
                문의 필요 세션: \(overview.supportRequiredSessionIds.joined(separator: ", "))

                증상:
                \(overview.message)
                """
            )
        ]
        return components.url
    }

    /// 단일 영구 실패 세션을 로컬 기록과 함께 진단해 복구 방향을 분류합니다.
    /// - Parameters:
    ///   - session: outbox에 남아 있는 영구 실패 세션 스냅샷입니다.
    ///   - polygonsBySessionId: 로컬 산책 기록을 세션 ID로 색인한 딕셔너리입니다.
    /// - Returns: 사용자 액션 분기와 진단 문구를 포함한 세션 진단 결과입니다.
    private func diagnose(
        session: SyncOutboxPermanentFailureSessionSnapshot,
        polygonsBySessionId: [String: Polygon]
    ) -> SessionDiagnosis {
        let localPolygon = polygonsBySessionId[session.walkSessionId]
        let localPetId = localPolygon?.canonicalPetId
        let primaryReason = preferredReasonCode(for: session)

        switch primaryReason {
        case .schemaMismatch:
            if localPolygon != nil {
                return SessionDiagnosis(
                    sessionId: session.walkSessionId,
                    disposition: .rebuildable,
                    reasonCode: primaryReason,
                    detailLine: "예전 형식으로 저장된 기록은 지금 기준으로 다시 만들어 복구할 수 있어요."
                )
            }
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .archiveOnly,
                reasonCode: primaryReason,
                detailLine: "원본 로컬 기록이 없어 서버 동기화 목록에서만 정리할 수 있어요."
            )
        case .sessionTimeRangeInvalid:
            if localPolygon != nil {
                return SessionDiagnosis(
                    sessionId: session.walkSessionId,
                    disposition: .rebuildable,
                    reasonCode: primaryReason,
                    detailLine: "잘못 저장된 시간 범위는 현재 로컬 기록 기준으로 다시 만들면 복구돼요."
                )
            }
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .archiveOnly,
                reasonCode: primaryReason,
                detailLine: "시간 정보가 어긋난 기록은 원본이 없으면 동기화 목록 정리만 할 수 있어요."
            )
        case .petIdRequired:
            if localPetId != nil {
                return SessionDiagnosis(
                    sessionId: session.walkSessionId,
                    disposition: .rebuildable,
                    reasonCode: primaryReason,
                    detailLine: "반려견 연결 정보가 복구돼 있으면 다시 만들어 바로 재전송할 수 있어요."
                )
            }
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .archiveOnly,
                reasonCode: primaryReason,
                detailLine: "반려견 연결 정보가 없는 기록은 기기에만 남기고 동기화 목록에서 정리할 수 있어요."
            )
        case .sessionInvalidPetReference:
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .archiveOnly,
                reasonCode: primaryReason,
                detailLine: "서버에 없는 반려견 참조 기록은 로컬 보관만 유지하고 동기화 대상에서 정리하는 편이 안전해요."
            )
        case .sessionOwnershipConflict, .conflict, .unauthorized, .tokenExpired:
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .supportRequired,
                reasonCode: primaryReason,
                detailLine: "계정 또는 소유권 확인이 필요한 기록은 문의로 넘겨 원인을 확인해야 해요."
            )
        case .notConfigured, .serverError, .storageQuota, .offline, .unknown:
            if localPolygon != nil {
                return SessionDiagnosis(
                    sessionId: session.walkSessionId,
                    disposition: .supportRequired,
                    reasonCode: primaryReason,
                    detailLine: "자동 복구 기준이 불명확한 실패는 문의로 넘겨 진단하는 편이 안전해요."
                )
            }
            return SessionDiagnosis(
                sessionId: session.walkSessionId,
                disposition: .archiveOnly,
                reasonCode: primaryReason,
                detailLine: "로컬 원본이 없는 오래된 실패 항목은 목록에서 정리할 수 있어요."
            )
        }
    }

    /// 세션 스냅샷에서 사용자 액션에 가장 직접적으로 영향을 주는 대표 오류 코드를 고릅니다.
    /// - Parameter session: 영구 실패 세션 스냅샷입니다.
    /// - Returns: 세션 단계 기준으로 대표로 사용할 오류 코드입니다.
    private func preferredReasonCode(for session: SyncOutboxPermanentFailureSessionSnapshot) -> SyncOutboxErrorCode {
        if let sessionCode = session.stageErrorCodes[.session] {
            if sessionCode == .schemaMismatch,
               let payload = session.payload(for: .session) {
                if (payload["pet_id"] ?? "").canonicalUUIDString == nil {
                    return .petIdRequired
                }

                let startedAt = Double(payload["started_at"] ?? "") ?? 0
                let endedAt = Double(payload["ended_at"] ?? "") ?? 0
                if endedAt < startedAt {
                    return .sessionTimeRangeInvalid
                }
            }
            return sessionCode
        }
        return session.stageErrorCodes
            .sorted { $0.key.order < $1.key.order }
            .first?.value ?? .unknown
    }
}
