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

enum IndoorMissionBoardSource: String, Codable, Equatable {
    case localFallback
    case serverCanonical
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

struct IndoorMissionCanonicalDifficultyHistorySnapshot: Codable, Equatable {
    let dayKey: String
    let petId: String?
    let petName: String
    let multiplier: Double
    let ageBandRawValue: String
    let activityLevelRawValue: String
    let walkFrequencyRawValue: String
    let easyDayApplied: Bool
}

struct IndoorMissionCanonicalDifficultySummarySnapshot: Codable, Equatable {
    let petId: String?
    let petName: String
    let ageBandRawValue: String
    let activityLevelRawValue: String
    let walkFrequencyRawValue: String
    let appliedMultiplier: Double
    let adjustmentDescription: String
    let adjustmentReasons: [String]
    let easyDayStateRawValue: String
    let easyDayMessage: String
    let history: [IndoorMissionCanonicalDifficultyHistorySnapshot]
}

struct IndoorMissionCanonicalMissionSnapshot: Codable, Equatable {
    let missionInstanceId: String
    let templateId: String
    let categoryRawValue: String
    let title: String
    let description: String
    let minimumActionCount: Int
    let rewardPoint: Int
    let streakEligible: Bool
    let trackingDayKey: String
    let isExtension: Bool
    let extensionSourceDayKey: String?
    let extensionRewardScale: Double
    let actionCount: Int
    let claimable: Bool
    let rewardEligible: Bool
    let claimedAt: TimeInterval?
    let statusRawValue: String
}

struct IndoorMissionCanonicalSummarySnapshot: Codable, Equatable {
    let ownerUserId: String?
    let petContextId: String?
    let dayKey: String
    let baseRiskLevel: IndoorWeatherRiskLevel
    let effectiveRiskLevel: IndoorWeatherRiskLevel
    let extensionStateRawValue: String
    let extensionMessage: String?
    let difficultySummary: IndoorMissionCanonicalDifficultySummarySnapshot?
    let missions: [IndoorMissionCanonicalMissionSnapshot]
    let refreshedAt: TimeInterval
}

struct IndoorMissionCanonicalActionMutationResult: Equatable {
    let missionInstanceId: String
    let templateId: String
    let eventId: String
    let idempotent: Bool
    let actionCount: Int
    let minimumActionCount: Int
    let claimable: Bool
    let statusRawValue: String
    let refreshedAt: TimeInterval
}

struct IndoorMissionCanonicalClaimMutationResult: Equatable {
    let missionInstanceId: String
    let templateId: String
    let claimStatusRawValue: String
    let alreadyClaimed: Bool
    let rewardPoints: Int
    let claimedAt: TimeInterval?
    let refreshedAt: TimeInterval
}

struct IndoorMissionCanonicalEasyDayMutationResult: Equatable {
    let outcomeRawValue: String
    let petContextId: String?
    let alreadyApplied: Bool
    let refreshedAt: TimeInterval
}

protocol IndoorMissionCanonicalSummaryServicing {
    /// 현재 선택 반려견/날씨 기준의 서버 canonical 실내 미션 summary를 조회합니다.
    /// - Parameters:
    ///   - context: 선택 반려견 기준 실내 미션 컨텍스트입니다.
    ///   - baseRiskLevel: 클라이언트가 관측한 기본 날씨 위험도입니다.
    ///   - now: 서버 summary를 계산할 기준 시각입니다.
    /// - Returns: 서버가 확정한 실내 미션 보드 canonical snapshot입니다.
    func fetchSummary(
        context: IndoorMissionPetContext,
        baseRiskLevel: IndoorWeatherRiskLevel,
        now: Date
    ) async throws -> IndoorMissionCanonicalSummarySnapshot

    /// 실내 미션의 자가보고 행동 +1 이벤트를 서버 canonical 경로로 기록합니다.
    /// - Parameters:
    ///   - missionInstanceId: 진행을 누적할 실내 미션 인스턴스 식별자입니다.
    ///   - requestId: 멱등 처리를 위한 요청 식별자입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 서버가 반영한 최신 action 누적 결과입니다.
    func recordAction(
        missionInstanceId: String,
        requestId: String,
        now: Date
    ) async throws -> IndoorMissionCanonicalActionMutationResult

    /// 실내 미션 보상 수령/완료를 서버 canonical 경로로 확정합니다.
    /// - Parameters:
    ///   - missionInstanceId: 보상을 수령할 실내 미션 인스턴스 식별자입니다.
    ///   - dayKey: 현재 홈 보드 day key입니다.
    ///   - petContextId: 현재 선택 반려견 context 식별자입니다.
    ///   - requestId: 멱등 처리를 위한 요청 식별자입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 서버가 확정한 claim 결과입니다.
    func claimReward(
        missionInstanceId: String,
        dayKey: String,
        petContextId: String?,
        requestId: String,
        now: Date
    ) async throws -> IndoorMissionCanonicalClaimMutationResult

    /// 쉬운 날 모드를 서버 canonical 경로로 활성화합니다.
    /// - Parameters:
    ///   - context: 선택 반려견 기준 실내 미션 컨텍스트입니다.
    ///   - baseRiskLevel: 클라이언트가 관측한 기본 날씨 위험도입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 쉬운 날 적용 결과입니다.
    func activateEasyDay(
        context: IndoorMissionPetContext,
        baseRiskLevel: IndoorWeatherRiskLevel,
        now: Date
    ) async throws -> IndoorMissionCanonicalEasyDayMutationResult
}

protocol IndoorMissionCanonicalSummaryStoreProtocol {
    /// 서버 canonical summary snapshot을 저장합니다.
    /// - Parameter summary: 저장할 실내 미션 canonical summary입니다.
    func save(_ summary: IndoorMissionCanonicalSummarySnapshot)

