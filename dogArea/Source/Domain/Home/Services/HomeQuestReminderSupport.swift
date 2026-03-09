import Foundation
import UserNotifications

/// 퀘스트 리마인드 스케줄 적용 결과입니다.
enum QuestReminderApplyResult: Equatable {
    case enabled
    case disabled
    case permissionDenied
    case requiresPermission
}

/// 퀘스트 리마인드의 다음 1회 알림 시각을 계산할 때 필요한 입력 컨텍스트입니다.
struct QuestReminderSchedulingContext {
    let now: Date
    let calendar: Calendar
    let reminderHour: Int
    let reminderMinute: Int
    let hasSavedWalkOnCurrentDay: Bool
}

/// 퀘스트 리마인드 스케줄링 인터페이스입니다.
protocol QuestReminderScheduling {
    /// 하루 1회 퀘스트 리마인드 스케줄을 적용합니다.
    /// - Parameters:
    ///   - enabled: 리마인드 활성화 여부입니다.
    ///   - allowAuthorizationPrompt: 권한 미결정 시 시스템 권한 팝업을 표시할지 여부입니다.
    ///   - context: 다음 1회 알림 시각을 계산할 컨텍스트입니다.
    /// - Returns: 리마인드 적용 결과 상태입니다.
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        context: QuestReminderSchedulingContext
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
    ///   - context: 다음 1회 알림 시각을 계산할 컨텍스트입니다.
    /// - Returns: 리마인드 적용 결과 상태입니다.
    func applyDailyReminder(
        enabled: Bool,
        allowAuthorizationPrompt: Bool,
        context: QuestReminderSchedulingContext
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
        center.removeDeliveredNotifications(withIdentifiers: [requestId])

        let nextReminderDate = makeNextReminderDate(from: context)
        let request = makeNotificationRequest(for: nextReminderDate, calendar: context.calendar)

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil ? .enabled : .permissionDenied)
            }
        }
    }

    /// 현재 컨텍스트를 기준으로 다음 1회 리마인드 알림 시각을 계산합니다.
    /// - Parameter context: 저장된 산책 여부와 현지 시간대 정보가 반영된 계산 입력입니다.
    /// - Returns: 다음으로 예약해야 할 알림 시각입니다.
    private func makeNextReminderDate(from context: QuestReminderSchedulingContext) -> Date {
        let todayReminderDate = makeReminderDate(dayOffset: 0, context: context)
        guard context.hasSavedWalkOnCurrentDay == false, context.now < todayReminderDate else {
            return makeReminderDate(dayOffset: 1, context: context)
        }
        return todayReminderDate
    }

    /// 기준 날짜에서 지정한 일수만큼 이동한 알림 시각을 생성합니다.
    /// - Parameters:
    ///   - dayOffset: 오늘 기준으로 더할 날짜 오프셋입니다.
    ///   - context: 시간대와 목표 시각이 담긴 리마인드 계산 컨텍스트입니다.
    /// - Returns: 해당 일자의 목표 시각이 반영된 날짜입니다.
    private func makeReminderDate(dayOffset: Int, context: QuestReminderSchedulingContext) -> Date {
        let targetDate = context.calendar.date(byAdding: .day, value: dayOffset, to: context.now) ?? context.now
        var dateComponents = context.calendar.dateComponents([.year, .month, .day], from: targetDate)
        dateComponents.hour = context.reminderHour
        dateComponents.minute = context.reminderMinute
        dateComponents.second = 0
        return context.calendar.date(from: dateComponents) ?? targetDate
    }

    /// 지정한 시각에 맞는 1회성 로컬 알림 요청을 생성합니다.
    /// - Parameters:
    ///   - date: 실제 알림이 울려야 하는 시각입니다.
    ///   - calendar: 날짜 컴포넌트 추출에 사용할 현지 캘린더입니다.
    /// - Returns: 시스템 알림 센터에 등록할 1회성 요청입니다.
    private func makeNotificationRequest(for date: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "오늘 산책 퀘스트 확인할 시간이에요"
        content.body = "홈에서 오늘 미션을 확인하고, 짧게 기록해 진행도를 올려보세요."
        content.sound = .default

        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        return UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
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
/// 영역 목표 달성 시점에 홈에서 표시할 마일스톤 이벤트 모델입니다.
struct AreaMilestoneEvent: Identifiable, Codable, Equatable {
    let milestoneId: String
    let landmarkName: String
    let thresholdArea: Double
    let achievedAt: TimeInterval
    let source: String

    var id: String { milestoneId }
}

/// 마일스톤 달성 판정에 사용하는 비교군 임계값 모델입니다.
struct AreaMilestoneCandidate: Equatable {
    let landmarkName: String
    let thresholdArea: Double
}

/// 영역 마일스톤 중복 발급을 제어하는 저장소 인터페이스입니다.
protocol AreaMilestoneLedgerStoring {
    /// 특정 사용자 범위의 baseline 시드 여부를 반환합니다.
    /// - Parameter ownerScope: 사용자 범위를 구분하는 키입니다.
    /// - Returns: baseline이 이미 시드되었으면 `true`입니다.
    func hasSeededBaseline(for ownerScope: String) -> Bool

    /// 특정 사용자 범위에 baseline 시드 완료 상태를 기록합니다.
    /// - Parameter ownerScope: 사용자 범위를 구분하는 키입니다.
    func markSeededBaseline(for ownerScope: String)

    /// 지정 마일스톤이 이미 달성 처리되었는지 반환합니다.
    /// - Parameters:
    ///   - milestoneId: 조회할 마일스톤 식별자입니다.
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    /// - Returns: 이미 달성 처리된 마일스톤이면 `true`입니다.
    func hasAchievedMilestone(_ milestoneId: String, ownerScope: String) -> Bool

    /// 마일스톤 달성 이벤트를 영속 저장합니다.
    /// - Parameters:
    ///   - event: 저장할 마일스톤 달성 이벤트입니다.
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    func markAchieved(_ event: AreaMilestoneEvent, ownerScope: String)
}

/// `UserDefaults` 기반 영역 마일스톤 발급 이력 저장소 구현입니다.
final class DefaultAreaMilestoneLedgerStore: AreaMilestoneLedgerStoring {
    private let defaults: UserDefaults
    private let achievedLedgerKey = "area.milestone.achieved.v1"
    private let seededOwnerKey = "area.milestone.seeded.v1"

    /// 저장소를 초기화합니다.
    /// - Parameter defaults: 영속 저장에 사용할 `UserDefaults` 인스턴스입니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 특정 사용자 범위의 baseline 시드 여부를 반환합니다.
    /// - Parameter ownerScope: 사용자 범위를 구분하는 키입니다.
    /// - Returns: baseline이 이미 시드되었으면 `true`입니다.
    func hasSeededBaseline(for ownerScope: String) -> Bool {
        seededOwnerScopes().contains(ownerScope)
    }

    /// 특정 사용자 범위에 baseline 시드 완료 상태를 기록합니다.
    /// - Parameter ownerScope: 사용자 범위를 구분하는 키입니다.
    func markSeededBaseline(for ownerScope: String) {
        var seeded = seededOwnerScopes()
        seeded.insert(ownerScope)
        defaults.set(Array(seeded), forKey: seededOwnerKey)
    }

    /// 지정 마일스톤이 이미 달성 처리되었는지 반환합니다.
    /// - Parameters:
    ///   - milestoneId: 조회할 마일스톤 식별자입니다.
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    /// - Returns: 이미 달성 처리된 마일스톤이면 `true`입니다.
    func hasAchievedMilestone(_ milestoneId: String, ownerScope: String) -> Bool {
        achievedLedger()[scopedMilestoneLedgerKey(ownerScope: ownerScope, milestoneId: milestoneId)] != nil
    }

    /// 마일스톤 달성 이벤트를 영속 저장합니다.
    /// - Parameters:
    ///   - event: 저장할 마일스톤 달성 이벤트입니다.
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    func markAchieved(_ event: AreaMilestoneEvent, ownerScope: String) {
        var ledger = achievedLedger()
        let key = scopedMilestoneLedgerKey(ownerScope: ownerScope, milestoneId: event.milestoneId)
        guard ledger[key] == nil else { return }
        ledger[key] = event
        persistLedger(ledger)
    }

    /// 사용자별 시드 완료 집합을 반환합니다.
    /// - Returns: baseline 시드 완료된 사용자 범위 키 집합입니다.
    private func seededOwnerScopes() -> Set<String> {
        let values = defaults.array(forKey: seededOwnerKey) as? [String] ?? []
        return Set(values)
    }

    /// 저장된 마일스톤 발급 원장을 로드합니다.
    /// - Returns: 사용자 범위 포함 키를 기준으로 한 이벤트 원장입니다.
    private func achievedLedger() -> [String: AreaMilestoneEvent] {
        guard let data = defaults.data(forKey: achievedLedgerKey) else { return [:] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String: AreaMilestoneEvent].self, from: data)) ?? [:]
    }

    /// 원장을 `UserDefaults`에 저장합니다.
    /// - Parameter ledger: 저장할 마일스톤 원장입니다.
    private func persistLedger(_ ledger: [String: AreaMilestoneEvent]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(ledger) else { return }
        defaults.set(data, forKey: achievedLedgerKey)
    }

    /// 사용자 범위와 마일스톤 ID를 조합한 저장 키를 생성합니다.
    /// - Parameters:
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    ///   - milestoneId: 마일스톤 식별자입니다.
    /// - Returns: 사용자 범위가 포함된 저장 키입니다.
    private func scopedMilestoneLedgerKey(ownerScope: String, milestoneId: String) -> String {
        "\(ownerScope)|\(milestoneId)"
    }
}

