import Foundation

enum WalkSessionEndReason: String, Codable {
    case manual = "manual"
    case autoInactive = "auto_inactive"
    case autoTimeout = "auto_timeout"
    case recoveryEstimated = "recovery_estimated"
}

struct WalkSessionMetadata: Codable, Equatable {
    let endReason: WalkSessionEndReason
    let endedAt: TimeInterval
    let petId: String?
    let updatedAt: TimeInterval
}

final class WalkSessionMetadataStore {
    static let shared = WalkSessionMetadataStore()

    private enum Key {
        static let sessionMetadata = "walk.session.metadata.v1"
        static let walkStartCountdownEnabled = "walkStartCountdownEnabled"
        static let walkPointRecordMode = "walkPointRecordMode"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cache: [String: WalkSessionMetadata] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Key.sessionMetadata),
              let decoded = try? JSONDecoder().decode([String: WalkSessionMetadata].self, from: data) else {
            cache = [:]
            return
        }
        cache = decoded
    }

    func set(
        sessionId: UUID,
        reason: WalkSessionEndReason,
        endedAt: TimeInterval,
        petId: String? = nil
    ) {
        lock.lock()
        cache[sessionId.uuidString.lowercased()] = WalkSessionMetadata(
            endReason: reason,
            endedAt: endedAt,
            petId: petId,
            updatedAt: Date().timeIntervalSince1970
        )
        persistLocked()
        lock.unlock()
    }

    func metadata(sessionId: UUID) -> WalkSessionMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return cache[sessionId.uuidString.lowercased()]
    }

    func petId(sessionId: UUID) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[sessionId.uuidString.lowercased()]?.petId
    }

    func clear(sessionId: UUID) {
        lock.lock()
        cache.removeValue(forKey: sessionId.uuidString.lowercased())
        persistLocked()
        lock.unlock()
    }

    func walkStartCountdownEnabled() -> Bool {
        defaults.object(forKey: Key.walkStartCountdownEnabled) as? Bool ?? false
    }

    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.walkStartCountdownEnabled)
    }

    func walkPointRecordModeRawValue() -> String {
        defaults.string(forKey: Key.walkPointRecordMode) ?? "manual"
    }

    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        defaults.set(rawValue, forKey: Key.walkPointRecordMode)
    }

    func clearPreferences() {
        defaults.removeObject(forKey: Key.walkStartCountdownEnabled)
        defaults.removeObject(forKey: Key.walkPointRecordMode)
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: Key.sessionMetadata)
    }
}
