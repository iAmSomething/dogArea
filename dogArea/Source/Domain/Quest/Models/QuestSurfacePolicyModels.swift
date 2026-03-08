import Foundation

/// 퀘스트 상태를 소비하는 제품 표면을 정의합니다.
enum QuestSurface: String, CaseIterable {
    case home
    case map
    case widget
}

/// 각 표면에서 미션을 어떤 수준으로 노출할지 정의합니다.
enum QuestSurfaceVisibilityBucket: String, CaseIterable {
    case automaticDuringWalk
    case manualHomeOnly
    case mapSummaryOnly
}

/// 표면별로 어떤 계층이 canonical source of truth인지 정의합니다.
enum QuestSurfaceSourceOfTruth: String, CaseIterable {
    case localIndoorMissionBoard
    case serverCanonicalQuestSummary
    case widgetMirrorOfServerSummary
}

/// 산책 중 자동 추적 가능한 조건을 정의합니다.
enum QuestAutomaticTrackingRuleKind: String, CaseIterable {
    case walkDuration
    case walkDistance
    case newlyCapturedTerritoryTile
    case activeWalkingTime
}

/// 지도/위젯에 노출할 자동 추적 규칙 설명 모델입니다.
struct QuestAutomaticTrackingRule: Equatable {
    let kind: QuestAutomaticTrackingRuleKind
    let title: String
    let countingRule: String
    let exclusionRule: String
}

/// 지도 HUD에서 대표로 노출할 미션 후보 요약입니다.
struct QuestMapMissionCandidate: Equatable {
    let missionId: String
    let title: String
    let progressRatio: Double
    let remainingSummary: String
    let isClaimable: Bool
    let isAutomaticTrackable: Bool
}

/// 보상 수령을 어느 표면에서 처리할지 정의합니다.
enum QuestRewardFlowPolicy: String, CaseIterable {
    case mapShowsClaimableStateOnly
    case homeHandlesClaimCollection
}

/// QA가 그대로 재현할 수 있는 정책 시나리오입니다.
struct QuestSurfaceQAScenario: Equatable {
    let title: String
    let setup: String
    let expectedMapBehavior: String
    let expectedHomeBehavior: String
    let expectedWidgetBehavior: String
}

/// 퀘스트 표면 정책 스냅샷입니다.
struct QuestSurfacePolicySnapshot: Equatable {
    let automaticTrackingRules: [QuestAutomaticTrackingRule]
    let homeOnlyMissionCategories: [IndoorMissionCategory]
    let rewardFlow: [QuestRewardFlowPolicy]
    let homeSourceOfTruth: QuestSurfaceSourceOfTruth
    let mapSourceOfTruth: QuestSurfaceSourceOfTruth
    let widgetSourceOfTruth: QuestSurfaceSourceOfTruth
    let qaScenarios: [QuestSurfaceQAScenario]
}