/// 현재 누적 영역과 비교군을 기준으로 새 마일스톤 돌파를 감지합니다.
protocol AreaMilestoneDetecting {
    /// 새로 돌파된 마일스톤 이벤트를 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역(㎡)입니다.
    ///   - ownerUserId: 현재 로그인 사용자 ID입니다.
    ///   - candidates: 비교 대상 마일스톤 영역 목록입니다.
    ///   - source: 마일스톤 기준 출처 라벨입니다.
    ///   - achievedAt: 달성 시각입니다.
    /// - Returns: 이번 계산에서 새로 돌파된 마일스톤 이벤트 목록입니다.
    func detectNewMilestones(
        currentArea: Double,
        ownerUserId: String?,
        candidates: [AreaMilestoneCandidate],
        source: String,
        achievedAt: Date
    ) -> [AreaMilestoneEvent]
}

/// 영역 비교군 기반 마일스톤 달성 감지기입니다.
final class AreaMilestoneDetector: AreaMilestoneDetecting {
    private let ledgerStore: AreaMilestoneLedgerStoring

    /// 감지기를 초기화합니다.
    /// - Parameter ledgerStore: 중복 발급 방지 원장을 담당하는 저장소입니다.
    init(ledgerStore: AreaMilestoneLedgerStoring = DefaultAreaMilestoneLedgerStore()) {
        self.ledgerStore = ledgerStore
    }

