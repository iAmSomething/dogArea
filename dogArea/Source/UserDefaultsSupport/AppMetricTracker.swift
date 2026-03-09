import Foundation

enum AppMetricEvent: String {
    case walkSaveSuccess = "walk_save_success"
    case walkSaveFailed = "walk_save_failed"
    case authMailSendAttempted = "auth_mail_send_attempted"
    case authMailSendAccepted = "auth_mail_send_accepted"
    case authMailActionSucceeded = "auth_mail_action_succeeded"
    case authMailActionRateLimited = "auth_mail_action_rate_limited"
    case authMailActionFailed = "auth_mail_action_failed"
    case authMailActionSuppressed = "auth_mail_action_suppressed"
    case authMailProviderBounce = "auth_mail_provider_bounce"
    case authMailProviderReject = "auth_mail_provider_reject"
    case authMailProviderDeferred = "auth_mail_provider_deferred"
    case watchActionReceived = "watch_action_received"
    case watchActionProcessed = "watch_action_processed"
    case watchActionApplied = "watch_action_applied"
    case watchActionDuplicate = "watch_action_duplicate"
    case widgetActionApplied = "widget_action_applied"
    case widgetActionRejected = "widget_action_rejected"
    case widgetActionDuplicate = "widget_action_duplicate"
    case widgetActionConverged = "widget_action_converged"
    case widgetActionEscalated = "widget_action_escalated"
    case widgetActionPendingDiscarded = "widget_action_pending_discarded"
    case caricatureSuccess = "caricature_success"
    case caricatureFailed = "caricature_failed"
    case nearbyOptInEnabled = "nearby_opt_in_enabled"
    case nearbyOptInDisabled = "nearby_opt_in_disabled"
    case petSelectionChanged = "pet_selection_changed"
    case petSelectionSuggested = "pet_selection_suggested"
    case recoveryDraftDetected = "recovery_draft_detected"
    case recoveryDraftDiscarded = "recovery_draft_discarded"
    case recoveryFinalizeConfirmed = "recovery_finalize_confirmed"
    case recoveryFinalizeFailed = "recovery_finalize_failed"
    case indoorMissionReplacementApplied = "indoor_mission_replacement_applied"
    case indoorMissionActionLogged = "indoor_mission_action_logged"
    case indoorMissionCompleted = "indoor_mission_completed"
    case indoorMissionCompletionRejected = "indoor_mission_completion_rejected"
    case indoorMissionExtensionApplied = "indoor_mission_extension_applied"
    case indoorMissionExtensionConsumed = "indoor_mission_extension_consumed"
    case indoorMissionExtensionExpired = "indoor_mission_extension_expired"
    case indoorMissionExtensionBlocked = "indoor_mission_extension_blocked"
    case indoorMissionDifficultyAdjusted = "indoor_mission_difficulty_adjusted"
    case indoorMissionEasyDayActivated = "indoor_mission_easy_day_activated"
    case indoorMissionEasyDayRejected = "indoor_mission_easy_day_rejected"
    case seasonCanonicalRefreshed = "season_canonical_refreshed"
    case seasonCanonicalMismatchDetected = "season_canonical_mismatch_detected"
    case seasonRewardClaimSucceeded = "season_reward_claim_succeeded"
    case seasonRewardClaimFailed = "season_reward_claim_failed"
    case weatherFeedbackSubmitted = "weather_feedback_submitted"
    case weatherFeedbackRateLimited = "weather_feedback_rate_limited"
    case weatherRiskReevaluated = "weather_risk_reevaluated"
    case syncAuthRefreshSucceeded = "sync_auth_refresh_succeeded"
    case syncAuthRefreshFailed = "sync_auth_refresh_failed"
    case rivalPrivacyOptInCompleted = "rival_privacy_opt_in_completed"
    case rivalLeaderboardFetched = "rival_leaderboard_fetched"
    case rivalHotspotFetchRequested = "rival_hotspot_fetch_requested"
    case rivalHotspotFetchSucceeded = "rival_hotspot_fetch_succeeded"
    case rivalHotspotFetchFailed = "rival_hotspot_fetch_failed"
}

final class AppMetricTracker {
    static let shared = AppMetricTracker()

    private init() {}

    /// 공통 metric 이벤트를 feature-control 수집 파이프라인으로 비동기 전송합니다.
    /// - Parameters:
    ///   - event: 기록할 metric 이벤트 타입입니다.
    ///   - userKey: 사용자 식별 해시에 대응하는 선택적 사용자 키입니다.
    ///   - featureKey: 관련 feature flag 키입니다.
    ///   - eventValue: 이벤트에 연결할 수치 값입니다.
    ///   - payload: 추가 태그/속성 문자열 맵입니다.
    func track(
        _ event: AppMetricEvent,
        userKey: String? = nil,
        featureKey: AppFeatureFlagKey? = nil,
        eventValue: Double? = nil,
        payload: [String: String] = [:]
    ) {
        var body: [String: Any] = [
            "action": "track_metric",
            "eventName": event.rawValue,
            "appInstanceId": FeatureFlagStore.shared.appInstanceId
        ]
        if let userKey, userKey.isEmpty == false {
            body["userKey"] = userKey
        }
        if let featureKey {
            body["featureKey"] = featureKey.rawValue
        }
        if let eventValue {
            body["eventValue"] = eventValue
        }
        if payload.isEmpty == false {
            body["payload"] = payload
        }
        FeatureControlService.shared.postFireAndForget(payload: body)
    }
}
