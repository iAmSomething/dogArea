import Foundation

/// 산책 중 지도에서 퀘스트 피드백을 전달하는 계층을 정의합니다.
enum QuestMapFeedbackLayer: String, CaseIterable {
    case companionHUD = "companion_hud"
    case milestoneToast = "milestone_toast"
    case expandedChecklist = "expanded_checklist"
}

/// 지도 상단 chrome 안에서 퀘스트 피드백이 차지하는 우선순위 tier를 정의합니다.
enum QuestMapFeedbackPriorityTier: String, CaseIterable {
    case criticalBanner = "critical_banner"
    case questCompanionHUD = "quest_companion_hud"
    case passiveStatus = "passive_status"
}

/// 마일스톤 토스트를 발화시키는 이벤트 종류를 정의합니다.
enum QuestMapMilestoneTrigger: String, CaseIterable {
    case halfway = "halfway"
    case nearCompletion = "near_completion"
    case completed = "completed"
    case claimable = "claimable"
}

/// 토스트와 함께 재생할 햅틱 패턴을 정의합니다.
enum QuestMapMilestoneHaptic: String, CaseIterable {
    case progressPulse = "progress_pulse"
    case completionSuccess = "completion_success"
    case rewardReady = "reward_ready"
}

/// HUD가 현재 어떤 정도로 접혀 있어야 하는지 정의합니다.
enum QuestMapFeedbackCollapsedState: String, CaseIterable {
    case expanded = "expanded"
    case compactSingleLine = "compact_single_line"
    case iconOnly = "icon_only"
    case hiddenByCriticalBanner = "hidden_by_critical_banner"
}

/// 체크리스트 항목이 어떤 진행 상태인지 정의합니다.
enum QuestMapChecklistItemState: String, CaseIterable {
    case autoChecked = "auto_checked"
    case remainingDuringWalk = "remaining_during_walk"
    case homeOnly = "home_only"
}

/// 지도 HUD 본문에 상시 유지할 대표 요약 모델입니다.
struct QuestMapCompanionHUDPolicy: Equatable {
    let titleLine: String
    let progressLine: String
    let remainingLine: String
    let collapsedState: QuestMapFeedbackCollapsedState
    let priorityTier: QuestMapFeedbackPriorityTier
}

/// milestone toast의 노출 규칙을 정의합니다.
struct QuestMapMilestoneToastPolicy: Equatable {
    let trigger: QuestMapMilestoneTrigger
    let title: String
    let body: String
    let haptic: QuestMapMilestoneHaptic
    let autoDismissSeconds: TimeInterval
    let suppressDuplicateWindowSeconds: TimeInterval
}

/// 확장 체크리스트 항목 모델입니다.
struct QuestMapChecklistItem: Equatable {
    let title: String
    let detail: String
    let state: QuestMapChecklistItemState
}

/// 확장 체크리스트 섹션 모델입니다.
struct QuestMapChecklistSection: Equatable {
    let title: String
    let items: [QuestMapChecklistItem]
}

/// 지도 퀘스트 피드백 QA 재현 시나리오입니다.
struct QuestMapFeedbackQAScenario: Equatable {
    let title: String
    let setup: String
    let expectedHUD: String
    let expectedToast: String
    let expectedChecklist: String
}

/// 지도 퀘스트 피드백 정책 스냅샷입니다.
struct QuestMapFeedbackPolicySnapshot: Equatable {
    let layers: [QuestMapFeedbackLayer]
    let priorityTiers: [QuestMapFeedbackPriorityTier]
    let defaultHUD: QuestMapCompanionHUDPolicy
    let milestoneToasts: [QuestMapMilestoneToastPolicy]
    let checklistSections: [QuestMapChecklistSection]
    let qaScenarios: [QuestMapFeedbackQAScenario]
}