    /// 새로 돌파된 마일스톤 이벤트를 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역(㎡)입니다.
    ///   - ownerUserId: 현재 로그인 사용자 ID입니다.
    ///   - candidates: 비교 대상 마일스톤 영역 목록입니다.
    ///   - source: 마일스톤 기준 출처 라벨입니다.
    ///   - achievedAt: 달성 시각입니다.
    /// - Returns: 이번 계산에서 새로 돌파된 마일스톤 이벤트 목록입니다.
    func detectNewMilestones(
        currentArea: Double,
        ownerUserId: String?,
        candidates: [AreaMilestoneCandidate],
        source: String,
        achievedAt: Date = Date()
    ) -> [AreaMilestoneEvent] {
        let ownerScope = ownerScopeKey(from: ownerUserId)
        let sortedCandidates = normalizedCandidates(candidates)
        guard sortedCandidates.isEmpty == false else { return [] }

        if ledgerStore.hasSeededBaseline(for: ownerScope) == false {
            seedBaselineIfNeeded(
                currentArea: currentArea,
                ownerScope: ownerScope,
                candidates: sortedCandidates,
                source: source,
                achievedAt: achievedAt
            )
            ledgerStore.markSeededBaseline(for: ownerScope)
            return []
        }

        var events: [AreaMilestoneEvent] = []
        for candidate in sortedCandidates where candidate.thresholdArea <= currentArea {
            let milestoneId = milestoneIdentifier(ownerScope: ownerScope, candidate: candidate)
            guard ledgerStore.hasAchievedMilestone(milestoneId, ownerScope: ownerScope) == false else {
                continue
            }
            let event = AreaMilestoneEvent(
                milestoneId: milestoneId,
                landmarkName: candidate.landmarkName,
                thresholdArea: candidate.thresholdArea,
                achievedAt: achievedAt.timeIntervalSince1970,
                source: source
            )
            ledgerStore.markAchieved(event, ownerScope: ownerScope)
            events.append(event)
        }
        return events
    }

