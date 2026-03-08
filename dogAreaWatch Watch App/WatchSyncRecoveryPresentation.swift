//
//  WatchSyncRecoveryPresentation.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import Foundation

enum WatchManualSyncRecoveryPhase: Equatable {
    case idle
    case processing(requestedAt: TimeInterval)
    case waiting(requestedAt: TimeInterval)
    case recovered(recoveredAt: TimeInterval)
}

struct WatchSyncRecoverySignal: Equatable, Hashable {
    let title: String
    let detail: String
    let tone: WatchActionFeedbackTone
}

struct WatchSyncRecoveryState: Equatable {
    let headline: String
    let headlineTone: WatchActionFeedbackTone
    let detail: String
    let signals: [WatchSyncRecoverySignal]
    let manualSyncButtonTitle: String
    let manualSyncButtonTone: WatchActionFeedbackTone
    let isManualSyncEnabled: Bool
    let isManualSyncHighlighted: Bool
    let cooldownRemainingText: String?
    let isOutOfSyncLikely: Bool
}

protocol WatchSyncRecoveryPresenting {
    /// queue, ACK, reachability, 수동 확인 상태를 종합해 watch 동기화 회복 프레젠테이션 상태를 계산합니다.
    /// - Parameters:
    ///   - pendingCount: 현재 큐에 남아 있는 action 개수입니다.
    ///   - oldestQueuedAt: 가장 오래된 queued action의 전송 시각입니다.
    ///   - lastSyncAt: iPhone application context 기준 마지막 동기화 시각입니다.
    ///   - lastAckAt: 마지막 ACK를 받은 시각입니다.
    ///   - lastAckStatus: 마지막 ACK 상태 문자열입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한지 여부입니다.
    ///   - manualSyncPhase: 수동 동기화 recovery 상태 단계입니다.
    ///   - nextManualSyncAllowedAt: 다시 수동 동기화를 허용할 다음 시각입니다.
    ///   - now: 기준이 되는 현재 시각입니다.
    /// - Returns: watch 카드/상세 시트가 공통으로 사용할 sync recovery 상태입니다.
    func makeState(
        pendingCount: Int,
        oldestQueuedAt: TimeInterval?,
        lastSyncAt: TimeInterval?,
        lastAckAt: TimeInterval?,
        lastAckStatus: String,
        isReachable: Bool,
        manualSyncPhase: WatchManualSyncRecoveryPhase,
        nextManualSyncAllowedAt: TimeInterval?,
        now: TimeInterval
    ) -> WatchSyncRecoveryState
}

struct DefaultWatchSyncRecoveryPresentationService: WatchSyncRecoveryPresenting {
    private let staleSyncThreshold: TimeInterval = 60
    private let staleQueueThreshold: TimeInterval = 90

    /// queue/ACK/reachability 상태를 기반으로 watch sync recovery 프레젠테이션 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - pendingCount: 현재 큐에 남아 있는 action 개수입니다.
    ///   - oldestQueuedAt: 가장 오래된 queued action의 전송 시각입니다.
    ///   - lastSyncAt: iPhone application context 기준 마지막 동기화 시각입니다.
    ///   - lastAckAt: 마지막 ACK를 받은 시각입니다.
    ///   - lastAckStatus: 마지막 ACK 상태 문자열입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한지 여부입니다.
    ///   - manualSyncPhase: 수동 동기화 recovery 상태 단계입니다.
    ///   - nextManualSyncAllowedAt: 다시 수동 동기화를 허용할 다음 시각입니다.
    ///   - now: 기준이 되는 현재 시각입니다.
    /// - Returns: watch 카드/상세 시트가 공통으로 사용할 sync recovery 상태입니다.
    func makeState(
        pendingCount: Int,
        oldestQueuedAt: TimeInterval?,
        lastSyncAt: TimeInterval?,
        lastAckAt: TimeInterval?,
        lastAckStatus: String,
        isReachable: Bool,
        manualSyncPhase: WatchManualSyncRecoveryPhase,
        nextManualSyncAllowedAt: TimeInterval?,
        now: TimeInterval
    ) -> WatchSyncRecoveryState {
        let signals = makeSignals(
            pendingCount: pendingCount,
            oldestQueuedAt: oldestQueuedAt,
            lastSyncAt: lastSyncAt,
            lastAckAt: lastAckAt,
            lastAckStatus: lastAckStatus,
            isReachable: isReachable,
            manualSyncPhase: manualSyncPhase,
            now: now
        )
        let cooldownRemainingText = makeCooldownRemainingText(
            nextManualSyncAllowedAt: nextManualSyncAllowedAt,
            now: now
        )
        let hasSyncRisk = signals.contains { $0.tone == .warning || $0.tone == .failure }

        let summary = makeSummary(
            pendingCount: pendingCount,
            isReachable: isReachable,
            manualSyncPhase: manualSyncPhase,
            signals: signals,
            hasSyncRisk: hasSyncRisk
        )
        let manualSyncPresentation = makeManualSyncPresentation(
            pendingCount: pendingCount,
            isReachable: isReachable,
            manualSyncPhase: manualSyncPhase,
            hasSyncRisk: hasSyncRisk,
            cooldownRemainingText: cooldownRemainingText
        )

        return WatchSyncRecoveryState(
            headline: summary.headline,
            headlineTone: summary.headlineTone,
            detail: summary.detail,
            signals: signals,
            manualSyncButtonTitle: manualSyncPresentation.title,
            manualSyncButtonTone: manualSyncPresentation.tone,
            isManualSyncEnabled: manualSyncPresentation.isEnabled,
            isManualSyncHighlighted: manualSyncPresentation.isHighlighted,
            cooldownRemainingText: cooldownRemainingText,
            isOutOfSyncLikely: hasSyncRisk || manualSyncPhase.isActiveRecovery
        )
    }

