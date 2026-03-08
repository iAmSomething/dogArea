import Foundation

/// 지도 상단 오버레이가 속하는 우선순위 계층을 정의합니다.
enum QuestMapOverlayFeedbackTier: String, CaseIterable {
    case critical = "critical"
    case operational = "operational"
    case progress = "progress"
}

/// 지도 상단 슬롯이 어떤 구성으로 점유되는지 정의합니다.
enum QuestMapTopOverlaySlotMode: String, CaseIterable {
    case none = "none"
    case criticalBannerOnly = "critical_banner_only"
    case operationalBannerOnly = "operational_banner_only"
    case operationalBannerWithCollapsedHUD = "operational_banner_with_collapsed_hud"
    case questHUDOnly = "quest_hud_only"
}

/// 퀘스트 HUD가 현재 어떤 방식으로 노출돼야 하는지 정의합니다.
enum QuestMapOverlayHUDDisplayState: String, CaseIterable {
    case hidden = "hidden"
    case expanded = "expanded"
    case collapsedSingleLine = "collapsed_single_line"
    case hiddenByCriticalBanner = "hidden_by_critical_banner"
    case hiddenByDensityGuard = "hidden_by_density_guard"
    case suppressedByUser = "suppressed_by_user"
}

/// milestone toast가 어떤 상태로 처리돼야 하는지 정의합니다.
enum QuestMapOverlayToastDisplayState: String, CaseIterable {
    case hidden = "hidden"
    case visible = "visible"
    case queuedUntilTopSlotSettles = "queued_until_top_slot_settles"
}

/// 상단 오버레이 교체 시 적용해야 하는 전환 정책을 정의합니다.
enum QuestMapOverlayTransitionPolicy: String, CaseIterable {
    case immediate = "immediate"
    case coalesceWithinStableWindow = "coalesce_within_stable_window"
    case deferUntilCriticalClears = "defer_until_critical_clears"
}

/// 화면 밀도에 따라 HUD 공존 허용 여부를 판정하기 위한 분류입니다.
enum QuestMapOverlayScreenDensity: String, CaseIterable {
    case compact = "compact"
    case regular = "regular"
}

/// 지도 상단 오버레이 런타임 판정 입력값입니다.
struct QuestMapOverlayRuntimeContext: Equatable {
    let activeBannerTier: QuestMapOverlayFeedbackTier?
    let hasQuestHUDCandidate: Bool
    let hasMultipleMissionSignals: Bool
    let hasMilestoneToastCandidate: Bool
    let isUserSuppressingHUD: Bool
    let screenDensity: QuestMapOverlayScreenDensity
    let isSeasonDetailExpanded: Bool
}

/// 지도 상단 오버레이 런타임 판정 결과입니다.
struct QuestMapOverlayRuntimeResolution: Equatable {
    let topSlotMode: QuestMapTopOverlaySlotMode
    let hudDisplayState: QuestMapOverlayHUDDisplayState
    let toastDisplayState: QuestMapOverlayToastDisplayState
    let transitionPolicy: QuestMapOverlayTransitionPolicy
    let restoreAfterSeconds: TimeInterval?
}

/// 구현자가 바로 옮길 수 있도록 정리한 상태표 행입니다.
struct QuestMapOverlayStateMatrixRow: Equatable {
    let title: String
    let activeTier: QuestMapOverlayFeedbackTier?
    let bannerExamples: [String]
    let questHUDResult: QuestMapOverlayHUDDisplayState
    let toastResult: QuestMapOverlayToastDisplayState
    let topSlotMode: QuestMapTopOverlaySlotMode
    let transitionPolicy: QuestMapOverlayTransitionPolicy
    let notes: String
}

/// 지도 상단 오버레이 우선순위 정책 스냅샷입니다.
struct QuestMapOverlayPrioritySnapshot: Equatable {
    let tiers: [QuestMapOverlayFeedbackTier]
    let topOverlayRole: String
    let toastSlotRole: String
    let manualHUDSuppressSeconds: TimeInterval
    let minimumStableWindowSeconds: TimeInterval
    let coalescingWindowSeconds: TimeInterval
    let stateMatrix: [QuestMapOverlayStateMatrixRow]
    let transitionGuardrail: String
}