    /// 감지 첫 실행 시 현재 누적 영역 이하 마일스톤을 baseline으로 선반영합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역(㎡)입니다.
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    ///   - candidates: 정렬된 마일스톤 후보 목록입니다.
    ///   - source: 마일스톤 기준 출처 라벨입니다.
    ///   - achievedAt: baseline 저장 기준 시각입니다.
    private func seedBaselineIfNeeded(
        currentArea: Double,
        ownerScope: String,
        candidates: [AreaMilestoneCandidate],
        source: String,
        achievedAt: Date
    ) {
        for candidate in candidates where candidate.thresholdArea <= currentArea {
            let event = AreaMilestoneEvent(
                milestoneId: milestoneIdentifier(ownerScope: ownerScope, candidate: candidate),
                landmarkName: candidate.landmarkName,
                thresholdArea: candidate.thresholdArea,
                achievedAt: achievedAt.timeIntervalSince1970,
                source: source
            )
            ledgerStore.markAchieved(event, ownerScope: ownerScope)
        }
    }

    /// 입력 후보를 정렬/중복 제거한 마일스톤 목록으로 정규화합니다.
    /// - Parameter candidates: 원본 후보 목록입니다.
    /// - Returns: 면적 오름차순 기준 정렬된 후보 목록입니다.
    private func normalizedCandidates(_ candidates: [AreaMilestoneCandidate]) -> [AreaMilestoneCandidate] {
        let unique = Dictionary(
            candidates.map { (candidateKey(for: $0), $0) },
            uniquingKeysWith: { lhs, rhs in
                lhs.thresholdArea <= rhs.thresholdArea ? lhs : rhs
            }
        )
        return unique.values.sorted { lhs, rhs in
            if lhs.thresholdArea == rhs.thresholdArea {
                return lhs.landmarkName < rhs.landmarkName
            }
            return lhs.thresholdArea < rhs.thresholdArea
        }
    }

    /// 사용자 ID를 마일스톤 원장 범위 키로 변환합니다.
    /// - Parameter userId: 현재 사용자 ID입니다.
    /// - Returns: 원장 분리에 사용할 사용자 범위 키입니다.
    private func ownerScopeKey(from userId: String?) -> String {
        let trimmed = (userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "guest" : trimmed
    }

    /// 마일스톤 후보를 안정적인 고유 키 문자열로 변환합니다.
    /// - Parameter candidate: 키를 생성할 마일스톤 후보입니다.
    /// - Returns: 이름/면적 기반의 정규화된 키 문자열입니다.
    private func candidateKey(for candidate: AreaMilestoneCandidate) -> String {
        "\(normalizedIdentifierFragment(candidate.landmarkName))|\(Int(candidate.thresholdArea.rounded()))"
    }

    /// 사용자 범위를 포함한 마일스톤 ID를 생성합니다.
    /// - Parameters:
    ///   - ownerScope: 사용자 범위를 구분하는 키입니다.
    ///   - candidate: 마일스톤 후보입니다.
    /// - Returns: 사용자 범위와 임계값이 반영된 마일스톤 ID입니다.
    private func milestoneIdentifier(ownerScope: String, candidate: AreaMilestoneCandidate) -> String {
        let normalizedName = normalizedIdentifierFragment(candidate.landmarkName)
        let threshold = Int(candidate.thresholdArea.rounded())
        return "\(ownerScope).\(normalizedName).\(threshold)"
    }

    /// 식별자에 사용할 문자열 조각을 소문자/밑줄 형식으로 정규화합니다.
    /// - Parameter value: 정규화할 원본 문자열입니다.
    /// - Returns: 공백/특수문자가 제거된 식별자 문자열입니다.
    private func normalizedIdentifierFragment(_ value: String) -> String {
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9가-힣_]+", with: "", options: .regularExpression)
        return lowered.isEmpty ? "milestone" : lowered
    }
}

