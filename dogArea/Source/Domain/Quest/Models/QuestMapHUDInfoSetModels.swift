import Foundation

/// 지도 퀘스트 HUD가 대표로 보여줘야 하는 상태 종류를 정의합니다.
enum QuestMapHUDStateVariant: String, CaseIterable {
    case empty
    case singleMission
    case multipleMissions
    case nearCompletion
    case completed
    case claimable
}

/// collapsed HUD에서 어느 행에 어떤 정보를 고정할지 정의합니다.
enum QuestMapHUDCollapsedLine: String, CaseIterable {
    case title
    case summary
}

/// expanded HUD에서만 추가로 보여줄 정보 블록을 정의합니다.
enum QuestMapHUDExpandedBlock: String, CaseIterable {
    case checklist
    case rewardSummary
    case conditionBreakdown
}

/// 숫자를 어떤 문장 규칙으로 노출할지 정의합니다.
enum QuestMapHUDNumberExpressionRule: String, CaseIterable {
    case remainingCountSentence
    case progressRatioSentence
    case additionalMissionBadge
    case hiddenWhenNoMeaningfulDelta
}

/// 상태 배지를 어떤 수준으로 축약할지 정의합니다.
enum QuestMapHUDStatusBadgeStyle: String, CaseIterable {
    case none
    case almostDone
    case completed
    case rewardReady
    case plusAdditionalCount
}

/// collapsed HUD의 텍스트 제한 규칙입니다.
struct QuestMapHUDTextConstraint: Equatable {
    let titleMaxCharacters: Int
    let summaryMaxCharacters: Int
    let maximumLineCount: Int
    let usesTrailingEllipsis: Bool
}

/// collapsed HUD의 최소 정보셋입니다.
struct QuestMapHUDCollapsedInfoSet: Equatable {
    let lines: [QuestMapHUDCollapsedLine]
    let numberExpressionRule: QuestMapHUDNumberExpressionRule
    let badgeStyle: QuestMapHUDStatusBadgeStyle
    let textConstraint: QuestMapHUDTextConstraint
    let keepsProgressBarHidden: Bool
}

/// expanded HUD의 확장 정보셋입니다.
struct QuestMapHUDExpandedInfoSet: Equatable {
    let titleLine: String
    let supportingSummaryLine: String
    let blocks: [QuestMapHUDExpandedBlock]
    let numberExpressionRule: QuestMapHUDNumberExpressionRule
    let maximumChecklistItems: Int
}

/// 상태별 HUD 정보 구성을 정의합니다.
struct QuestMapHUDStatePolicy: Equatable {
    let state: QuestMapHUDStateVariant
    let collapsed: QuestMapHUDCollapsedInfoSet
    let expanded: QuestMapHUDExpandedInfoSet
    let visualWeightGuideline: String
    let autoHideAfterSeconds: TimeInterval?
}

/// QA가 그대로 비교할 수 있는 HUD 예시 카피입니다.
struct QuestMapHUDWireExample: Equatable {
    let state: QuestMapHUDStateVariant
    let title: String
    let summary: String
    let badge: String?
    let expandedChecklistHint: String
}

/// 지도 퀘스트 HUD 최소 정보셋 정책 스냅샷입니다.
struct QuestMapHUDInfoSetPolicySnapshot: Equatable {
    let collapsedStates: [QuestMapHUDStatePolicy]
    let wireExamples: [QuestMapHUDWireExample]
    let emptyStateCopy: String
    let multiMissionRule: String
    let visualWeightRule: String
}
