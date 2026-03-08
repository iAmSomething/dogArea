import Foundation

struct SupabaseWeatherReplacementSummaryService: WeatherReplacementSummaryServicing {
    private struct SummaryRowDTO: Decodable {
        let applied: Bool?
        let blockedReason: String?
        let baseRiskLevel: String?
        let effectiveRiskLevel: String?
        let riskLevel: String?
        let replacementReason: String?
        let replacementCountToday: Int?
        let dailyReplacementLimit: Int?
        let shieldUsedThisWeek: Int?
        let weeklyShieldLimit: Int?
        let shieldApplyCountToday: Int?
        let shieldLastAppliedAt: String?
        let feedbackUsedThisWeek: Int?
        let weeklyFeedbackLimit: Int?
        let feedbackRemainingCount: Int?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case applied
            case blockedReason = "blocked_reason"
            case baseRiskLevel = "base_risk_level"
            case effectiveRiskLevel = "effective_risk_level"
            case riskLevel = "risk_level"
            case replacementReason = "replacement_reason"
            case replacementCountToday = "replacement_count_today"
            case dailyReplacementLimit = "daily_replacement_limit"
            case shieldUsedThisWeek = "shield_used_this_week"
            case weeklyShieldLimit = "weekly_shield_limit"
            case shieldApplyCountToday = "shield_apply_count_today"
            case shieldLastAppliedAt = "shield_last_applied_at"
            case feedbackUsedThisWeek = "feedback_used_this_week"
            case weeklyFeedbackLimit = "weekly_feedback_limit"
            case feedbackRemainingCount = "feedback_remaining_count"
            case refreshedAt = "refreshed_at"
        }
    }

    private struct FeedbackRowDTO: Decodable {
        let accepted: Bool?
        let message: String?
        let originalRiskLevel: String?
        let adjustedRiskLevel: String?
        let applied: Bool?
        let blockedReason: String?
        let baseRiskLevel: String?
        let effectiveRiskLevel: String?
        let riskLevel: String?
        let replacementReason: String?
        let replacementCountToday: Int?
        let dailyReplacementLimit: Int?
        let shieldUsedThisWeek: Int?
        let weeklyShieldLimit: Int?
        let shieldApplyCountToday: Int?
        let shieldLastAppliedAt: String?
        let feedbackUsedThisWeek: Int?
        let weeklyFeedbackLimit: Int?
        let feedbackRemainingCount: Int?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case accepted
            case message
            case originalRiskLevel = "original_risk_level"
            case adjustedRiskLevel = "adjusted_risk_level"
            case applied
            case blockedReason = "blocked_reason"
            case baseRiskLevel = "base_risk_level"
            case effectiveRiskLevel = "effective_risk_level"
            case riskLevel = "risk_level"
            case replacementReason = "replacement_reason"
            case replacementCountToday = "replacement_count_today"
            case dailyReplacementLimit = "daily_replacement_limit"
            case shieldUsedThisWeek = "shield_used_this_week"
            case weeklyShieldLimit = "weekly_shield_limit"
            case shieldApplyCountToday = "shield_apply_count_today"
            case shieldLastAppliedAt = "shield_last_applied_at"
            case feedbackUsedThisWeek = "feedback_used_this_week"
            case weeklyFeedbackLimit = "weekly_feedback_limit"
            case feedbackRemainingCount = "feedback_remaining_count"
            case refreshedAt = "refreshed_at"
        }
    }

    private let client: SupabaseHTTPClient

    /// 날씨 치환 canonical summary 서비스 인스턴스를 생성합니다.
    /// - Parameter client: Supabase RPC 호출에 사용할 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 현재 기준 위험도에 대한 서버 canonical summary를 조회합니다.
    /// - Parameters:
    ///   - baseRiskLevel: 클라이언트가 관측한 현재 기본 위험도입니다.
    ///   - now: 서버 요약 기준 시각입니다.
    /// - Returns: 서버가 계산한 날씨 치환 canonical summary입니다.
    func fetchSummary(baseRiskLevel: IndoorWeatherRiskLevel, now: Date) async throws -> WeatherReplacementSummarySnapshot {
        let payload: [String: Any] = [
            "payload": [
                "in_base_risk_level": baseRiskLevel.rawValue,
                "in_now_ts": ISO8601DateFormatter().string(from: now)
            ]
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_weather_replacement_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        return try decodeSummary(data: data, fallbackBaseRiskLevel: baseRiskLevel)
    }

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
    ) async throws -> WeatherFeedbackServerResult {
        let normalizedRequestId = requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? UUID().uuidString.lowercased()
            : requestId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload: [String: Any] = [
            "payload": [
                "in_base_risk_level": baseRiskLevel.rawValue,
                "in_request_id": normalizedRequestId,
                "in_now_ts": ISO8601DateFormatter().string(from: now)
            ]
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_submit_weather_feedback"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let row = try decodeRow(FeedbackRowDTO.self, from: data)
        let summary = makeSummary(from: row, fallbackBaseRiskLevel: baseRiskLevel)
        let originalRisk = IndoorWeatherRiskLevel(rawValue: row.originalRiskLevel ?? "")
            ?? summary.effectiveRiskLevel
        let adjustedRisk = IndoorWeatherRiskLevel(rawValue: row.adjustedRiskLevel ?? "")
            ?? summary.effectiveRiskLevel
        let message = (row.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return WeatherFeedbackServerResult(
            accepted: row.accepted ?? false,
            message: message.isEmpty ? defaultFeedbackMessage(accepted: row.accepted ?? false, adjustedRisk: adjustedRisk) : message,
            originalRisk: originalRisk,
            adjustedRisk: adjustedRisk,
            summary: summary
        )
    }

    /// RPC 응답 데이터에서 단일 row를 정규화해 디코딩합니다.
    /// - Parameters:
    ///   - type: 디코딩할 row 타입입니다.
    ///   - data: RPC 원시 응답 데이터입니다.
    /// - Returns: 정규화된 단일 row입니다.
    private func decodeRow<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        if let row = try? decoder.decode(T.self, from: data) {
            return row
        }
        if let rows = try? decoder.decode([T].self, from: data), let first = rows.first {
            return first
        }
        throw SupabaseHTTPError.invalidResponse
    }

    /// RPC 응답을 canonical summary snapshot으로 변환합니다.
    /// - Parameters:
    ///   - data: RPC 원시 응답 데이터입니다.
    ///   - fallbackBaseRiskLevel: 응답에 기본 위험도가 없을 때 사용할 위험도입니다.
    /// - Returns: 서버 canonical summary snapshot입니다.
    private func decodeSummary(
        data: Data,
        fallbackBaseRiskLevel: IndoorWeatherRiskLevel
    ) throws -> WeatherReplacementSummarySnapshot {
        let row = try decodeRow(SummaryRowDTO.self, from: data)
        return makeSummary(from: row, fallbackBaseRiskLevel: fallbackBaseRiskLevel)
    }

    /// summary DTO를 앱 공용 snapshot으로 정규화합니다.
    /// - Parameters:
    ///   - row: 서버가 반환한 summary row입니다.
    ///   - fallbackBaseRiskLevel: 응답에 기본 위험도가 없을 때 사용할 위험도입니다.
    /// - Returns: 앱이 재사용할 canonical summary snapshot입니다.
    private func makeSummary(
        from row: SummaryRowDTO,
        fallbackBaseRiskLevel: IndoorWeatherRiskLevel
    ) -> WeatherReplacementSummarySnapshot {
        let baseRisk = IndoorWeatherRiskLevel(rawValue: row.baseRiskLevel ?? "") ?? fallbackBaseRiskLevel
        let effectiveRisk = IndoorWeatherRiskLevel(rawValue: row.effectiveRiskLevel ?? row.riskLevel ?? "") ?? baseRisk
        return WeatherReplacementSummarySnapshot(
            ownerUserId: currentOwnerUserId(),
            baseRiskLevel: baseRisk,
            effectiveRiskLevel: effectiveRisk,
            replacementApplied: row.applied ?? (effectiveRisk != .clear),
            blockedReason: row.blockedReason,
            replacementReason: row.replacementReason,
            replacementCountToday: max(0, row.replacementCountToday ?? 0),
            dailyReplacementLimit: max(0, row.dailyReplacementLimit ?? 0),
            shieldUsedThisWeek: max(0, row.shieldUsedThisWeek ?? 0),
            weeklyShieldLimit: max(0, row.weeklyShieldLimit ?? 0),
            shieldApplyCountToday: max(0, row.shieldApplyCountToday ?? 0),
            shieldLastAppliedAt: SupabaseISO8601.parseEpoch(row.shieldLastAppliedAt),
            feedbackUsedThisWeek: max(0, row.feedbackUsedThisWeek ?? 0),
            weeklyFeedbackLimit: max(0, row.weeklyFeedbackLimit ?? 0),
            feedbackRemainingCount: max(0, row.feedbackRemainingCount ?? 0),
            refreshedAt: SupabaseISO8601.parseEpoch(row.refreshedAt) ?? Date().timeIntervalSince1970
        )
    }

    /// feedback DTO를 앱 공용 snapshot으로 정규화합니다.
    /// - Parameters:
    ///   - row: 서버가 반환한 feedback 처리 row입니다.
    ///   - fallbackBaseRiskLevel: 응답에 기본 위험도가 없을 때 사용할 위험도입니다.
    /// - Returns: 앱이 재사용할 canonical summary snapshot입니다.
    private func makeSummary(
        from row: FeedbackRowDTO,
        fallbackBaseRiskLevel: IndoorWeatherRiskLevel
    ) -> WeatherReplacementSummarySnapshot {
        let baseRisk = IndoorWeatherRiskLevel(rawValue: row.baseRiskLevel ?? "") ?? fallbackBaseRiskLevel
        let effectiveRisk = IndoorWeatherRiskLevel(rawValue: row.effectiveRiskLevel ?? row.riskLevel ?? "") ?? baseRisk
        return WeatherReplacementSummarySnapshot(
            ownerUserId: currentOwnerUserId(),
            baseRiskLevel: baseRisk,
            effectiveRiskLevel: effectiveRisk,
            replacementApplied: row.applied ?? (effectiveRisk != .clear),
            blockedReason: row.blockedReason,
            replacementReason: row.replacementReason,
            replacementCountToday: max(0, row.replacementCountToday ?? 0),
            dailyReplacementLimit: max(0, row.dailyReplacementLimit ?? 0),
            shieldUsedThisWeek: max(0, row.shieldUsedThisWeek ?? 0),
            weeklyShieldLimit: max(0, row.weeklyShieldLimit ?? 0),
            shieldApplyCountToday: max(0, row.shieldApplyCountToday ?? 0),
            shieldLastAppliedAt: SupabaseISO8601.parseEpoch(row.shieldLastAppliedAt),
            feedbackUsedThisWeek: max(0, row.feedbackUsedThisWeek ?? 0),
            weeklyFeedbackLimit: max(0, row.weeklyFeedbackLimit ?? 0),
            feedbackRemainingCount: max(0, row.feedbackRemainingCount ?? 0),
            refreshedAt: SupabaseISO8601.parseEpoch(row.refreshedAt) ?? Date().timeIntervalSince1970
        )
    }

    /// 서버가 사용자 문구를 주지 못했을 때 사용할 기본 결과 문구를 생성합니다.
    /// - Parameters:
    ///   - accepted: 피드백이 서버에서 수락됐는지 여부입니다.
    ///   - adjustedRisk: 서버가 최종 확정한 위험도입니다.
    /// - Returns: 홈 카드에 바로 노출할 기본 문구입니다.
    private func defaultFeedbackMessage(accepted: Bool, adjustedRisk: IndoorWeatherRiskLevel) -> String {
        if accepted {
            return "체감 피드백을 반영해 오늘 판정을 \(adjustedRisk.displayTitle)로 다시 계산했어요."
        }
        return "이번 주 체감 피드백 반영 한도를 모두 사용했어요."
    }

    /// 현재 인증 세션의 사용자 식별자를 canonical summary owner로 반환합니다.
    /// - Returns: 로그인 세션이 있으면 사용자 식별자, 없으면 `nil`입니다.
    private func currentOwnerUserId() -> String? {
        switch AppFeatureGate.currentSession() {
        case .guest:
            return nil
        case .member(let userId):
            return userId
        }
    }
}