/// 앱이 비활성 상태일 때 마일스톤 달성 로컬 알림 fallback을 스케줄합니다.
protocol AreaMilestoneNotificationScheduling {
    /// 필요 시 마일스톤 로컬 알림을 예약합니다.
    /// - Parameters:
    ///   - event: 알림 대상으로 예약할 마일스톤 이벤트입니다.
    ///   - appIsActive: 앱이 현재 포그라운드 활성 상태인지 여부입니다.
    ///   - now: 일일 상한 계산 기준 시각입니다.
    func scheduleFallbackNotificationIfNeeded(
        for event: AreaMilestoneEvent,
        appIsActive: Bool,
        now: Date
    ) async
}

/// `UNUserNotificationCenter` 기반 마일스톤 알림 fallback 스케줄러입니다.
final class LocalAreaMilestoneNotificationScheduler: AreaMilestoneNotificationScheduling {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let dailyCountPrefix = "home.area.milestone.notification.daily.v1"
    private let dailyLimit = 3
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    /// 스케줄러를 초기화합니다.
    /// - Parameters:
    ///   - center: 알림 예약에 사용할 시스템 알림 센터입니다.
    ///   - defaults: 일일 발급 상한 카운트를 저장할 `UserDefaults`입니다.
    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    /// 필요 시 마일스톤 로컬 알림을 예약합니다.
    /// - Parameters:
    ///   - event: 알림 대상으로 예약할 마일스톤 이벤트입니다.
    ///   - appIsActive: 앱이 현재 포그라운드 활성 상태인지 여부입니다.
    ///   - now: 일일 상한 계산 기준 시각입니다.
    func scheduleFallbackNotificationIfNeeded(
        for event: AreaMilestoneEvent,
        appIsActive: Bool,
        now: Date = Date()
    ) async {
        guard appIsActive == false else { return }
        guard todayNotificationCount(at: now) < dailyLimit else { return }
        let isAuthorized = await ensureAuthorization()
        guard isAuthorized else { return }

        let identifier = "home.area.milestone.\(event.milestoneId)"
        let content = UNMutableNotificationContent()
        content.title = "영역 배지 획득"
        content.body = "\(event.landmarkName) 목표를 달성했어요! 홈에서 새 배지를 확인해보세요."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        let scheduled = await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }

        if scheduled {
            incrementTodayNotificationCount(at: now)
        }
    }

    /// 현재 시각 기준 일일 알림 발급 횟수를 반환합니다.
    /// - Parameter date: 조회 기준 시각입니다.
    /// - Returns: 해당 일자의 누적 알림 발급 횟수입니다.
    private func todayNotificationCount(at date: Date) -> Int {
        defaults.integer(forKey: dailyCountKey(for: date))
    }

    /// 현재 시각 기준 일일 알림 발급 횟수를 1 증가시킵니다.
    /// - Parameter date: 카운트 증가 기준 시각입니다.
    private func incrementTodayNotificationCount(at date: Date) {
        let key = dailyCountKey(for: date)
        defaults.set(todayNotificationCount(at: date) + 1, forKey: key)
    }

    /// 시각을 일일 발급 카운트 저장 키로 변환합니다.
    /// - Parameter date: 변환할 기준 시각입니다.
    /// - Returns: 날짜 기준 카운트 키 문자열입니다.
    private func dailyCountKey(for date: Date) -> String {
        "\(dailyCountPrefix).\(Self.dayFormatter.string(from: date))"
    }

    /// 알림 권한 상태를 확인하고 필요 시 시스템 권한 요청을 진행합니다.
    /// - Returns: 알림 발급이 가능한 상태면 `true`입니다.
    private func ensureAuthorization() async -> Bool {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
