import Foundation
import UserNotifications

/// 퀘스트 리마인드 스케줄 적용 결과입니다.
enum QuestReminderApplyResult: Equatable {
    case enabled
    case disabled
    case permissionDenied
    case requiresPermission
}

/// 퀘스트 리마인드 스케줄링 인터페이스입니다.
protocol QuestReminderScheduling {
    /// 하루 1회 퀘스트 리마인드 스케줄을 적용합니다.
    /// - Parameters:
    ///   - enabled: 리마인드 활성화 여부입니다.
    ///   - allowAuthorizationPrompt: 권한 미결정 시 시스템 권한 팝업을 표시할지 여부입니다.
    ///   - hour: 반복 알림 시각(시)입니다.
    ///   - minute: 반복 알림 시각(분)입니다.
    /// - Returns: 리마인드 적용 결과 상태입니다.
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        hour: Int,
        minute: Int
    ) async -> QuestReminderApplyResult
}

/// 퀘스트 리마인드 on/off 설정을 로컬에 저장합니다.
final class QuestReminderPreferenceStore {
    private let defaults = UserDefaults.standard
    private let key = "home.quest.reminder.enabled.v1"

    /// 저장된 퀘스트 리마인드 on/off 상태를 반환합니다.
    var isEnabled: Bool {
        defaults.object(forKey: key) as? Bool ?? false
    }

    /// 퀘스트 리마인드 on/off 상태를 저장합니다.
    /// - Parameter enabled: 저장할 활성화 상태입니다.
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
    }
}

/// iOS 로컬 알림 기반 퀘스트 리마인더 스케줄러입니다.
final class LocalQuestReminderScheduler: QuestReminderScheduling {
    private let center: UNUserNotificationCenter
    private let requestId = "home.quest.daily.reminder.v1"

    /// 로컬 알림 스케줄러를 초기화합니다.
    /// - Parameter center: 알림 스케줄링에 사용할 시스템 알림 센터입니다.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 하루 1회 퀘스트 리마인드 알림을 설정하거나 해제합니다.
    /// - Parameters:
    ///   - enabled: 리마인드 활성화 여부입니다.
    ///   - allowAuthorizationPrompt: 권한 미결정 시 시스템 권한 팝업을 표시할지 여부입니다.
    ///   - hour: 반복 알림 시각(시)입니다.
    ///   - minute: 반복 알림 시각(분)입니다.
    /// - Returns: 리마인드 적용 결과 상태입니다.
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        hour: Int,
        minute: Int
    ) async -> QuestReminderApplyResult {
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [requestId])
            center.removeDeliveredNotifications(withIdentifiers: [requestId])
            return .disabled
        }

        let authorization = await ensureAuthorization(allowPrompt: allowAuthorizationPrompt)
        switch authorization {
        case .enabled:
            break
        case .permissionDenied:
            return .permissionDenied
        case .requiresPermission:
            return .requiresPermission
        case .disabled:
            return .permissionDenied
        }

        center.removePendingNotificationRequests(withIdentifiers: [requestId])

        let content = UNMutableNotificationContent()
        content.title = "오늘 산책 퀘스트 확인할 시간이에요"
        content.body = "홈에서 오늘 미션을 확인하고, 짧게 기록해 진행도를 올려보세요."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil ? .enabled : .permissionDenied)
            }
        }
    }

    /// 알림 권한 상태를 확인하고 필요 시 사용자 권한 요청을 실행합니다.
    /// - Parameter allowPrompt: 권한 미결정 시 시스템 권한 팝업 표시 여부입니다.
    /// - Returns: 권한 처리 결과입니다.
    private func ensureAuthorization(allowPrompt: Bool) async -> QuestReminderApplyResult {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .denied:
            return .permissionDenied
        case .notDetermined:
            guard allowPrompt else { return .requiresPermission }
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted ? .enabled : .permissionDenied)
                }
            }
        @unknown default:
            return .permissionDenied
        }
    }
}
