//
//  HomePresentationStateModels.swift
//  dogArea
//
//  Created by Codex on 3/7/26.
//

import Foundation

enum QuestMotionEventType: String, Equatable {
    case progress
    case completed
    case failed
    case alreadyCompleted
}

struct QuestMotionEvent: Identifiable, Equatable {
    let id = UUID()
    let missionId: String
    let missionTitle: String
    let type: QuestMotionEventType
    let progress: Double
}

struct QuestCompletionPresentation: Identifiable, Equatable {
    let id = UUID()
    let missionId: String
    let missionTitle: String
    let rewardPoint: Int
}

enum SeasonMotionEventType: String, Equatable {
    case scoreIncreased
    case rankUp
    case shieldApplied
    case seasonReset
}

struct SeasonMotionEvent: Identifiable, Equatable {
    let id = UUID()
    let type: SeasonMotionEventType
    let scoreDelta: Double
    let rankTier: SeasonRankTier
    let shieldApplied: Bool
}

struct SeasonMotionSummary: Equatable {
    let weekKey: String
    let score: Double
    let targetScore: Double
    let progress: Double
    let rankTier: SeasonRankTier
    let todayScoreDelta: Int
    let contributionCount: Int
    let weatherShieldActive: Bool
    let weatherShieldApplyCount: Int

    static let empty = SeasonMotionSummary(
        weekKey: "",
        score: 0,
        targetScore: 520,
        progress: 0,
        rankTier: .rookie,
        todayScoreDelta: 0,
        contributionCount: 0,
        weatherShieldActive: false,
        weatherShieldApplyCount: 0
    )
}

struct SeasonResultPresentation: Identifiable, Equatable {
    let id = UUID()
    let weekKey: String
    let rankTier: SeasonRankTier
    let totalScore: Int
    let contributionCount: Int
    let shieldApplyCount: Int
}

enum SeasonRewardClaimStatus: String, Codable, Equatable {
    case pending
    case claimed
    case failed
}

struct WeatherMissionStatusSummary: Equatable {
    let badgeText: String
    let title: String
    let reasonText: String
    let appliedAtText: String
    let shieldUsageText: String
    let policyTitle: String
    let policyText: String
    let lifecycleGuideText: String
    let fallbackNotice: String?
    let accessibilityText: String
    let isFallback: Bool
    let riskLevel: IndoorWeatherRiskLevel

    static let empty = WeatherMissionStatusSummary(
        badgeText: "정상",
        title: "실내 미션 전환 요약",
        reasonText: "기본 루프는 산책입니다.",
        appliedAtText: "적용 시점 -",
        shieldUsageText: "보호 사용 0회",
        policyTitle: "실내 미션이 열리는 기준",
        policyText: "실내 미션은 악천후나 예외 상황에서만 산책을 보조하는 흐름입니다.",
        lifecycleGuideText: "실내 미션을 진행했다면 기준 횟수를 채운 뒤 완료 확인을 눌러야 보상이 확정됩니다.",
        fallbackNotice: nil,
        accessibilityText: "실내 미션 전환 요약. 기본 루프는 산책입니다.",
        isFallback: false,
        riskLevel: .clear
    )
}

struct WeatherShieldDailySummary: Equatable {
    let dayKey: String
    let applyCount: Int
    let lastAppliedAtText: String
}

struct HomeWeatherMetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let valueText: String
    let detailText: String?
    let accessibilityText: String
}

struct HomeWeatherSnapshotCardPresentation: Equatable {
    let title: String
    let subtitle: String
    let statusBadgeText: String
    let detailActionTitle: String
    let metrics: [HomeWeatherMetricPresentation]
    let observedAtText: String
    let sourceLineText: String
    let missionHintText: String
    let accessibilityText: String
    let isPlaceholder: Bool
    let isFallback: Bool

    static let placeholder = HomeWeatherSnapshotCardPresentation(
        title: "지금 날씨 상세",
        subtitle: "기온, 체감, 습도, 강수, 공기질을 한 번에 확인하세요.",
        statusBadgeText: "준비 중",
        detailActionTitle: "오늘 산책 가이드 더보기",
        metrics: [
            .init(
                id: "temperature",
                title: "기온",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "기온 확인 중"
            ),
            .init(
                id: "feelsLike",
                title: "체감",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "체감 온도 확인 중"
            ),
            .init(
                id: "humidity",
                title: "습도",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "습도 확인 중"
            ),
            .init(
                id: "precipitationState",
                title: "강수 여부",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "강수 여부 확인 중"
            ),
            .init(
                id: "precipitationAmount",
                title: "강수량",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "강수량 확인 중"
            ),
            .init(
                id: "dust",
                title: "미세먼지",
                valueText: "확인 중",
                detailText: nil,
                accessibilityText: "미세먼지 확인 중"
            )
        ],
        observedAtText: "관측 시각 확인 중",
        sourceLineText: "최근 관측값을 준비 중입니다. 산책 기록이 생기면 자동으로 채워져요.",
        missionHintText: "미션 영향 요약은 아래 카드에서 따로 보여줘요.",
        accessibilityText: "지금 날씨 상세. 최근 관측값을 준비 중입니다.",
        isPlaceholder: true,
        isFallback: true
    )
}

