import Foundation

protocol WalkWidgetActionConverging {
    /// 현재 canonical 산책 상태를 기준으로 위젯 액션 상태를 수렴시킵니다.
    /// - Parameters:
    ///   - current: 현재 위젯 스냅샷에 저장된 액션 상태입니다.
    ///   - isWalking: 앱 세션이 현재 산책 중인지 여부입니다.
    ///   - status: 위젯 스냅샷에 반영할 canonical 상태 값입니다.
    ///   - statusMessage: canonical 상태에 연결된 부가 메시지입니다.
    ///   - now: 수렴 판단 기준 시각입니다.
    /// - Returns: 현재 canonical 상태와 TTL 규칙을 반영한 최신 액션 상태입니다.
    func resolve(
        current: WalkWidgetActionState?,
        isWalking: Bool,
        status: WalkWidgetSnapshotStatus,
        statusMessage: String?,
        now: Date
    ) -> WalkWidgetActionState?
}

final class WalkWidgetActionConvergenceService: WalkWidgetActionConverging {
    /// 현재 canonical 산책 상태를 기준으로 위젯 액션 상태를 수렴시킵니다.
    /// - Parameters:
    ///   - current: 현재 위젯 스냅샷에 저장된 액션 상태입니다.
    ///   - isWalking: 앱 세션이 현재 산책 중인지 여부입니다.
    ///   - status: 위젯 스냅샷에 반영할 canonical 상태 값입니다.
    ///   - statusMessage: canonical 상태에 연결된 부가 메시지입니다.
    ///   - now: 수렴 판단 기준 시각입니다.
    /// - Returns: 현재 canonical 상태와 TTL 규칙을 반영한 최신 액션 상태입니다.
    func resolve(
        current: WalkWidgetActionState?,
        isWalking: Bool,
        status: WalkWidgetSnapshotStatus,
        statusMessage: String?,
        now: Date
    ) -> WalkWidgetActionState? {
        guard let current else { return nil }

        if let convergedState = canonicalSuccessStateIfNeeded(
            for: current,
            isWalking: isWalking,
            now: now
        ) {
            return convergedState
        }

        if isExpired(current, now: now) == false {
            return current
        }

        switch current.phase {
        case .pending:
            return escalatedStateAfterPendingExpiry(
                current,
                status: status,
                statusMessage: statusMessage,
                now: now
            )
        case .requiresAppOpen:
            return .failed(
                kind: current.kind,
                followUp: .openApp,
                message: unresolvedFailureMessage(for: current.kind, statusMessage: statusMessage),
                now: now
            )
        case .succeeded, .failed:
            return nil
        }
    }

    /// 현재 canonical 산책 상태가 이미 액션 성공 결과에 도달했는지 검사합니다.
    /// - Parameters:
    ///   - state: 검사할 위젯 액션 상태입니다.
    ///   - isWalking: 앱 세션의 현재 산책 진행 여부입니다.
    ///   - now: 성공 상태를 생성할 기준 시각입니다.
    /// - Returns: canonical 상태가 이미 만족되면 성공 상태를 반환하고, 아니면 `nil`을 반환합니다.
    private func canonicalSuccessStateIfNeeded(
        for state: WalkWidgetActionState,
        isWalking: Bool,
        now: Date
    ) -> WalkWidgetActionState? {
        switch state.kind {
        case .startWalk where isWalking:
            return .succeeded(
                kind: .startWalk,
                message: "산책이 시작되어 위젯과 앱 상태를 맞췄어요.",
                now: now
            )
        case .endWalk where isWalking == false:
            return .succeeded(
                kind: .endWalk,
                message: "산책이 종료되어 위젯과 앱 상태를 맞췄어요.",
                now: now
            )
        default:
            return nil
        }
    }