    /// 현재 sync/queue/recovery 조건에서 사용자에게 노출할 out-of-sync 징후 목록을 생성합니다.
    /// - Parameters:
    ///   - pendingCount: 현재 큐에 남아 있는 action 개수입니다.
    ///   - oldestQueuedAt: 가장 오래된 queued action의 전송 시각입니다.
    ///   - lastSyncAt: 마지막 application context 동기화 시각입니다.
    ///   - lastAckAt: 마지막 ACK 시각입니다.
    ///   - lastAckStatus: 마지막 ACK 상태 문자열입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한지 여부입니다.
    ///   - manualSyncPhase: 수동 동기화 recovery 상태 단계입니다.
    ///   - now: 기준이 되는 현재 시각입니다.
    /// - Returns: 카드/시트에서 보여줄 sync 징후 목록입니다.
    private func makeSignals(
        pendingCount: Int,
        oldestQueuedAt: TimeInterval?,
        lastSyncAt: TimeInterval?,
        lastAckAt: TimeInterval?,
        lastAckStatus: String,
        isReachable: Bool,
        manualSyncPhase: WatchManualSyncRecoveryPhase,
        now: TimeInterval
    ) -> [WatchSyncRecoverySignal] {
        var signals: [WatchSyncRecoverySignal] = []

        if isReachable == false {
            signals.append(
                WatchSyncRecoverySignal(
                    title: "iPhone 연결 끊김",
                    detail: "연결이 돌아오면 자동 동기화가 다시 시작됩니다.",
                    tone: .warning
                )
            )
        }

        if let lastSyncAt, lastSyncAt > 0 {
            if now - lastSyncAt >= staleSyncThreshold {
                signals.append(
                    WatchSyncRecoverySignal(
                        title: "마지막 동기화 오래됨",
                        detail: "최근 상태 수신이 늦어져 현재 상태를 다시 확인할 필요가 있습니다.",
                        tone: .warning
                    )
                )
            }
        } else {
            signals.append(
                WatchSyncRecoverySignal(
                    title: "초기 동기화 전",
                    detail: "아직 iPhone의 최신 상태를 한 번도 받지 못했습니다.",
                    tone: .neutral
                )
            )
        }

        if pendingCount > 0,
           let oldestQueuedAt,
           now - oldestQueuedAt >= staleQueueThreshold {
            signals.append(
                WatchSyncRecoverySignal(
                    title: "큐 장기 적재",
                    detail: "90초 이상 처리되지 않은 요청이 남아 있어 직접 상태 확인이 필요합니다.",
                    tone: .warning
                )
            )
        }

        if pendingCount > 0, lastAckAt == nil || lastAckStatus == "대기" {
            signals.append(
                WatchSyncRecoverySignal(
                    title: "ACK 아직 없음",
                    detail: "보낸 요청에 대한 최신 ACK를 아직 받지 못했습니다.",
                    tone: .warning
                )
            )
        }

        switch manualSyncPhase {
        case .idle:
            break
        case .processing:
            signals.insert(
                WatchSyncRecoverySignal(
                    title: "수동 확인 진행 중",
                    detail: "사용자가 요청한 다시 동기화에 대한 최신 상태를 확인 중입니다.",
                    tone: .processing
                ),
                at: 0
            )
        case .waiting:
            signals.insert(
                WatchSyncRecoverySignal(
                    title: "응답 대기 중",
                    detail: "연결 또는 ACK 응답이 늦어져 자동 회복을 조금 더 기다리는 중입니다.",
                    tone: .warning
                ),
                at: 0
            )
        case .recovered:
            signals.insert(
                WatchSyncRecoverySignal(
                    title: "동기화 확인됨",
                    detail: "가장 최근 다시 동기화 요청 이후 상태를 다시 맞췄습니다.",
                    tone: .success
                ),
                at: 0
            )
        }

        return signals
    }

