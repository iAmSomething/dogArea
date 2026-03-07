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
        title: "오늘 미션 영향 요약",
        reasonText: "기본 퀘스트 진행",
        appliedAtText: "적용 시점 -",
        shieldUsageText: "보호 사용 0회",
        policyTitle: "오늘 미션 기준",
        policyText: "날씨 위험도에 따라 실외 목표와 실내 대체 미션이 자동으로 정리됩니다.",
        lifecycleGuideText: "기준 횟수를 채운 뒤 완료 확인을 눌러야 보상이 확정됩니다.",
        fallbackNotice: nil,
        accessibilityText: "오늘 미션 영향 요약. 기본 퀘스트 진행.",
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
    let rationaleItems: [String]
    let activeMissions: [HomeIndoorMissionRowPresentation]
    let completedMissions: [HomeIndoorMissionRowPresentation]
    let completedSectionTitle: String?
    let emptyTitle: String
    let emptyMessage: String

    static let empty = HomeIndoorMissionBoardPresentation(
        sectionTitle: "오늘 미션 안내",
        sectionSubtitle: "완료 기준과 부족분을 카드에서 바로 확인하세요.",
        rationaleItems: [],
        activeMissions: [],
        completedMissions: [],
        completedSectionTitle: nil,
        emptyTitle: "오늘 진행할 미션이 없어요.",
        emptyMessage: "날씨 기준이 바뀌면 새로운 미션이 자동으로 열립니다."
    )
}