    /// pending 상태가 만료됐을 때 canonical 상태와 도메인 상태를 바탕으로 후속 상태를 결정합니다.
    /// - Parameters:
    ///   - state: 만료된 pending 액션 상태입니다.
    ///   - status: 현재 위젯 canonical 상태 값입니다.
    ///   - statusMessage: 현재 canonical 상태 메시지입니다.
    ///   - now: 새 상태 생성 기준 시각입니다.
    /// - Returns: 앱 확인 필요 또는 실패 상태 중 하나입니다.
    private func escalatedStateAfterPendingExpiry(
        _ state: WalkWidgetActionState,
        status: WalkWidgetSnapshotStatus,
        statusMessage: String?,
        now: Date
    ) -> WalkWidgetActionState {
        switch status {
        case .locationDenied:
            return .failed(
                kind: state.kind,
                followUp: .openApp,
                message: statusMessage ?? "위치 권한이 필요해요. 앱에서 권한을 확인해 주세요.",
                now: now
            )
        case .sessionConflict:
            return .failed(
                kind: state.kind,
                followUp: .openApp,
                message: statusMessage ?? "현재 산책 상태와 위젯 요청이 달라 앱에서 확인이 필요해요.",
                now: now
            )
        case .error:
            return .failed(
                kind: state.kind,
                followUp: .openApp,
                message: statusMessage ?? unresolvedFailureMessage(for: state.kind, statusMessage: nil),
                now: now
            )
        case .ready:
            return .requiresAppOpen(
                kind: state.kind,
                message: unresolvedOpenAppMessage(for: state.kind, statusMessage: statusMessage),
                now: now
            )
        }
    }

    /// 액션 상태가 지정 시각 기준으로 만료됐는지 검사합니다.
    /// - Parameters:
    ///   - state: 만료 여부를 확인할 액션 상태입니다.
    ///   - now: 비교 기준 시각입니다.
    /// - Returns: 만료됐으면 `true`, 아니면 `false`입니다.
    private func isExpired(_ state: WalkWidgetActionState, now: Date) -> Bool {
        guard let expiresAt = state.expiresAt else { return false }
        return now.timeIntervalSince1970 >= expiresAt
    }

    /// pending 이후 앱 확인 단계로 올릴 때 사용할 안내 문구를 생성합니다.
    /// - Parameters:
    ///   - kind: 수렴 대상 액션 종류입니다.
    ///   - statusMessage: 현재 canonical 상태 메시지입니다.
    /// - Returns: 사용자가 앱에서 다음 행동을 이해할 수 있는 안내 문구입니다.
    private func unresolvedOpenAppMessage(
        for kind: WalkWidgetActionKind,
        statusMessage: String?
    ) -> String {
        if let statusMessage,
           statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return statusMessage
        }

        switch kind {
        case .startWalk:
            return "시작 요청은 전달됐지만 최종 반영 확인이 필요해요. 앱에서 현재 산책 상태를 확인해 주세요."
        case .endWalk:
            return "종료 요청은 전달됐지만 최종 반영 확인이 필요해요. 앱에서 현재 산책 상태를 확인해 주세요."
        case .openWalkTab, .claimQuestReward, .openQuestDetail, .openQuestRecovery, .openRivalTab:
            return "앱에서 상태를 확인해 주세요."
        }
    }

    /// 앱 확인 단계까지 지나도 수렴하지 못했을 때 사용할 실패 문구를 생성합니다.
    /// - Parameters:
    ///   - kind: 실패 처리할 액션 종류입니다.
    ///   - statusMessage: 현재 canonical 상태 메시지입니다.
    /// - Returns: 사용자가 앱 확인 필요성을 이해할 수 있는 실패 문구입니다.
    private func unresolvedFailureMessage(
        for kind: WalkWidgetActionKind,
        statusMessage: String?
    ) -> String {
        if let statusMessage,
           statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return statusMessage
        }

        switch kind {
        case .startWalk:
            return "산책 시작 상태를 맞추지 못했어요. 앱에서 현재 세션을 다시 확인해 주세요."
        case .endWalk:
            return "산책 종료 상태를 맞추지 못했어요. 앱에서 현재 세션을 다시 확인해 주세요."
        case .openWalkTab, .claimQuestReward, .openQuestDetail, .openQuestRecovery, .openRivalTab:
            return "앱에서 상태를 다시 확인해 주세요."
        }
    }
}
