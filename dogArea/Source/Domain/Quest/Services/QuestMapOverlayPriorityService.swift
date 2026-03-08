import Foundation

protocol QuestMapOverlayPriorityResolving {
    /// 지도 상단 오버레이 우선순위 정책 스냅샷을 생성합니다.
    /// - Returns: 상단 슬롯 역할, toast 역할, suppress 시간, 상태표를 포함한 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapOverlayPrioritySnapshot

    /// 현재 배너/HUD/toast 상황에 맞는 상단 오버레이 판정 결과를 계산합니다.
    /// - Parameter context: 지도 상단에 동시에 경쟁하는 banner, HUD, toast의 런타임 입력값입니다.
    /// - Returns: 현재 top slot, HUD, toast를 어떻게 노출해야 하는지 정의한 판정 결과입니다.
    func resolve(context: QuestMapOverlayRuntimeContext) -> QuestMapOverlayRuntimeResolution
}

final class QuestMapOverlayPriorityService: QuestMapOverlayPriorityResolving {
    /// 지도 상단 오버레이 우선순위 정책 스냅샷을 생성합니다.
    /// - Returns: 상단 슬롯 역할, toast 역할, suppress 시간, 상태표를 포함한 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapOverlayPrioritySnapshot {
        QuestMapOverlayPrioritySnapshot(
            tiers: [.critical, .operational, .progress],
            topOverlayRole: "top overlay slot은 지도 chrome 안에서 동시에 하나의 banner 계층만 점유합니다. quest HUD는 banner가 비었을 때 full, operational banner일 때만 collapsed secondary row로 공존합니다.",
            toastSlotRole: "toast slot은 top overlay와 분리된 짧은 비차단 피드백 전용 영역입니다. critical banner 전환 중에는 queue에 머물고, stable window 이후에만 노출합니다.",
            manualHUDSuppressSeconds: 120,
            minimumStableWindowSeconds: 1.5,
            coalescingWindowSeconds: 0.35,
            stateMatrix: stateMatrix(),
            transitionGuardrail: "critical preemption 외에는 1.5초 stable window 안에서 top slot 교체를 coalesce하고, milestone toast는 top slot이 안정된 뒤에만 재개합니다."
        )
    }

    /// 현재 배너/HUD/toast 상황에 맞는 상단 오버레이 판정 결과를 계산합니다.
    /// - Parameter context: 지도 상단에 동시에 경쟁하는 banner, HUD, toast의 런타임 입력값입니다.
    /// - Returns: 현재 top slot, HUD, toast를 어떻게 노출해야 하는지 정의한 판정 결과입니다.
    func resolve(context: QuestMapOverlayRuntimeContext) -> QuestMapOverlayRuntimeResolution {
        if context.activeBannerTier == .critical {
            return QuestMapOverlayRuntimeResolution(
                topSlotMode: .criticalBannerOnly,
                hudDisplayState: .hiddenByCriticalBanner,
                toastDisplayState: context.hasMilestoneToastCandidate ? .queuedUntilTopSlotSettles : .hidden,
                transitionPolicy: .deferUntilCriticalClears,
                restoreAfterSeconds: 0.35
            )
        }

        if context.isUserSuppressingHUD {
            return QuestMapOverlayRuntimeResolution(
                topSlotMode: context.activeBannerTier == .operational ? .operationalBannerOnly : .none,
                hudDisplayState: .suppressedByUser,
                toastDisplayState: resolvedToastState(
                    hasMilestoneToastCandidate: context.hasMilestoneToastCandidate,
                    shouldQueueToast: context.activeBannerTier == .operational
                ),
                transitionPolicy: context.activeBannerTier == .operational
                    ? .coalesceWithinStableWindow
                    : .immediate,
                restoreAfterSeconds: nil
            )
        }

        if context.activeBannerTier == .operational {
            let hidesHUDForDensity = shouldHideHUDForDensity(context: context)
            let hudState: QuestMapOverlayHUDDisplayState = hidesHUDForDensity
                ? .hiddenByDensityGuard
                : .collapsedSingleLine
            let topSlotMode: QuestMapTopOverlaySlotMode = hidesHUDForDensity || !context.hasQuestHUDCandidate
                ? .operationalBannerOnly
                : .operationalBannerWithCollapsedHUD
            return QuestMapOverlayRuntimeResolution(
                topSlotMode: topSlotMode,
                hudDisplayState: hudState,
                toastDisplayState: resolvedToastState(
                    hasMilestoneToastCandidate: context.hasMilestoneToastCandidate,
                    shouldQueueToast: true
                ),
                transitionPolicy: .coalesceWithinStableWindow,
                restoreAfterSeconds: 0.35
            )
        }

        if context.hasQuestHUDCandidate {
            let hudState: QuestMapOverlayHUDDisplayState = context.hasMultipleMissionSignals
                ? .collapsedSingleLine
                : .expanded
            return QuestMapOverlayRuntimeResolution(
                topSlotMode: .questHUDOnly,
                hudDisplayState: hudState,
                toastDisplayState: resolvedToastState(
                    hasMilestoneToastCandidate: context.hasMilestoneToastCandidate,
                    shouldQueueToast: false
                ),
                transitionPolicy: .immediate,
                restoreAfterSeconds: nil
            )
        }

        return QuestMapOverlayRuntimeResolution(
            topSlotMode: .none,
            hudDisplayState: .hidden,
            toastDisplayState: resolvedToastState(
                hasMilestoneToastCandidate: context.hasMilestoneToastCandidate,
                shouldQueueToast: false
            ),
            transitionPolicy: .immediate,
            restoreAfterSeconds: nil
        )
    }

    /// 작은 화면이나 시즌 타일 상세 패널 확장 상태에서 HUD를 숨겨야 하는지 판단합니다.
    /// - Parameter context: 현재 지도 상단 오버레이 런타임 입력값입니다.
    /// - Returns: compact density이거나 시즌 타일 상세가 열린 경우 `true`, 아니면 `false`입니다.
    private func shouldHideHUDForDensity(context: QuestMapOverlayRuntimeContext) -> Bool {
        context.screenDensity == .compact || context.isSeasonDetailExpanded
    }

    /// milestone toast가 바로 보일지, queue에 들어갈지 계산합니다.
    /// - Parameters:
    ///   - hasMilestoneToastCandidate: milestone toast를 띄울 이벤트가 존재하는지 여부입니다.
    ///   - shouldQueueToast: 현재 top slot 전환 안정화가 끝날 때까지 toast를 지연해야 하는지 여부입니다.
    /// - Returns: toast의 최종 노출 상태입니다.
    private func resolvedToastState(
        hasMilestoneToastCandidate: Bool,
        shouldQueueToast: Bool
    ) -> QuestMapOverlayToastDisplayState {
        guard hasMilestoneToastCandidate else { return .hidden }
        return shouldQueueToast ? .queuedUntilTopSlotSettles : .visible
    }

    /// 지도 상단 오버레이 상태표를 생성합니다.
    /// - Returns: 구현자가 바로 사용할 수 있는 우선순위 매트릭스 행 목록입니다.
    private func stateMatrix() -> [QuestMapOverlayStateMatrixRow] {
        [
            QuestMapOverlayStateMatrixRow(
                title: "critical banner 단독 우선",
                activeTier: .critical,
                bannerExamples: ["recoveryIssue", "recoverableSession", "returnToOrigin"],
                questHUDResult: .hiddenByCriticalBanner,
                toastResult: .queuedUntilTopSlotSettles,
                topSlotMode: .criticalBannerOnly,
                transitionPolicy: .deferUntilCriticalClears,
                notes: "권한/복구/종료 제안은 항상 단독 노출합니다. quest HUD는 자동 복귀하되 사용자 suppress 상태는 유지합니다."
            ),
            QuestMapOverlayStateMatrixRow(
                title: "operational banner + collapsed HUD",
                activeTier: .operational,
                bannerExamples: ["syncOutbox", "runtimeGuard", "offlineMode"],
                questHUDResult: .collapsedSingleLine,
                toastResult: .queuedUntilTopSlotSettles,
                topSlotMode: .operationalBannerWithCollapsedHUD,
                transitionPolicy: .coalesceWithinStableWindow,
                notes: "regular density에서는 operational banner 아래에 1줄 collapsed HUD만 공존시킵니다."
            ),
            QuestMapOverlayStateMatrixRow(
                title: "compact density는 single top slot",
                activeTier: .operational,
                bannerExamples: ["watchStatus", "guestBackup"],
                questHUDResult: .hiddenByDensityGuard,
                toastResult: .queuedUntilTopSlotSettles,
                topSlotMode: .operationalBannerOnly,
                transitionPolicy: .coalesceWithinStableWindow,
                notes: "좁은 화면이거나 시즌 타일 상세 패널이 열린 상태에서는 HUD를 숨기고 banner만 유지합니다."
            ),
            QuestMapOverlayStateMatrixRow(
                title: "progress only는 HUD 우선",
                activeTier: .progress,
                bannerExamples: [],
                questHUDResult: .expanded,
                toastResult: .visible,
                topSlotMode: .questHUDOnly,
                transitionPolicy: .immediate,
                notes: "critical/operational banner가 없으면 대표 quest HUD가 top overlay의 주인공이 됩니다."
            ),
            QuestMapOverlayStateMatrixRow(
                title: "다중 미션은 collapsed 유지",
                activeTier: .progress,
                bannerExamples: [],
                questHUDResult: .collapsedSingleLine,
                toastResult: .visible,
                topSlotMode: .questHUDOnly,
                transitionPolicy: .immediate,
                notes: "대표 1개 + 추가 n개 상태에서는 full HUD로 키우지 않고 single-line collapsed로 밀도를 제어합니다."
            ),
            QuestMapOverlayStateMatrixRow(
                title: "사용자 dismiss는 timed suppress",
                activeTier: nil,
                bannerExamples: [],
                questHUDResult: .suppressedByUser,
                toastResult: .visible,
                topSlotMode: .none,
                transitionPolicy: .immediate,
                notes: "사용자가 HUD를 닫으면 120초 동안 suppress하고, 대표 미션 상태가 completed/claimable로 상승하면 즉시 복귀를 허용합니다."
            )
        ]
    }
}
