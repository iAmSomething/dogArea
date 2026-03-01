import Foundation

/// 라이벌 탭의 숨김/차단 익명코드 스냅샷입니다.
struct RivalModerationSnapshot {
    let hiddenAliases: [String]
    let blockedAliases: [String]
}

/// 라이벌 모더레이션 로컬 저장소 인터페이스입니다.
protocol RivalModerationStoreProtocol {
    /// 로컬에 저장된 숨김/차단 목록을 불러옵니다.
    /// - Returns: 숨김/차단 익명코드 스냅샷입니다.
    func loadSnapshot() -> RivalModerationSnapshot

    /// 숨김/차단 목록을 로컬에 저장합니다.
    /// - Parameter snapshot: 저장할 모더레이션 스냅샷입니다.
    func saveSnapshot(_ snapshot: RivalModerationSnapshot)

    /// 신고/차단/숨김 이력을 로컬 로그에 누적합니다.
    /// - Parameters:
    ///   - action: 기록할 액션 타입입니다(`report`/`block`/`hide`).
    ///   - aliasCode: 대상 익명코드입니다.
    ///   - reason: 신고 사유 원문값입니다. 신고가 아니면 `nil`입니다.
    func appendLog(action: String, aliasCode: String, reason: String?)
}

final class RivalModerationStore: RivalModerationStoreProtocol {
    private let preferenceStore: MapPreferenceStoreProtocol
    private let hiddenAliasKey: String
    private let blockedAliasKey: String
    private let moderationLogKey: String

    /// 라이벌 모더레이션 저장소를 초기화합니다.
    /// - Parameters:
    ///   - preferenceStore: UserDefaults 래퍼 저장소입니다.
    ///   - hiddenAliasKey: 숨김 목록 키입니다.
    ///   - blockedAliasKey: 차단 목록 키입니다.
    ///   - moderationLogKey: 모더레이션 로그 키입니다.
    init(
        preferenceStore: MapPreferenceStoreProtocol,
        hiddenAliasKey: String = "rival.hidden.alias.codes.v1",
        blockedAliasKey: String = "rival.blocked.alias.codes.v1",
        moderationLogKey: String = "rival.moderation.logs.v1"
    ) {
        self.preferenceStore = preferenceStore
        self.hiddenAliasKey = hiddenAliasKey
        self.blockedAliasKey = blockedAliasKey
        self.moderationLogKey = moderationLogKey
    }

    /// 로컬에 저장된 숨김/차단 목록을 불러옵니다.
    /// - Returns: 숨김/차단 익명코드 스냅샷입니다.
    func loadSnapshot() -> RivalModerationSnapshot {
        let hidden = Array(Set(preferenceStore.stringArray(forKey: hiddenAliasKey))).sorted()
        let blocked = Array(Set(preferenceStore.stringArray(forKey: blockedAliasKey))).sorted()
        return RivalModerationSnapshot(hiddenAliases: hidden, blockedAliases: blocked)
    }

    /// 숨김/차단 목록을 로컬에 저장합니다.
    /// - Parameter snapshot: 저장할 모더레이션 스냅샷입니다.
    func saveSnapshot(_ snapshot: RivalModerationSnapshot) {
        preferenceStore.set(snapshot.hiddenAliases.sorted(), forKey: hiddenAliasKey)
        preferenceStore.set(snapshot.blockedAliases.sorted(), forKey: blockedAliasKey)
    }

    /// 신고/차단/숨김 이력을 로컬 로그에 누적합니다.
    /// - Parameters:
    ///   - action: 기록할 액션 타입입니다(`report`/`block`/`hide`).
    ///   - aliasCode: 대상 익명코드입니다.
    ///   - reason: 신고 사유 원문값입니다. 신고가 아니면 `nil`입니다.
    func appendLog(action: String, aliasCode: String, reason: String?) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var logs: [RivalModerationLogEntry] = []
        if let data = preferenceStore.data(forKey: moderationLogKey),
           let decoded = try? decoder.decode([RivalModerationLogEntry].self, from: data) {
            logs = decoded
        }

        let entry = RivalModerationLogEntry(
            action: action,
            aliasCode: aliasCode,
            reason: reason,
            createdAt: Date().timeIntervalSince1970
        )
        logs.append(entry)
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
        let encoded = try? encoder.encode(logs)
        preferenceStore.set(encoded, forKey: moderationLogKey)
    }
}
