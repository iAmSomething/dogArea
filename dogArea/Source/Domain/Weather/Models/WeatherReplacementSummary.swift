import Foundation

/// 서버가 최종 확정한 날씨 치환/보호/체감 피드백 요약 snapshot입니다.
struct WeatherReplacementSummarySnapshot: Codable, Equatable {
    let ownerUserId: String?
    let baseRiskLevel: IndoorWeatherRiskLevel
    let effectiveRiskLevel: IndoorWeatherRiskLevel
    let replacementApplied: Bool
    let blockedReason: String?
    let replacementReason: String?
    let replacementCountToday: Int
    let dailyReplacementLimit: Int
    let shieldUsedThisWeek: Int
    let weeklyShieldLimit: Int
    let shieldApplyCountToday: Int
    let shieldLastAppliedAt: TimeInterval?
    let feedbackUsedThisWeek: Int
    let weeklyFeedbackLimit: Int
    let feedbackRemainingCount: Int
    let refreshedAt: TimeInterval
}

/// 체감 피드백 서버 처리 결과입니다.
struct WeatherFeedbackServerResult: Equatable {
    let accepted: Bool
    let message: String
    let originalRisk: IndoorWeatherRiskLevel
    let adjustedRisk: IndoorWeatherRiskLevel
    let summary: WeatherReplacementSummarySnapshot
}

/// 날씨 치환 canonical summary를 조회/갱신하는 서비스 계약입니다.
protocol WeatherReplacementSummaryServicing {
    /// 현재 기준 위험도에 대한 서버 canonical summary를 조회합니다.
    /// - Parameters:
    ///   - baseRiskLevel: 클라이언트가 관측한 현재 기본 위험도입니다.
    ///   - now: 서버 요약 기준 시각입니다.
    /// - Returns: 서버가 계산한 날씨 치환 canonical summary입니다.
    func fetchSummary(baseRiskLevel: IndoorWeatherRiskLevel, now: Date) async throws -> WeatherReplacementSummarySnapshot

    /// 사용자의 체감 피드백을 서버에 제출하고 재평가 결과를 반환합니다.
    /// - Parameters:
    ///   - baseRiskLevel: 제출 시점의 기본 위험도입니다.
    ///   - requestId: 멱등 처리를 위한 요청 식별자입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 서버가 확정한 피드백 처리 결과와 최신 canonical summary입니다.
    func submitFeedback(
        baseRiskLevel: IndoorWeatherRiskLevel,
        requestId: String,
        now: Date
    ) async throws -> WeatherFeedbackServerResult
}