    /// 현재 조건에서 카드 헤드라인과 설명을 결정합니다.
    /// - Parameters:
    ///   - pendingCount: 현재 큐에 남아 있는 action 개수입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한지 여부입니다.
    ///   - manualSyncPhase: 수동 동기화 recovery 상태 단계입니다.
    ///   - signals: 현재 감지된 sync 징후 목록입니다.
    ///   - hasSyncRisk: 사용자가 이해해야 할 out-of-sync 위험이 있는지 여부입니다.
    /// - Returns: 카드/시트 헤더에 표시할 제목, 톤, 설명입니다.
    private func makeSummary(
        pendingCount: Int,
        isReachable: Bool,
        manualSyncPhase: WatchManualSyncRecoveryPhase,
        signals: [WatchSyncRecoverySignal],
        hasSyncRisk: Bool
    ) -> (headline: String, headlineTone: WatchActionFeedbackTone, detail: String) {
        switch manualSyncPhase {
        case .processing:
            return (
                "다시 확인 중",
                .processing,
                "iPhone의 최신 ACK와 상태를 기다리는 중이에요."
            )
        case .waiting:
            return (
                "응답 대기 중",
                .warning,
                isReachable
                    ? "연결은 살아 있지만 최신 응답이 늦어지고 있어요."
                    : "연결이 돌아오면 자동 동기화가 다시 시도됩니다."
            )
        case .recovered:
            return (
                "동기화 확인됨",
                .success,
                "watch와 iPhone 상태를 다시 맞췄어요."
            )
        case .idle:
            break
        }

        if hasSyncRisk {
            return (
                "상태 확인 필요",
                .warning,
                signals.first?.detail ?? "최신 상태를 다시 확인해 주세요."
            )
        }

        if pendingCount == 0 {
            return (
                "동기화 정상",
                isReachable ? .success : .neutral,
                isReachable
                    ? "watch와 iPhone 상태가 현재 잘 맞고 있어요."
                    : "오프라인이지만 대기 중인 요청은 없습니다."
            )
        }

        return (
            "자동 동기화 대기",
            isReachable ? .processing : .warning,
            isReachable
                ? "연결은 살아 있어 큐 재확인을 바로 시도할 수 있어요."
                : "연결이 돌아오면 큐를 자동으로 다시 보냅니다."
        )
    }

    /// 수동 동기화 CTA의 제목/강조/활성 상태를 계산합니다.
    /// - Parameters:
    ///   - pendingCount: 현재 큐에 남아 있는 action 개수입니다.
    ///   - isReachable: 현재 iPhone과 즉시 통신 가능한지 여부입니다.
    ///   - manualSyncPhase: 수동 동기화 recovery 상태 단계입니다.
    ///   - hasSyncRisk: 사용자가 이해해야 할 out-of-sync 위험이 있는지 여부입니다.
    ///   - cooldownRemainingText: 다음 수동 확인까지 남은 시간 설명입니다.
    /// - Returns: CTA 제목, 톤, 활성 상태, 강조 여부입니다.
    private func makeManualSyncPresentation(
        pendingCount: Int,
        isReachable: Bool,
        manualSyncPhase: WatchManualSyncRecoveryPhase,
        hasSyncRisk: Bool,
        cooldownRemainingText: String?
    ) -> (title: String, tone: WatchActionFeedbackTone, isEnabled: Bool, isHighlighted: Bool) {
        if case .processing = manualSyncPhase {
            return ("다시 확인 중", .processing, false, false)
        }

        if cooldownRemainingText != nil {
            return ("잠시 후 다시", .warning, false, false)
        }

        guard isReachable else {
            return ("연결 후 다시 동기화", .warning, false, false)
        }

        if hasSyncRisk || pendingCount > 0 {
            return ("지금 다시 동기화", .warning, true, true)
        }

        return ("상태 다시 확인", .neutral, true, false)
    }

    /// 수동 동기화 cooldown이 남아 있을 때 사용자용 문구를 만듭니다.
    /// - Parameters:
    ///   - nextManualSyncAllowedAt: 다음 수동 동기화 허용 시각입니다.
    ///   - now: 기준이 되는 현재 시각입니다.
    /// - Returns: 남은 시간이 있으면 사용자용 문자열, 없으면 `nil`입니다.
    private func makeCooldownRemainingText(
        nextManualSyncAllowedAt: TimeInterval?,
        now: TimeInterval
    ) -> String? {
        guard let nextManualSyncAllowedAt, nextManualSyncAllowedAt > now else { return nil }
        let seconds = Int(ceil(nextManualSyncAllowedAt - now))
        return "\(max(seconds, 1))초 뒤 다시 확인할 수 있어요."
    }
}

private extension WatchManualSyncRecoveryPhase {
    var isActiveRecovery: Bool {
        switch self {
        case .idle:
            return false
        case .processing, .waiting, .recovered:
            return true
        }
    }
}