enum HomeIndoorMissionLifecycleState: String, Equatable {
    case actionRequired
    case readyToFinalize
    case completed
}

struct HomeIndoorMissionRowPresentation: Identifiable, Equatable {
    let id: String
    let mission: IndoorMissionCardModel
    let lifecycleState: HomeIndoorMissionLifecycleState
    let trackingMode: HomeMissionTrackingModePresentation
    let trackingSummaryText: String
    let badgeText: String
    let requirementText: String
    let progressText: String
    let remainingText: String?
    let guideTitle: String
    let guideItems: [String]
    let lifecycleMessage: String
    let rewardFootnote: String
    let recordActionTitle: String
    let finalizeActionTitle: String
}

struct HomeIndoorMissionBoardPresentation: Equatable {
    let sectionTitle: String
    let sectionSubtitle: String
    let trackingOverviewTitle: String
    let trackingModes: [HomeMissionTrackingModePresentation]
    let rationaleItems: [String]
    let activeMissions: [HomeIndoorMissionRowPresentation]
    let completedMissions: [HomeIndoorMissionRowPresentation]
    let completedSectionTitle: String?
    let emptyTitle: String
    let emptyMessage: String

    static let empty = HomeIndoorMissionBoardPresentation(
        sectionTitle: "실내 미션 보조 안내",
        sectionSubtitle: "실외 산책이 어려운 날에만 여는 보조 흐름입니다.",
        trackingOverviewTitle: "추적 방식",
        trackingModes: [],
        rationaleItems: [],
        activeMissions: [],
        completedMissions: [],
        completedSectionTitle: nil,
        emptyTitle: "오늘은 실내 미션이 열리지 않았어요.",
        emptyMessage: "기본 루프는 산책 기록입니다. 악천후가 오면 보조 미션이 자동으로 열립니다."
    )
}

enum TerritoryGoalEntrySource: String, Equatable {
    case territoryWidget = "territory_widget"
}

enum QuestWidgetEntrySource: String, Equatable {
    case questRivalWidget = "quest_rival_widget"
}

enum HomeExternalScrollTarget: String, Equatable {
    case questMissionSection = "home.quest.section"
}

struct TerritoryGoalEntryContext: Equatable {
    let source: TerritoryGoalEntrySource
    let widgetStatus: TerritoryWidgetSnapshotStatus

    var bannerMessage: String {
        switch widgetStatus {
        case .memberReady:
            return "위젯에서 바로 다음 목표 상세로 열었어요. 남은 면적과 최근 정복 흐름을 이어서 확인해보세요."
        case .offlineCached:
            return "위젯에 저장된 최근 스냅샷으로 열었어요. 연결이 돌아오면 최신 목표를 다시 확인해보세요."
        case .syncDelayed:
            return "위젯 동기화가 지연돼 최근 스냅샷으로 열었어요. 새로고침 후 목표 기준을 다시 확인해보세요."
        case .emptyData:
            return "아직 목표 데이터가 충분하지 않아요. 다음 산책에서 첫 영역을 넓혀 기준을 만들어보세요."
        case .guestLocked:
            return "로그인 후 영역 목표 상세로 바로 이어졌어요. 다음 산책 목표를 여기서 정리해보세요."
        }
    }

    var isWarning: Bool {
        switch widgetStatus {
        case .offlineCached, .syncDelayed:
            return true
        case .memberReady, .emptyData, .guestLocked:
            return false
        }
    }
}

struct QuestWidgetEntryContext: Equatable {
    let source: QuestWidgetEntrySource
    let routeKind: WalkWidgetActionKind
    let widgetStatus: QuestRivalWidgetSnapshotStatus

    var bannerMessage: String {
        switch routeKind {
        case .claimQuestReward:
            return "위젯에서 보상 수령을 요청했어요. 이 카드에서 처리 결과와 다음 행동을 바로 확인해보세요."
        case .openQuestRecovery:
            return "위젯 수령 상태와 앱 상태가 어긋났을 수 있어요. 이 카드에서 다시 확인하고 복구해보세요."
        case .openQuestDetail:
            return "위젯에서 퀘스트 상세로 바로 이어졌어요. 부족한 진행량과 완료 조건을 여기서 이어서 확인해보세요."
        case .openRivalTab, .openWalkTab, .startWalk, .endWalk:
            return "위젯에서 현재 퀘스트 요약을 열었어요."
        }
    }

    var isWarning: Bool {
        switch routeKind {
        case .openQuestRecovery:
            return true
        case .claimQuestReward:
            return widgetStatus == .claimFailed || widgetStatus == .syncDelayed
        case .openQuestDetail, .openRivalTab, .openWalkTab, .startWalk, .endWalk:
            return false
        }
    }
}

struct HomeExternalRoute: Identifiable, Equatable {
    enum Destination: String, Equatable {
        case territoryGoalDetail = "territory_goal_detail"
        case questMissionBoard = "quest_mission_board"
    }

    let id = UUID()
    let destination: Destination
    let territoryGoalEntryContext: TerritoryGoalEntryContext?
    let questWidgetEntryContext: QuestWidgetEntryContext?
}
