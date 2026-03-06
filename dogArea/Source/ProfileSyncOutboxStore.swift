import Foundation

enum ProfileSyncOutboxStage: String, Codable, CaseIterable {
    case profile
    case pet

    var order: Int {
        switch self {
        case .profile: return 0
        case .pet: return 1
        }
    }
}

struct ProfileSyncOutboxItem: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let petId: String?
    let stage: ProfileSyncOutboxStage
    let idempotencyKey: String
    let payload: [String: String]
    var status: SyncOutboxStatus
    var retryCount: Int
    var nextRetryAt: TimeInterval
    var lastErrorCode: SyncOutboxErrorCode?
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
}

protocol ProfileSyncOutboxTransporting {
    func send(item: ProfileSyncOutboxItem) async -> SyncOutboxSendResult
}

final class ProfileSyncOutboxStore {
    static let shared = ProfileSyncOutboxStore()

    private let stateQueue = DispatchQueue(label: "com.th.dogArea.profile-sync-outbox-store.state")
    private let storageKey = "sync.profile.outbox.items.v1"
    private var items: [ProfileSyncOutboxItem] = []
    private let maxItems = 500

    private init() {
        load()
    }

    func enqueueSnapshot(userInfo: UserInfo) {
        stateQueue.sync {
            var mutable = items
            let now = Date().timeIntervalSince1970

            let profilePayload: [String: String] = [
                "display_name": userInfo.name,
                "profile_image_url": userInfo.profile ?? "",
                "profile_message": userInfo.profileMessage ?? ""
            ]
            let profileKey = "profile-\(userInfo.id)"
            if mutable.contains(where: { $0.idempotencyKey == profileKey && $0.status != .completed }) == false {
                mutable.append(
                    ProfileSyncOutboxItem(
                        id: UUID().uuidString.lowercased(),
                        userId: userInfo.id,
                        petId: nil,
                        stage: .profile,
                        idempotencyKey: profileKey,
                        payload: profilePayload,
                        status: .queued,
                        retryCount: 0,
                        nextRetryAt: now,
                        lastErrorCode: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }

            userInfo.pet.forEach { pet in
                let petKey = "pet-\(userInfo.id)-\(pet.petId)"
                guard mutable.contains(where: { $0.idempotencyKey == petKey && $0.status != .completed }) == false else {
                    return
                }
                let payload: [String: String] = [
                    "pet_id": pet.petId,
                    "name": pet.petName,
                    "photo_url": pet.petProfile ?? "",
                    "breed": pet.breed ?? "",
                    "age_years": pet.ageYears.map(String.init) ?? "",
                    "gender": pet.gender.rawValue,
                    "is_active": pet.isActive ? "true" : "false"
                ]
                mutable.append(
                    ProfileSyncOutboxItem(
                        id: UUID().uuidString.lowercased(),
                        userId: userInfo.id,
                        petId: pet.petId,
                        stage: .pet,
                        idempotencyKey: petKey,
                        payload: payload,
                        status: .queued,
                        retryCount: 0,
                        nextRetryAt: now,
                        lastErrorCode: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }

            if mutable.count > maxItems {
                let overflow = mutable.count - maxItems
                let removable = mutable
                    .enumerated()
                    .filter { _, item in item.status == .completed || item.status == .permanentFailed }
                    .prefix(overflow)
                    .map(\.offset)
                removable.reversed().forEach { mutable.remove(at: $0) }
            }

            items = mutable
            persistLocked()
        }
    }

    func summary() -> SyncOutboxSummary {
        stateQueue.sync {
            let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
            let permanent = items.filter { $0.status == .permanentFailed }.count
            let lastError = items.reversed().compactMap(\.lastErrorCode).first
            return SyncOutboxSummary(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
        }
    }

    @discardableResult
    func flush(using transport: ProfileSyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        while let next = nextDispatchableItem(now: nowTs) {
            updateItem(id: next.id) { item in
                item.status = .processing
                item.updatedAt = Date().timeIntervalSince1970
            }

            let result = await transport.send(item: next)
            let currentNow = Date().timeIntervalSince1970
            switch result {
            case .success:
                updateItem(id: next.id) { item in
                    item.status = .completed
                    item.lastErrorCode = nil
                    item.updatedAt = currentNow
                }
            case .retryable(let code):
                let delay = Self.retryDelay(retryCount: next.retryCount + 1)
                updateItem(id: next.id) { item in
                    item.status = .retrying
                    item.retryCount += 1
                    item.lastErrorCode = code
                    item.nextRetryAt = currentNow + delay
                    item.updatedAt = currentNow
                }
                return summary()
            case .permanent(let code):
                updateItem(id: next.id) { item in
                    item.status = .permanentFailed
                    item.lastErrorCode = code
                    item.updatedAt = currentNow
                }
                return summary()
            }
        }
        return summary()
    }

    private static func retryDelay(retryCount: Int) -> TimeInterval {
        let exp = pow(2.0, Double(max(0, retryCount)))
        return min(900.0, 5.0 * exp)
    }

    private func nextDispatchableItem(now: TimeInterval) -> ProfileSyncOutboxItem? {
        stateQueue.sync {
            return items
                .sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt {
                        if lhs.stage.order == rhs.stage.order {
                            return lhs.id < rhs.id
                        }
                        return lhs.stage.order < rhs.stage.order
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                .first(where: {
                    ($0.status == .queued || $0.status == .retrying || $0.status == .processing) &&
                    $0.nextRetryAt <= now
                })
        }
    }

    private func updateItem(id: String, _ block: (inout ProfileSyncOutboxItem) -> Void) {
        stateQueue.sync {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                block(&items[idx])
                persistLocked()
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ProfileSyncOutboxItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}


final class ProfileSyncCoordinator {
    static let shared = ProfileSyncCoordinator()

    private let outbox = ProfileSyncOutboxStore.shared
    private let transport = SupabaseProfileSyncTransport()
    private var flushTask: Task<Void, Never>? = nil
    private var lastFlushAt: Date = .distantPast

    private init() {}

    func enqueueSnapshot(userInfo: UserInfo) {
        outbox.enqueueSnapshot(userInfo: userInfo)
    }

    func flushIfNeeded(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastFlushAt) < 5.0 {
            return
        }
        guard flushTask == nil else { return }
        lastFlushAt = now
        flushTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.outbox.flush(using: self.transport, now: Date())
            self.flushTask = nil
        }
    }

    func summary() -> SyncOutboxSummary {
        outbox.summary()
    }
}
