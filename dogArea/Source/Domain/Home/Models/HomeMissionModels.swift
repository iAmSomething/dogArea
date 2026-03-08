//
//  HomeMissionModels.swift
//  dogArea
//

import Foundation

struct DayBoundarySplitContribution {
    let previousDay: Date
    let currentDay: Date
    let previousArea: Double
    let currentArea: Double
    let previousDuration: Double
    let currentDuration: Double

    var previousDayLabel: String {
        Self.dayFormatter.string(from: previousDay)
    }

    var currentDayLabel: String {
        Self.dayFormatter.string(from: currentDay)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return formatter
    }()
}

enum IndoorWeatherRiskLevel: String, CaseIterable, Codable {
    case clear
    case caution
    case bad
    case severe

    var displayTitle: String {
        switch self {
        case .clear: return "날씨 안정"
        case .caution: return "기상 주의"
        case .bad: return "악천후"
        case .severe: return "고위험 악천후"
        }
    }

    var replacementMissionCount: Int {
        switch self {
        case .clear: return 0
        case .caution: return 1
        case .bad: return 2
        case .severe: return 3
        }
    }

    var rewardScale: Double {
        switch self {
        case .clear: return 1.0
        case .caution: return 0.92
        case .bad: return 0.88
        case .severe: return 0.84
        }
    }
}

enum IndoorWeatherRiskSource: String, Equatable {
    case environment
    case snapshot
    case serverSummary
    case userOverride
    case fallback
}

struct IndoorWeatherStatus: Equatable {
    let source: IndoorWeatherRiskSource
    let baseRisk: IndoorWeatherRiskLevel
    let adjustedRisk: IndoorWeatherRiskLevel
    let lastUpdatedAt: TimeInterval?
}

enum IndoorMissionCategory: String, CaseIterable {
    case recordCleanup
    case petCareCheck
    case trainingCheck
}

enum IndoorMissionPetAgeBand: String, Codable, Equatable {
    case puppy
    case adult
    case senior
    case unknown

    var title: String {
        switch self {
        case .puppy: return "유년기"
        case .adult: return "성견"
        case .senior: return "노령기"
        case .unknown: return "연령 미지정"
        }
    }
}

enum IndoorMissionActivityLevel: String, Codable, Equatable {
    case low
    case moderate
    case high

    var title: String {
        switch self {
        case .low: return "저활동"
        case .moderate: return "보통 활동"
        case .high: return "고활동"
        }
    }
}

enum IndoorMissionWalkFrequencyBand: String, Codable, Equatable {
    case sparse
    case steady
    case frequent

    var title: String {
        switch self {
        case .sparse: return "산책 빈도 낮음"
        case .steady: return "산책 빈도 보통"
        case .frequent: return "산책 빈도 높음"
        }
    }
}

enum IndoorMissionEasyDayState: String, Codable, Equatable {
    case unavailable
    case available
    case active
}

struct IndoorMissionPetContext: Equatable {
    let petId: String?
    let petName: String
    let ageYears: Int?
    let recentDailyMinutes: Double
    let averageWeeklyWalkCount: Double
}

struct IndoorMissionDifficultyHistoryEntry: Identifiable, Equatable {
    var id: String {
        "\(dayKey)|\(petId)"
    }

    let dayKey: String
    let petId: String
    let petName: String
    let multiplier: Double
    let ageBand: IndoorMissionPetAgeBand
    let activityLevel: IndoorMissionActivityLevel
    let walkFrequency: IndoorMissionWalkFrequencyBand
    let easyDayApplied: Bool
}

struct IndoorMissionDifficultySummary: Equatable {
    let petId: String?
    let petName: String
    let ageBand: IndoorMissionPetAgeBand
    let activityLevel: IndoorMissionActivityLevel
    let walkFrequency: IndoorMissionWalkFrequencyBand
    let appliedMultiplier: Double
    let adjustmentDescription: String
    let reasons: [String]
    let easyDayState: IndoorMissionEasyDayState
    let easyDayMessage: String
    let history: [IndoorMissionDifficultyHistoryEntry]
}

struct IndoorMissionTemplate: Identifiable, Equatable {
    let id: String
    let category: IndoorMissionCategory
    let title: String
    let description: String
    let minimumActionCount: Int
    let baseRewardPoint: Int
    let streakEligible: Bool
}

struct IndoorMissionProgress: Equatable {
    let actionCount: Int
    let minimumActionCount: Int
    let isCompleted: Bool

    var progressRatio: Double {
        guard minimumActionCount > 0 else { return 1.0 }
        return min(1.0, Double(actionCount) / Double(minimumActionCount))
    }
}

struct IndoorMissionCardModel: Identifiable, Equatable {
    let id: String
    let category: IndoorMissionCategory
    let title: String
    let description: String
    let minimumActionCount: Int
    let rewardPoint: Int
    let streakEligible: Bool
    let trackingMissionId: String
    let dayKey: String
    let isExtension: Bool
    let extensionSourceDayKey: String?
    let extensionRewardScale: Double
    let progress: IndoorMissionProgress
}

enum IndoorMissionExtensionState: String, Codable, Equatable {
    case none
    case active
    case consumed
    case expired
    case cooldown

    var shouldDisplayCard: Bool {
        switch self {
        case .none:
            return false
        case .active, .consumed, .expired, .cooldown:
            return true
        }
    }
}

struct IndoorMissionBoard: Equatable {
    let riskLevel: IndoorWeatherRiskLevel
    let dayKey: String
    let missions: [IndoorMissionCardModel]
    let extensionState: IndoorMissionExtensionState
    let extensionMessage: String?
    let difficultySummary: IndoorMissionDifficultySummary?

    var isIndoorReplacementActive: Bool {
        riskLevel != .clear && missions.isEmpty == false
    }

    var shouldDisplayCard: Bool {
        missions.isEmpty == false || extensionState.shouldDisplayCard || difficultySummary != nil
    }

    static let empty = IndoorMissionBoard(
        riskLevel: .clear,
        dayKey: "",
        missions: [],
        extensionState: .none,
        extensionMessage: nil,
        difficultySummary: nil
    )

    func updated(_ mission: IndoorMissionCardModel) -> IndoorMissionBoard {
        let replaced = missions.map { existing in
            existing.id == mission.id ? mission : existing
        }
        return .init(
            riskLevel: riskLevel,
            dayKey: dayKey,
            missions: replaced,
            extensionState: extensionState,
            extensionMessage: extensionMessage,
            difficultySummary: difficultySummary
        )
    }
}

struct WeatherFeedbackOutcome: Equatable {
    let accepted: Bool
    let message: String
    let originalRisk: IndoorWeatherRiskLevel
    let adjustedRisk: IndoorWeatherRiskLevel
    let remainingWeeklyQuota: Int
}
