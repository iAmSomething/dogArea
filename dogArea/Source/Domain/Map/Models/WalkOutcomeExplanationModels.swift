import Foundation

enum WalkOutcomeSummaryState: String, Codable, Equatable {
    case lowApplied
    case normalApplied
    case policyExcludedDominant
}

enum WalkOutcomeExclusionReasonID: String, Codable, Equatable {
    case lowAccuracy
    case jump
    case duplicateOrPause
    case policyGuard
}

struct WalkOutcomeExclusionSnapshot: Codable, Equatable {
    let lowAccuracyCount: Int
    let jumpCount: Int
    let duplicateOrPauseCount: Int
    let policyGuardCount: Int

    static let empty = WalkOutcomeExclusionSnapshot(
        lowAccuracyCount: 0,
        jumpCount: 0,
        duplicateOrPauseCount: 0,
        policyGuardCount: 0
    )

    /// 모든 제외 사유 카운트를 합산한 총 제외 기록 수를 반환합니다.
    /// - Returns: 현재 스냅샷에 누적된 전체 제외 기록 수입니다.
    var totalExcludedCount: Int {
        lowAccuracyCount + jumpCount + duplicateOrPauseCount + policyGuardCount
    }
}

struct WalkOutcomeContributionSnapshot: Codable, Equatable {
    let markAreaM2: Double
    let routeAreaM2: Double
    let routeCappedAreaM2: Double
    let finalAreaM2: Double
    let routeContributionRatio: Double
}

enum WalkOutcomeConnectionStatus: String, Codable, Equatable {
    case updated
    case pending
    case notApplicable
}

struct WalkOutcomeConnectionSnapshot: Codable, Equatable {
    let recordStatus: WalkOutcomeConnectionStatus
    let territoryStatus: WalkOutcomeConnectionStatus
    let seasonStatus: WalkOutcomeConnectionStatus
    let questStatus: WalkOutcomeConnectionStatus
}

struct WalkOutcomeCalculationSnapshot: Codable, Equatable {
    let appliedPointCount: Int
    let excludedPointCount: Int
    let excludedRatio: Double
    let exclusions: WalkOutcomeExclusionSnapshot
    let contribution: WalkOutcomeContributionSnapshot
    let connections: WalkOutcomeConnectionSnapshot
    let calculationSourceVersion: String
}

struct WalkOutcomeExclusionReasonSummary: Identifiable, Equatable {
    let reasonID: WalkOutcomeExclusionReasonID
    let title: String
    let count: Int
    let shortExplanation: String

    var id: String { reasonID.rawValue }
}

struct WalkOutcomeContributionRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct WalkOutcomeConnectionRow: Identifiable, Equatable {
    let id: String
    let title: String
    let statusTitle: String
    let detail: String
}

struct WalkOutcomeExplanationDTO: Equatable {
    let summaryState: WalkOutcomeSummaryState
    let statusTitle: String
    let statusBody: String
    let appliedPointCount: Int
    let excludedPointCount: Int
    let excludedRatioText: String
    let topExclusionReasons: [WalkOutcomeExclusionReasonSummary]
    let primaryReasonLine: String?
    let primaryConnectionLine: String
    let contributionRows: [WalkOutcomeContributionRow]
    let connectionRows: [WalkOutcomeConnectionRow]
    let calculationSourceVersion: String
}