    /// 특정 사용자/일자/반려견 문맥에 대응하는 summary snapshot을 조회합니다.
    /// - Parameters:
    ///   - userId: 현재 사용자 식별자입니다.
    ///   - dayKey: 조회 기준 day key입니다.
    ///   - petContextId: 반려견 context 식별자입니다.
    /// - Returns: 저장된 snapshot이며, 없거나 다른 사용자 캐시면 `nil`입니다.
    func loadSummary(
        for userId: String?,
        dayKey: String,
        petContextId: String?
    ) -> IndoorMissionCanonicalSummarySnapshot?

    /// 최대 허용 나이 안에 있는 canonical summary snapshot을 조회합니다.
    /// - Parameters:
    ///   - maxAge: 허용할 최대 snapshot 나이(초)입니다.
    ///   - userId: 현재 사용자 식별자입니다.
    ///   - dayKey: 조회 기준 day key입니다.
    ///   - petContextId: 반려견 context 식별자입니다.
    /// - Returns: 유효한 snapshot이며, 없거나 만료되면 `nil`입니다.
    func loadFreshSummary(
        maxAge: TimeInterval,
        for userId: String?,
        dayKey: String,
        petContextId: String?
    ) -> IndoorMissionCanonicalSummarySnapshot?

    /// 특정 사용자에게 속한 실내 미션 canonical snapshot을 모두 삭제합니다.
    /// - Parameter userId: 삭제할 사용자 식별자입니다. `nil`이면 전체 캐시를 비웁니다.
    func clear(for userId: String?)
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
    let canonicalMissionInstanceId: String?
    let claimable: Bool?
    let rewardEligible: Bool?
    let source: IndoorMissionBoardSource

    /// 홈 실내 미션 카드 모델을 생성합니다.
    /// - Parameters:
    ///   - id: 카드 식별자입니다.
    ///   - category: 실내 미션 카테고리입니다.
    ///   - title: 카드 제목입니다.
    ///   - description: 카드 설명입니다.
    ///   - minimumActionCount: 완료에 필요한 최소 행동 수입니다.
    ///   - rewardPoint: 완료 시 지급되는 보상 포인트입니다.
    ///   - streakEligible: 시즌 연속 보상 반영 대상 여부입니다.
    ///   - trackingMissionId: 추적/템플릿 기준 미션 식별자입니다.
    ///   - dayKey: 카드가 속한 일자 키입니다.
    ///   - isExtension: 연장 미션 여부입니다.
    ///   - extensionSourceDayKey: 연장 원본 day key입니다.
    ///   - extensionRewardScale: 연장 감액 배율입니다.
    ///   - progress: 현재 진행 상태입니다.
    ///   - canonicalMissionInstanceId: 서버 canonical 미션 인스턴스 식별자입니다.
    ///   - claimable: 서버 기준 보상 수령 가능 여부입니다.
    ///   - rewardEligible: 서버 기준 보상 지급 가능 여부입니다.
    ///   - source: 보드 ownership 출처입니다.
    init(
        id: String,
        category: IndoorMissionCategory,
        title: String,
        description: String,
        minimumActionCount: Int,
        rewardPoint: Int,
        streakEligible: Bool,
        trackingMissionId: String,
        dayKey: String,
        isExtension: Bool,
        extensionSourceDayKey: String?,
        extensionRewardScale: Double,
        progress: IndoorMissionProgress,
        canonicalMissionInstanceId: String? = nil,
        claimable: Bool? = nil,
        rewardEligible: Bool? = nil,
        source: IndoorMissionBoardSource = .localFallback
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.minimumActionCount = minimumActionCount
        self.rewardPoint = rewardPoint
        self.streakEligible = streakEligible
        self.trackingMissionId = trackingMissionId
        self.dayKey = dayKey
        self.isExtension = isExtension
        self.extensionSourceDayKey = extensionSourceDayKey
        self.extensionRewardScale = extensionRewardScale
        self.progress = progress
        self.canonicalMissionInstanceId = canonicalMissionInstanceId
        self.claimable = claimable
        self.rewardEligible = rewardEligible
        self.source = source
    }
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
    let source: IndoorMissionBoardSource

    /// 홈 실내 미션 보드 모델을 생성합니다.
    /// - Parameters:
    ///   - riskLevel: 현재 적용된 실내 날씨 위험도입니다.
    ///   - dayKey: 보드 기준 일자 키입니다.
    ///   - missions: 노출할 실내 미션 카드 목록입니다.
    ///   - extensionState: 연장 미션 슬롯 상태입니다.
    ///   - extensionMessage: 연장 상태 설명 문구입니다.
    ///   - difficultySummary: 난이도/쉬운 날 요약 정보입니다.
    ///   - source: 보드 ownership 출처입니다.
    init(
        riskLevel: IndoorWeatherRiskLevel,
        dayKey: String,
        missions: [IndoorMissionCardModel],
        extensionState: IndoorMissionExtensionState,
        extensionMessage: String?,
        difficultySummary: IndoorMissionDifficultySummary?,
        source: IndoorMissionBoardSource = .localFallback
    ) {
        self.riskLevel = riskLevel
        self.dayKey = dayKey
        self.missions = missions
        self.extensionState = extensionState
        self.extensionMessage = extensionMessage
        self.difficultySummary = difficultySummary
        self.source = source
    }

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
        difficultySummary: nil,
        source: .localFallback
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
            difficultySummary: difficultySummary,
            source: source
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
