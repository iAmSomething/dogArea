import Foundation

enum WatchWalkCompletionResult: String, Equatable {
    case saved
    case discarded
}

struct WatchWalkCompletionSummaryState: Equatable, Identifiable {
    let actionId: String
    let result: WatchWalkCompletionResult
    let title: String
    let detail: String
    let petName: String
    let elapsedTime: TimeInterval
    let area: Double
    let pointCount: Int
    let generatedAt: TimeInterval?
    let followUpNote: String

    var id: String {
        actionId
    }

    var tone: WatchActionFeedbackTone {
        switch result {
        case .saved:
            return .success
        case .discarded:
            return .warning
        }
    }

    /// iPhone application context에 담긴 완료 요약 payload를 watch 전용 상태로 변환합니다.
    /// - Parameter context: iPhone 앱이 전달한 최신 WatchConnectivity application context입니다.
    /// - Returns: 표시 가능한 완료 요약이 있으면 상태를 반환하고, 없으면 `nil`을 반환합니다.
    static func make(from context: [String: Any]) -> WatchWalkCompletionSummaryState? {
        guard let payload = context["watch_completion_summary"] as? [String: Any],
              let actionId = (payload["action_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              actionId.isEmpty == false,
              let rawResult = payload["result"] as? String,
              let result = WatchWalkCompletionResult(rawValue: rawResult) else {
            return nil
        }

        let title = ((payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? result.defaultTitle
        let detail = ((payload["detail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? result.defaultDetail
        let petName = ((payload["pet_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "반려견"
        let followUpNote = ((payload["follow_up_note"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? result.defaultFollowUpNote

        return WatchWalkCompletionSummaryState(
            actionId: actionId,
            result: result,
            title: title,
            detail: detail,
            petName: petName,
            elapsedTime: (payload["elapsed_time"] as? TimeInterval) ?? 0,
            area: (payload["area"] as? Double) ?? 0,
            pointCount: (payload["point_count"] as? Int) ?? 0,
            generatedAt: payload["generated_at"] as? TimeInterval,
            followUpNote: followUpNote
        )
    }
}

private extension WatchWalkCompletionResult {
    var defaultTitle: String {
        switch self {
        case .saved:
            return "저장하고 종료했어요"
        case .discarded:
            return "기록을 폐기했어요"
        }
    }

    var defaultDetail: String {
        switch self {
        case .saved:
            return "이번 산책을 손목에서 바로 마무리했어요."
        case .discarded:
            return "이번 산책 기록은 저장하지 않았어요."
        }
    }

    var defaultFollowUpNote: String {
        switch self {
        case .saved:
            return "퀘스트와 영역 반영 상세는 iPhone 앱에서 이어서 확인할 수 있어요."
        case .discarded:
            return "새 산책을 시작하면 다시 기록을 쌓을 수 있어요."
        }
    }
}
