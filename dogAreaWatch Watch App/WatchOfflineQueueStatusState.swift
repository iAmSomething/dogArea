//
//  WatchOfflineQueueStatusState.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import Foundation

struct WatchOfflineQueueStatusState: Equatable {
    let pendingCount: Int
    let queuedActionTitles: [String]
    let lastQueuedAt: TimeInterval?
    let oldestQueuedAt: TimeInterval?
    let lastAckStatus: String
    let lastAckActionId: String
    let lastAckAt: TimeInterval?
    let isReachable: Bool

    private let staleThreshold: TimeInterval = 90

    var summaryTone: WatchActionFeedbackTone {
        if pendingCount == 0 {
            return isReachable ? .success : .neutral
        }
        if isStale {
            return .warning
        }
        return isReachable ? .processing : .warning
    }

    var summaryTitle: String {
        if pendingCount == 0 {
            return "큐가 비어 있어요"
        }
        return "대기 \(pendingCount)건"
    }

    var summaryDetail: String {
        if pendingCount == 0 {
            return isReachable ? "지금은 바로 전송 가능한 상태예요." : "오프라인이면 새 요청을 큐에 안전하게 저장해요."
        }
        if isReachable {
            return "현재 연결되어 있어 다시 동기화하면 큐를 바로 재확인할 수 있어요."
        }
        return "iPhone과 다시 연결되면 큐를 자동으로 재전송해요."
    }

    var duplicateInfoText: String {
        "같은 action_id는 한 번만 반영돼요. 중복 전송처럼 보여도 실제 적용은 한 번만 처리됩니다."
    }

    var nextActionText: String {
        if pendingCount == 0 {
            return "지금은 추가 행동이 필요하지 않아요."
        }
        if isStale {
            return isReachable
                ? "큐가 오래 남아 있어요. 지금 다시 동기화해서 상태를 재확인해 보세요."
                : "오래 오프라인 상태예요. iPhone과 다시 연결한 뒤 다시 동기화해 보세요."
        }
        return isReachable
            ? "연결은 살아 있어요. 필요하면 다시 동기화로 최신 ACK를 확인할 수 있어요."
            : "현재는 자동 재전송 대기 상태예요. 연결이 돌아오면 큐를 다시 보냅니다."
    }

    var warningText: String? {
        guard pendingCount > 0 else { return nil }
        guard isStale else { return nil }
        return isReachable
            ? "큐가 90초 이상 남아 있습니다. 다시 동기화로 상태를 확인해 주세요."
            : "큐가 오래 남아 있습니다. iPhone 연결 후 다시 동기화가 필요합니다."
    }

    var lastQueuedActionSummary: String {
        guard queuedActionTitles.isEmpty == false else { return "없음" }
        return queuedActionTitles.joined(separator: ", ")
    }

    var shouldOfferManualSync: Bool {
        pendingCount > 0 || isReachable
    }

    var isManualSyncEnabled: Bool {
        isReachable
    }

    var manualSyncButtonTitle: String {
        if isReachable {
            return pendingCount > 0 ? "지금 다시 동기화" : "상태 다시 확인"
        }
        return "연결 후 다시 동기화"
    }

    var isManualSyncHighlighted: Bool {
        pendingCount > 0 && isReachable
    }

    var isStale: Bool {
        guard let oldestQueuedAt else { return false }
        return Date().timeIntervalSince1970 - oldestQueuedAt >= staleThreshold
    }

    /// 즉시 통신 가능 여부만 반영한 기본 큐 상태를 만듭니다.
    /// - Parameter isReachable: 현재 iPhone과 즉시 통신 가능한 상태인지 여부입니다.
    /// - Returns: pending/ACK 정보가 비어 있는 초기 큐 상태입니다.
    static func empty(isReachable: Bool) -> WatchOfflineQueueStatusState {
        make(
            pendingActions: [],
            lastAckStatus: "대기",
            lastAckActionId: "",
            lastAckAt: nil,
            isReachable: isReachable
        )
    }

    /// pending queue, ACK, reachability 정보를 화면용 큐 상태 모델로 변환합니다.
    /// - Parameters:
    ///   - pendingActions: 아직 iPhone에 전달되지 않은 watch 액션 queue입니다.
    ///   - lastAckStatus: 마지막 ACK 상태 요약 문자열입니다.
    ///   - lastAckActionId: 마지막 ACK에 대응한 action id입니다.
    ///   - lastAckAt: 마지막 ACK를 받은 시각입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한 상태인지 여부입니다.
    /// - Returns: 카드와 시트가 공통으로 사용할 큐 상태 모델입니다.
    static func make(
        pendingActions: [WatchActionDTO],
        lastAckStatus: String,
        lastAckActionId: String,
        lastAckAt: TimeInterval?,
        isReachable: Bool
    ) -> WatchOfflineQueueStatusState {
        let queuedActionTitles = pendingActions
            .map(\.displayTitle)
            .reduce(into: [String]()) { partial, title in
                if partial.contains(title) == false {
                    partial.append(title)
                }
            }
        let sentTimes = pendingActions.map(\.sentAt)
        return WatchOfflineQueueStatusState(
            pendingCount: pendingActions.count,
            queuedActionTitles: queuedActionTitles,
            lastQueuedAt: sentTimes.max(),
            oldestQueuedAt: sentTimes.min(),
            lastAckStatus: lastAckStatus,
            lastAckActionId: lastAckActionId,
            lastAckAt: lastAckAt,
            isReachable: isReachable
        )
    }
}

private extension WatchActionDTO {
    var displayTitle: String {
        WatchActionType(rawValue: action)?.baseTitle ?? action
    }
}
