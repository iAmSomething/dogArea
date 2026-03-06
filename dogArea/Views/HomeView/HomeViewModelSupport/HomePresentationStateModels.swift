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
    let fallbackNotice: String?
    let accessibilityText: String
    let isFallback: Bool
    let riskLevel: IndoorWeatherRiskLevel

    static let empty = WeatherMissionStatusSummary(
        badgeText: "정상",
        title: "오늘 날씨 연동 상태",
        reasonText: "기본 퀘스트 진행",
        appliedAtText: "적용 시점 -",
        shieldUsageText: "보호 사용 0회",
        fallbackNotice: nil,
        accessibilityText: "오늘 날씨 연동 상태. 기본 퀘스트 진행.",
        isFallback: false,
        riskLevel: .clear
    )
}

struct WeatherShieldDailySummary: Equatable {
    let dayKey: String
    let applyCount: Int
    let lastAppliedAtText: String
}
